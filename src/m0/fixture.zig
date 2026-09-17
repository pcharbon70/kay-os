const std = @import("std");
const abi = @cImport({
    @cInclude("abi.h");
});

comptime {
    if (@sizeOf(abi.struct_kay_packet) != 16) @compileError("kay_packet size drift");
    if (@alignOf(abi.struct_kay_packet) != 8) @compileError("kay_packet alignment drift");
    if (@offsetOf(abi.struct_kay_packet, "tag") != 0) @compileError("kay_packet.tag offset drift");
    if (@offsetOf(abi.struct_kay_packet, "value") != 8) @compileError("kay_packet.value offset drift");
}

fn panicImpl(_: []const u8, _: ?usize) noreturn {
    kay_panic(0x50414e4943);
}

pub const panic = std.debug.FullPanic(panicImpl);

export fn kay_zig_callback(packet: *const abi.struct_kay_packet) callconv(.c) u64 {
    return packet.tag ^ packet.value;
}

export fn kay_fixture_main() callconv(.c) u64 {
    const packets = [_]abi.struct_kay_packet{
        .{ .tag = 0x4b4159, .value = 1 },
        .{ .tag = 0x4d30, .value = 2 },
    };
    return abi.kay_c_accumulate(&packets, packets.len);
}

export fn kay_panic(_: u64) callconv(.c) noreturn {
    while (true) {
        asm volatile ("cli\n\thlt");
    }
}
