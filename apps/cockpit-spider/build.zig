const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const spider_dep = b.dependency("spider", .{ .target = target });
    const spider_mod = spider_dep.module("spider");

    const exe = b.addExecutable(.{
        .name = "zivyar-cockpit-spider",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "spider", .module = spider_mod },
            },
        }),
    });

    spider_mod.addAnonymousImport("spider_config", .{
        .root_source_file = b.path("spider.config.zig"),
        .imports = &.{
            .{ .name = "spider", .module = spider_mod },
        },
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run Zivyar Cockpit Spider backend");
    run_step.dependOn(&run_cmd.step);
}
