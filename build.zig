const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimze = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const exe = b.addExecutable(.{
        .name = "zproj",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimze,
        }),
    });

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    run_exe.step.dependOn(b.getInstallStep());

    if (b.args) |arg| {
        run_exe.addArgs(arg);
    }

    const run_step = b.step("run", "run the program");
    run_step.dependOn(&run_exe.step);

}
