const std = @import("std");

pub const boot_magic: u32 = 0x3042_594b; // "KYB0" in little-endian order.
pub const boot_version: u16 = 1;
pub const boot_header_size: usize = 24;
pub const memory_record_size: usize = 24;
pub const max_boot_snapshot_bytes: usize = 4096;
pub const max_memory_records: usize = 32;
pub const max_image_segments: usize = 8;
pub const max_console_transfer: usize = 256;
pub const higher_half_base: u64 = 0xffff_ffff_8000_0000;
pub const kernel_physical_base: u64 = 0x200000;
pub const physical_limit: u64 = 64 * 1024 * 1024;
pub const page_size: u64 = 4096;
pub const console_endpoint: u16 = 1;
pub const clock_endpoint: u16 = 2;

pub const MemoryKind = enum(u32) { usable = 1, reserved = 2 };

pub const MemoryExtent = struct { base: u64, length: u64, kind: MemoryKind };

pub const BootSnapshot = struct {
    record_count: usize,
    usable_bytes: u64,
    kernel_physical_base: u64,
    records: [max_memory_records]MemoryExtent,

    pub fn extents(snapshot: *const BootSnapshot) []const MemoryExtent {
        return snapshot.records[0..snapshot.record_count];
    }
};

pub const SegmentFlags = packed struct(u8) {
    read: bool = false,
    write: bool = false,
    execute: bool = false,
    _padding: u5 = 0,
};

pub const ImageSegment = struct {
    virtual_address: u64,
    physical_address: u64,
    file_offset: u64,
    file_size: u64,
    memory_size: u64,
    alignment: u64,
    flags: SegmentFlags,
};

pub const ImageDescriptor = struct { entry: u64, segments: []const ImageSegment };

pub const ValidatedImage = struct {
    entry: u64,
    segment_count: usize,
    physical_start: u64,
    physical_end: u64,
};

pub const Caller = enum(u8) { cli = 1, unknown = 255 };
pub const Grant = enum(u8) { console_read, console_write, clock_read, clock_wait };
pub const Operation = enum(u8) { console_read = 1, console_write = 2, clock_now = 3, clock_wait_until = 4 };
pub const Payer = enum(u8) { caller_budget = 1 };
pub const EnforcingOwner = enum(u8) { kernel_console_service = 1, kernel_clock_service = 2 };
pub const ResponseKind = enum(u8) {
    byte_count_and_bytes = 1,
    byte_count = 2,
    monotonic_nanoseconds = 3,
    wait_completion = 4,
};
pub const ResultCode = enum(u16) {
    ok = 0,
    denied = 1,
    invalid_endpoint = 2,
    invalid_length = 3,
    deadline_in_past = 4,
};

pub const OperationContract = struct {
    operation: Operation,
    endpoint: u16,
    required_grant: Grant,
    payer: Payer,
    owner: EnforcingOwner,
    response: ResponseKind,
    maximum_transfer: usize,
};

pub const AuthorityRequest = struct {
    caller: Caller,
    endpoint: u16,
    operation: Operation,
    grants: std.EnumSet(Grant),
    buffer_length: usize = 0,
    response_capacity: usize = 0,
    now_ns: u64 = 0,
    deadline_ns: u64 = 0,
};

pub const AuthorityDecision = union(enum) {
    allowed: OperationContract,
    rejected: ResultCode,
};

