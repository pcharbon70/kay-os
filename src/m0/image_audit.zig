const std = @import("std");
const contracts = @import("contracts.zig");
const limine = @import("limine.zig");

const max_elf_bytes = 1024 * 1024;

pub fn main(init: std.process.Init) !void {
    var args = std.process.Args.Iterator.init(init.minimal.args);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingElfPath;
    if (args.next() != null) return error.TooManyArguments;

    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_elf_bytes));
    defer init.gpa.free(bytes);

    var segment_storage: [contracts.max_image_segments]contracts.ImageSegment = undefined;
    const image = try parseElf(bytes, &segment_storage);
    const snapshot = contracts.canonicalBootSnapshot();
    const validated = try contracts.validateImage(image, &snapshot);

    try requireBytes(bytes, std.mem.asBytes(&limine.request_start_values));
    try requireBytes(bytes, std.mem.asBytes(&limine.base_revision_values));
    try requireBytes(bytes, std.mem.asBytes(&limine.request_end_values));

    std.debug.print(
        "image-contract=pass segments={d} entry=0x{x} physical=0x{x}..0x{x} limine-base-revision={d}\n",
        .{ validated.segment_count, validated.entry, validated.physical_start, validated.physical_end, limine.protocol_base_revision },
    );
}

fn parseElf(bytes: []const u8, storage: *[contracts.max_image_segments]contracts.ImageSegment) !contracts.ImageDescriptor {
    if (bytes.len < 64 or !std.mem.eql(u8, bytes[0..4], "\x7fELF")) return error.BadElfMagic;
    if (bytes[4] != 2 or bytes[5] != 1) return error.UnsupportedElfEncoding;
    if (try readU16(bytes, 16) != 2 or try readU16(bytes, 18) != 62) return error.UnsupportedElfIdentity;
    const entry = try readU64(bytes, 24);
    const program_offset = try readU64(bytes, 32);
    const program_size = try readU16(bytes, 54);
    const program_count = try readU16(bytes, 56);
    if (program_size != 56 or program_count == 0 or program_count > contracts.max_image_segments) {
        return error.BadProgramHeaderTable;
    }

    const table_bytes = try checkedMul(program_count, program_size);
    const table_end = try checkedAdd(program_offset, table_bytes);
    if (table_end > bytes.len) return error.TruncatedProgramHeaderTable;

    var load_count: usize = 0;
    var index: usize = 0;
    while (index < program_count) : (index += 1) {
        const offset = program_offset + index * program_size;
        if (try readU32(bytes, offset) != 1) return error.UnsupportedProgramHeader;
        const flags = try readU32(bytes, offset + 4);
        const file_offset = try readU64(bytes, offset + 8);
        const file_size = try readU64(bytes, offset + 32);
        if (try checkedAdd(file_offset, file_size) > bytes.len) return error.SegmentOutsideElf;
        storage[load_count] = .{
            .file_offset = file_offset,
            .virtual_address = try readU64(bytes, offset + 16),
            .physical_address = try readU64(bytes, offset + 24),
            .file_size = file_size,
            .memory_size = try readU64(bytes, offset + 40),
            .alignment = try readU64(bytes, offset + 48),
            .flags = .{
                .read = flags & 4 != 0,
                .write = flags & 2 != 0,
                .execute = flags & 1 != 0,
            },
        };
        load_count += 1;
    }
    if (load_count != 2) return error.UnexpectedLoadSegmentCount;
    if (storage[1].memory_size <= storage[1].file_size) return error.MissingZeroFillDescription;
    return .{ .entry = entry, .segments = storage[0..load_count] };
}

fn requireBytes(haystack: []const u8, needle: []const u8) !void {
    if (std.mem.indexOf(u8, haystack, needle) == null) return error.MissingLimineProtocolTag;
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
    if (offset > bytes.len or bytes.len - offset < 2) return error.TruncatedElf;
    return @as(u16, bytes[offset]) | (@as(u16, bytes[offset + 1]) << 8);
}

fn readU32(bytes: []const u8, offset: usize) !u32 {
    if (offset > bytes.len or bytes.len - offset < 4) return error.TruncatedElf;
    return @as(u32, bytes[offset]) | (@as(u32, bytes[offset + 1]) << 8) |
        (@as(u32, bytes[offset + 2]) << 16) | (@as(u32, bytes[offset + 3]) << 24);
}

fn readU64(bytes: []const u8, offset: usize) !u64 {
    if (offset > bytes.len or bytes.len - offset < 8) return error.TruncatedElf;
    var value: u64 = 0;
    var index: usize = 0;
    while (index < 8) : (index += 1) value |= @as(u64, bytes[offset + index]) << @intCast(index * 8);
    return value;
}
