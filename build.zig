const std = @import("std");
const Builder = std.build.Builder;
const sep_str = std.fs.path.sep_str;
const Cpu = std.Target.Cpu;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});

    const exe = b.addExecutable("voxel-game", "src/main.zig");
    exe.setBuildMode(b.standardReleaseOptions());
    exe.setTarget(target);
    exe.addIncludeDir("lib");
    const lib_cflags = &[_][]const u8{};
    exe.addCSourceFile("lib/stb_perlin.c", lib_cflags);
    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("freetype");
    exe.linkSystemLibrary("epoxy");
    exe.linkLibC();
    exe.install();

    const tests = b.addTest("src/main.zig");

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    b.step("native", "Build the native binary").dependOn(&exe.step);
    b.step("run", "Run the native binary").dependOn(&run_cmd.step);
    b.step("test", "Run tests").dependOn(&tests.step);

    const all = b.step("all", "Build all binaries");
    all.dependOn(&exe.step);
    all.dependOn(&tests.step);
}