pub fn validateBootSnapshot(bytes: []const u8) !BootSnapshot {
    if (bytes.len < boot_header_size) return error.TruncatedBootSnapshot;
    if (bytes.len > max_boot_snapshot_bytes) return error.BootSnapshotTooLarge;
    if (try readU32(bytes, 0) != boot_magic) return error.BadBootMagic;
    if (try readU16(bytes, 4) != boot_version) return error.UnsupportedBootVersion;
    if (try readU16(bytes, 6) != boot_header_size) return error.BadBootHeaderSize;
    if (try readU32(bytes, 8) != bytes.len) return error.BootSizeMismatch;

    const record_count = try readU16(bytes, 12);
    if (record_count == 0 or record_count > max_memory_records) return error.BadMemoryRecordCount;
    if (try readU16(bytes, 14) != 0) return error.UnsupportedBootFlags;
    const record_bytes = try checkedMul(record_count, memory_record_size);
    if (try checkedAdd(boot_header_size, record_bytes) != bytes.len) return error.BootSizeMismatch;

    var snapshot = BootSnapshot{
        .record_count = record_count,
        .usable_bytes = 0,
        .kernel_physical_base = try readU64(bytes, 16),
        .records = undefined,
    };
    var previous_end: u64 = 0;
    var index: usize = 0;
    while (index < record_count) : (index += 1) {
        const offset = boot_header_size + index * memory_record_size;
        const base = try readU64(bytes, offset);
        const length = try readU64(bytes, offset + 8);
        if (length == 0) return error.EmptyMemoryExtent;
        const extent_end = try checkedAdd(base, length);
        if (index != 0 and base < previous_end) return error.OverlappingMemoryExtents;
        previous_end = extent_end;
        const kind: MemoryKind = switch (try readU32(bytes, offset + 16)) {
            1 => .usable,
            2 => .reserved,
            else => return error.UnsupportedMemoryKind,
        };
        if (try readU32(bytes, offset + 20) != 0) return error.UnsupportedMemoryFlags;
        snapshot.records[index] = .{ .base = base, .length = length, .kind = kind };
        if (kind == .usable) snapshot.usable_bytes = try checkedAdd(snapshot.usable_bytes, length);
    }
    if (snapshot.usable_bytes == 0) return error.NoUsableMemory;
    return snapshot;
}

pub fn validateImage(image: ImageDescriptor, snapshot: *const BootSnapshot) !ValidatedImage {
    if (image.segments.len == 0 or image.segments.len > max_image_segments) return error.BadImageSegmentCount;
    var entry_is_executable = false;
    var physical_start: u64 = std.math.maxInt(u64);
    var physical_end_max: u64 = 0;
    for (image.segments, 0..) |segment, index| {
        if (segment.memory_size == 0 or segment.file_size > segment.memory_size) return error.BadImageExtent;
        if (segment.alignment != page_size or
            segment.virtual_address % segment.alignment != 0 or
            segment.physical_address % segment.alignment != 0 or
            segment.file_offset % segment.alignment != 0)
        {
            return error.BadImageAlignment;
        }
        if (segment.virtual_address < higher_half_base) return error.NotHigherHalf;
        if (segment.flags.write and segment.flags.execute) return error.WriteExecuteSegment;
        if (!segment.flags.read) return error.UnreadableSegment;

        const virtual_end = try checkedAdd(segment.virtual_address, segment.memory_size);
        const physical_end = try checkedAdd(segment.physical_address, segment.memory_size);
        const file_end = try checkedAdd(segment.file_offset, segment.file_size);
        if (physical_end > physical_limit) return error.SegmentOutsidePhysicalFixture;
        if (!rangeIsReserved(snapshot, segment.physical_address, physical_end)) {
            return error.ImageOutsideKernelReservation;
        }
        for (image.segments[0..index]) |previous| {
            const previous_virtual_end = try checkedAdd(previous.virtual_address, previous.memory_size);
            const previous_physical_end = try checkedAdd(previous.physical_address, previous.memory_size);
            const previous_file_end = try checkedAdd(previous.file_offset, previous.file_size);
            if (rangesOverlap(segment.virtual_address, virtual_end, previous.virtual_address, previous_virtual_end)) {
                return error.OverlappingVirtualSegments;
            }
            if (rangesOverlap(segment.physical_address, physical_end, previous.physical_address, previous_physical_end)) {
                return error.OverlappingPhysicalSegments;
            }
            if (segment.file_size != 0 and previous.file_size != 0 and
                rangesOverlap(segment.file_offset, file_end, previous.file_offset, previous_file_end))
            {
                return error.OverlappingFileSegments;
            }
        }
        if (image.entry >= segment.virtual_address and image.entry < virtual_end and segment.flags.execute) {
            entry_is_executable = true;
        }
        physical_start = @min(physical_start, segment.physical_address);
        physical_end_max = @max(physical_end_max, physical_end);
    }
    if (!entry_is_executable) return error.InvalidEntryPoint;
    if (physical_start != snapshot.kernel_physical_base) return error.KernelBaseMismatch;
    return .{
        .entry = image.entry,
        .segment_count = image.segments.len,
        .physical_start = physical_start,
        .physical_end = physical_end_max,
    };
}

