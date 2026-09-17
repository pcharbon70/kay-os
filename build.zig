const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
        .cpu_model = .{ .explicit = &std.Target.x86.cpu.nehalem },
    });

    const fixture = addFixture(b, target, "kay-m0-fixture", true);
    const audit_fixture = addFixture(b, target, "kay-m0-fixture-audit", false);

    b.installArtifact(fixture);
    b.installArtifact(audit_fixture);

    const fixture_step = b.step("fixture", "Build the M0 freestanding qualification fixtures");
    fixture_step.dependOn(&fixture.step);
    fixture_step.dependOn(&audit_fixture.step);
}

fn addFixture(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    name: []const u8,
    strip: bool,
) *std.Build.Step.Compile {
    const root_module = b.createModule(.{
        .root_source_file = b.path("src/m0/fixture.zig"),
        .target = target,
        .optimize = .ReleaseSmall,
        .link_libc = false,
        .single_threaded = true,
        .strip = strip,
        .unwind_tables = .none,
        .code_model = .small,
        .stack_protector = false,
        .stack_check = false,
        .sanitize_c = .off,
        .pic = false,
        .red_zone = false,
        .omit_frame_pointer = false,
        .error_tracing = false,
    });
    root_module.addIncludePath(b.path("src/m0"));
    root_module.addCSourceFile(.{
        .file = b.path("src/m0/boundary.c"),
        .flags = &.{
            "-std=c11",
            "-ffreestanding",
            "-fno-builtin",
            "-fno-stack-protector",
            "-fno-unwind-tables",
            "-fno-asynchronous-unwind-tables",
            "-fno-pic",
            "-mno-red-zone",
            "-mno-mmx",
            "-mno-sse",
            "-msoft-float",
            "-Wall",
            "-Wextra",
            "-Werror",
        },
    });
    root_module.addAssemblyFile(b.path("src/m0/entry.S"));

    const fixture = b.addExecutable(.{
        .name = name,
        .root_module = root_module,
        .use_llvm = true,
        .use_lld = true,
    });
    fixture.entry = .{ .symbol_name = "_start" };
    fixture.pie = false;
    fixture.link_gc_sections = false;
    fixture.link_function_sections = true;
    fixture.link_data_sections = true;
    fixture.bundle_compiler_rt = false;
    fixture.bundle_ubsan_rt = false;
    fixture.build_id = .none;
    fixture.link_z_defs = true;
    fixture.setLinkerScript(b.path("linker/x86_64-m0.ld"));

    return fixture;
}
