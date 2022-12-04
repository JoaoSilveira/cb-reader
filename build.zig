const std = @import("std");
const Builder = std.build.Builder;
const Step = std.build.Step;
const raylib = @import("deps/raylib-zig/lib.zig");

pub fn build(b: *Builder) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("cb-reader", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.setOutputDir("zig-out");

    // exe.addIncludePath("./deps/raylib.zig/");
    // exe.addCSourceFile("./deps/raylib.zig/marshal.c", &.{});
    raylib.link(exe, false);
    raylib.addAsPackage("raylib", exe);
    raylib.math.addAsPackage("raylib-math", exe);

    exe.linkLibC();
    exe.linkSystemLibrary("archive");
    exe.addLibraryPath("./deps/libarchive/lib");
    exe.addIncludePath("./deps/libarchive/include");
    b.installBinFile("./deps/libarchive/bin/archive.dll", "archive.dll");
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
