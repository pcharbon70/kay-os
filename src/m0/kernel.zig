const std = @import("std");
const limine = @import("limine.zig");

fn panicImpl(_: []const u8, _: ?usize) noreturn {
    kay_panic(0x50414e4943);
}

pub const panic = std.debug.FullPanic(panicImpl);

export fn kay_fixture_main() callconv(.c) u64 {
    // Reading the exported tag keeps the selected protocol revision visible to
    // both the compiler and the linker without trusting any loader response.
    const revision: *volatile u64 = &limine.kay_limine_base_revision[2];
    return revision.*;
}

export fn kay_panic(_: u64) callconv(.c) noreturn {
    while (true) asm volatile ("cli\n\thlt");
}