pub fn operationContract(operation: Operation) OperationContract {
    return switch (operation) {
        .console_read => .{ .operation = operation, .endpoint = console_endpoint, .required_grant = .console_read, .payer = .caller_budget, .owner = .kernel_console_service, .response = .byte_count_and_bytes, .maximum_transfer = max_console_transfer },
        .console_write => .{ .operation = operation, .endpoint = console_endpoint, .required_grant = .console_write, .payer = .caller_budget, .owner = .kernel_console_service, .response = .byte_count, .maximum_transfer = max_console_transfer },
        .clock_now => .{ .operation = operation, .endpoint = clock_endpoint, .required_grant = .clock_read, .payer = .caller_budget, .owner = .kernel_clock_service, .response = .monotonic_nanoseconds, .maximum_transfer = 8 },
        .clock_wait_until => .{ .operation = operation, .endpoint = clock_endpoint, .required_grant = .clock_wait, .payer = .caller_budget, .owner = .kernel_clock_service, .response = .wait_completion, .maximum_transfer = 0 },
    };
}

pub fn authorize(request: AuthorityRequest) AuthorityDecision {
    if (request.caller != .cli) return .{ .rejected = .denied };
    const contract = operationContract(request.operation);
    if (request.endpoint != contract.endpoint) return .{ .rejected = .invalid_endpoint };
    if (!request.grants.contains(contract.required_grant)) return .{ .rejected = .denied };
    switch (request.operation) {
        .console_read, .console_write => if (request.buffer_length == 0 or request.buffer_length > contract.maximum_transfer) return .{ .rejected = .invalid_length },
        .clock_now => if (request.buffer_length != 0 or request.response_capacity != 8) return .{ .rejected = .invalid_length },
        .clock_wait_until => {
            if (request.buffer_length != 0 or request.response_capacity != 0) return .{ .rejected = .invalid_length };
            if (request.deadline_ns < request.now_ns) return .{ .rejected = .deadline_in_past };
        },
    }
    return .{ .allowed = contract };
}

pub fn millisecondsToNanoseconds(milliseconds: u64) !u64 {
    return checkedMul(milliseconds, 1_000_000);
}

fn rangeIsReserved(snapshot: *const BootSnapshot, start: u64, end: u64) bool {
    for (snapshot.extents()) |extent| {
        const extent_end = checkedAdd(extent.base, extent.length) catch return false;
        if (extent.kind == .reserved and start >= extent.base and end <= extent_end) return true;
    }
    return false;
}

fn rangesOverlap(a_start: u64, a_end: u64, b_start: u64, b_end: u64) bool {
    return a_start < b_end and b_start < a_end;
}

fn checkedAdd(a: anytype, b: @TypeOf(a)) !@TypeOf(a) {
    const result = @addWithOverflow(a, b);
    if (result[1] != 0) return error.ArithmeticOverflow;
    return result[0];
}

fn checkedMul(a: anytype, b: @TypeOf(a)) !@TypeOf(a) {
    const result = @mulWithOverflow(a, b);
    if (result[1] != 0) return error.ArithmeticOverflow;
    return result[0];
}

fn readU16(bytes: []const u8, offset: usize) !u16 {
    if (offset > bytes.len or bytes.len - offset < 2) return error.TruncatedBootSnapshot;
    return @as(u16, bytes[offset]) | (@as(u16, bytes[offset + 1]) << 8);
}

