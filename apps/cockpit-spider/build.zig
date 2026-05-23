const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const skip_db = b.option(bool, "skip-db", "Skip local PostgreSQL Docker bootstrap") orelse false;

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

    // Torna spider.config.zig visível para o módulo Spider.
const spider_config_mod = b.createModule(.{
    .root_source_file = b.path("spider.config.zig"),
    .imports = &.{
        .{ .name = "spider", .module = spider_mod },
    },
});
spider_mod.addImport("spider_config", spider_config_mod);

    // Auto-generate embedded templates for Spider embed mode
    const gen = b.addRunArtifact(spider_dep.artifact("generate-templates"));
    gen.addArg("src/");
    gen.addArg("src/embedded_templates.zig");
    exe.step.dependOn(&gen.step);

    b.installArtifact(exe);

    const ensure_postgres_cmd = b.addSystemCommand(&.{
        "sh",
        "../../scripts/ensure-local-postgres.sh",
    });

    const db_step = b.step("db", "Ensure the local PostgreSQL Docker container is running");
    db_step.dependOn(&ensure_postgres_cmd.step);

    if (!skip_db) {
        b.getInstallStep().dependOn(&ensure_postgres_cmd.step);
    }

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (!skip_db) {
        run_cmd.step.dependOn(&ensure_postgres_cmd.step);
    }

    const run_step = b.step("run", "Run Zivyar Cockpit Spider backend");
    run_step.dependOn(&run_cmd.step);
}