fn readU32(bytes: []const u8, offset: usize) !u32 {
    if (offset > bytes.len or bytes.len - offset < 4) return error.TruncatedBootSnapshot;
    return @as(u32, bytes[offset]) | (@as(u32, bytes[offset + 1]) << 8) |
        (@as(u32, bytes[offset + 2]) << 16) | (@as(u32, bytes[offset + 3]) << 24);
}

fn readU64(bytes: []const u8, offset: usize) !u64 {
    if (offset > bytes.len or bytes.len - offset < 8) return error.TruncatedBootSnapshot;
    var value: u64 = 0;
    var index: usize = 0;
    while (index < 8) : (index += 1) value |= @as(u64, bytes[offset + index]) << @intCast(index * 8);
    return value;
}

fn writeU16(bytes: []u8, offset: usize, value: u16) void {
    bytes[offset] = @truncate(value);
    bytes[offset + 1] = @truncate(value >> 8);
}

fn writeU32(bytes: []u8, offset: usize, value: u32) void {
    var index: usize = 0;
    while (index < 4) : (index += 1) bytes[offset + index] = @truncate(value >> @intCast(index * 8));
}

fn writeU64(bytes: []u8, offset: usize, value: u64) void {
    var index: usize = 0;
    while (index < 8) : (index += 1) bytes[offset + index] = @truncate(value >> @intCast(index * 8));
}

fn validBootSnapshotBytes() [boot_header_size + 4 * memory_record_size]u8 {
    var bytes = [_]u8{0} ** (boot_header_size + 4 * memory_record_size);
    writeU32(&bytes, 0, boot_magic);
    writeU16(&bytes, 4, boot_version);
    writeU16(&bytes, 6, boot_header_size);
    writeU32(&bytes, 8, bytes.len);
    writeU16(&bytes, 12, 4);
    writeU64(&bytes, 16, kernel_physical_base);
    writeMemoryRecord(&bytes, 0, 0, 0x10_0000, .reserved);
    writeMemoryRecord(&bytes, 1, 0x10_0000, 0x10_0000, .usable);
    writeMemoryRecord(&bytes, 2, kernel_physical_base, 0x1_0000, .reserved);
    writeMemoryRecord(&bytes, 3, 0x21_0000, physical_limit - 0x21_0000, .usable);
    return bytes;
}

fn writeMemoryRecord(bytes: []u8, index: usize, base: u64, length: u64, kind: MemoryKind) void {
    const offset = boot_header_size + index * memory_record_size;
    writeU64(bytes, offset, base);
    writeU64(bytes, offset + 8, length);
    writeU32(bytes, offset + 16, @intFromEnum(kind));
}

pub fn canonicalBootSnapshot() BootSnapshot {
    const bytes = validBootSnapshotBytes();
    return validateBootSnapshot(&bytes) catch unreachable;
}

fn validImageSegments() [2]ImageSegment {
    return .{
        .{ .virtual_address = higher_half_base, .physical_address = kernel_physical_base, .file_offset = 0x1000, .file_size = 0x2000, .memory_size = 0x2000, .alignment = page_size, .flags = .{ .read = true, .execute = true } },
        .{ .virtual_address = higher_half_base + 0x2000, .physical_address = kernel_physical_base + 0x2000, .file_offset = 0x3000, .file_size = 0x1000, .memory_size = 0x3000, .alignment = page_size, .flags = .{ .read = true, .write = true } },
    };
}

fn validAuthorityRequest(operation: Operation) AuthorityRequest {
    const contract = operationContract(operation);
    var grants = std.EnumSet(Grant).initEmpty();
    grants.insert(contract.required_grant);
    return .{
        .caller = .cli,
        .endpoint = contract.endpoint,
        .operation = operation,
        .grants = grants,
        .buffer_length = switch (operation) {
            .console_read, .console_write => max_console_transfer,
            else => 0,
        },
        .response_capacity = if (operation == .clock_now) 8 else 0,
        .now_ns = 20,
        .deadline_ns = 20,
    };
}

test "m0-p02-t01-valid-boot-snapshot" {
    const bytes = validBootSnapshotBytes();
    const snapshot = try validateBootSnapshot(&bytes);
    try std.testing.expectEqual(@as(usize, 4), snapshot.record_count);
    try std.testing.expectEqual(kernel_physical_base, snapshot.kernel_physical_base);
    try std.testing.expectEqual(MemoryKind.reserved, snapshot.extents()[2].kind);
}

test "m0-p02-n01-truncated-snapshot" {
    const bytes = validBootSnapshotBytes();
    try std.testing.expectError(error.BootSizeMismatch, validateBootSnapshot(bytes[0 .. bytes.len - 1]));
}

test "m0-p02-n02-overlapping-memory" {
    var bytes = validBootSnapshotBytes();
    writeU64(&bytes, boot_header_size + memory_record_size, 0x0f_0000);
    try std.testing.expectError(error.OverlappingMemoryExtents, validateBootSnapshot(&bytes));
}

test "m0-p02-n03-arithmetic-overflow" {
    var bytes = validBootSnapshotBytes();
    writeU64(&bytes, boot_header_size + 3 * memory_record_size + 8, std.math.maxInt(u64));
    try std.testing.expectError(error.ArithmeticOverflow, validateBootSnapshot(&bytes));
}

test "m0-p02-t02-valid-static-image" {
    const segments = validImageSegments();
    const snapshot = canonicalBootSnapshot();
    const validated = try validateImage(.{ .entry = higher_half_base, .segments = &segments }, &snapshot);
    try std.testing.expectEqual(@as(usize, 2), validated.segment_count);
    try std.testing.expectEqual(kernel_physical_base, validated.physical_start);
}

test "m0-p02-n04-invalid-entry" {
    const segments = validImageSegments();
    const snapshot = canonicalBootSnapshot();
    try std.testing.expectError(error.InvalidEntryPoint, validateImage(.{ .entry = higher_half_base + 0x3000, .segments = &segments }, &snapshot));
}

test "m0-p02-n05-write-execute-segment" {
    var segments = validImageSegments();
    const snapshot = canonicalBootSnapshot();
    segments[0].flags.write = true;
    try std.testing.expectError(error.WriteExecuteSegment, validateImage(.{ .entry = higher_half_base, .segments = &segments }, &snapshot));
}

test "m0-p02-n06-overlapping-virtual-segments" {
    var segments = validImageSegments();
    const snapshot = canonicalBootSnapshot();
    segments[1].virtual_address = higher_half_base + 0x1000;
    try std.testing.expectError(error.OverlappingVirtualSegments, validateImage(.{ .entry = higher_half_base, .segments = &segments }, &snapshot));
}

test "m0-p02-n07-image-outside-kernel-reservation" {
    var bytes = validBootSnapshotBytes();
    writeU32(&bytes, boot_header_size + 2 * memory_record_size + 16, @intFromEnum(MemoryKind.usable));
    const snapshot = try validateBootSnapshot(&bytes);
    const segments = validImageSegments();
    try std.testing.expectError(error.ImageOutsideKernelReservation, validateImage(.{ .entry = higher_half_base, .segments = &segments }, &snapshot));
}

test "m0-p02-n14-overlapping-physical-segments" {
    var segments = validImageSegments();
    const snapshot = canonicalBootSnapshot();
    segments[1].physical_address = kernel_physical_base + 0x1000;
    try std.testing.expectError(error.OverlappingPhysicalSegments, validateImage(.{ .entry = higher_half_base, .segments = &segments }, &snapshot));
}

test "m0-p02-n15-overlapping-file-segments" {
    var segments = validImageSegments();
    const snapshot = canonicalBootSnapshot();
    segments[1].file_offset = 0x2000;
    try std.testing.expectError(error.OverlappingFileSegments, validateImage(.{ .entry = higher_half_base, .segments = &segments }, &snapshot));
}

test "m0-p02-t03-bounded-authorized-interfaces" {
    const expected = [_]OperationContract{
        .{ .operation = .console_read, .endpoint = 1, .required_grant = .console_read, .payer = .caller_budget, .owner = .kernel_console_service, .response = .byte_count_and_bytes, .maximum_transfer = 256 },
        .{ .operation = .console_write, .endpoint = 1, .required_grant = .console_write, .payer = .caller_budget, .owner = .kernel_console_service, .response = .byte_count, .maximum_transfer = 256 },
        .{ .operation = .clock_now, .endpoint = 2, .required_grant = .clock_read, .payer = .caller_budget, .owner = .kernel_clock_service, .response = .monotonic_nanoseconds, .maximum_transfer = 8 },
        .{ .operation = .clock_wait_until, .endpoint = 2, .required_grant = .clock_wait, .payer = .caller_budget, .owner = .kernel_clock_service, .response = .wait_completion, .maximum_transfer = 0 },
    };
    for (expected) |wanted| {
        try std.testing.expectEqualDeep(wanted, operationContract(wanted.operation));
        var request = validAuthorityRequest(wanted.operation);
        request.endpoint = wanted.endpoint;
        request.grants = std.EnumSet(Grant).initEmpty();
        request.grants.insert(wanted.required_grant);
        switch (authorize(request)) {
            .allowed => |contract| {
                try std.testing.expectEqualDeep(wanted, contract);
            },
            .rejected => return error.ValidAuthorityRequestRejected,
        }
    }
}

test "m0-p02-n08-oversized-console-buffer" {
    var request = validAuthorityRequest(.console_write);
    request.buffer_length = max_console_transfer + 1;
    try std.testing.expectEqual(ResultCode.invalid_length, authorize(request).rejected);
}

test "m0-p02-n09-missing-grant-cross-product" {
    const operations = [_]Operation{ .console_read, .console_write, .clock_now, .clock_wait_until };
    for (operations) |operation| {
        var request = validAuthorityRequest(operation);
        request.grants = std.EnumSet(Grant).initEmpty();
        try std.testing.expectEqual(ResultCode.denied, authorize(request).rejected);
    }
}

test "m0-p02-n10-past-deadline" {
    var request = validAuthorityRequest(.clock_wait_until);
    request.deadline_ns = request.now_ns - 1;
    try std.testing.expectEqual(ResultCode.deadline_in_past, authorize(request).rejected);
}

test "m0-p02-n11-time-conversion-overflow" {
    try std.testing.expectError(error.ArithmeticOverflow, millisecondsToNanoseconds(std.math.maxInt(u64)));
}

test "m0-p02-n16-wrong-endpoint-and-caller" {
    var request = validAuthorityRequest(.clock_now);
    request.endpoint = console_endpoint;
    try std.testing.expectEqual(ResultCode.invalid_endpoint, authorize(request).rejected);
    request = validAuthorityRequest(.clock_now);
    request.caller = .unknown;
    try std.testing.expectEqual(ResultCode.denied, authorize(request).rejected);
}

test "clock conversion uses monotonic nanoseconds" {
    try std.testing.expectEqual(@as(u64, 7_000_000), try millisecondsToNanoseconds(7));
}

test "authority result codes are stable" {
    try std.testing.expectEqual(@as(u16, 0), @intFromEnum(ResultCode.ok));
    try std.testing.expectEqual(@as(u16, 1), @intFromEnum(ResultCode.denied));
    try std.testing.expectEqual(@as(u16, 2), @intFromEnum(ResultCode.invalid_endpoint));
    try std.testing.expectEqual(@as(u16, 3), @intFromEnum(ResultCode.invalid_length));
    try std.testing.expectEqual(@as(u16, 4), @intFromEnum(ResultCode.deadline_in_past));
}
