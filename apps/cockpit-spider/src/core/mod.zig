const std = @import("std");
const spider = @import("spider");

pub const db = spider.pg;

pub const RuntimeCommandResult = struct {
    ok: bool,
    exit_code: i32,
    stdout: []const u8,
    stderr: []const u8,
};

pub fn runRuntimeCommand(c: *spider.Ctx, argv: []const []const u8) RuntimeCommandResult {
    const result = std.process.run(c.arena, c._io, .{
        .argv = argv,
    }) catch {
        return .{
            .ok = false,
            .exit_code = -1,
            .stdout = "",
            .stderr = "Falha ao executar processo externo.",
        };
    };
    const exit_code: i32 = switch (result.term) {
        .exited => |code| @intCast(code),
        else => -1,
    };
    return .{
        .ok = exit_code == 0,
        .exit_code = exit_code,
        .stdout = result.stdout,
        .stderr = result.stderr,
    };
}

pub fn commandSucceeded(c: *spider.Ctx, argv: []const []const u8) bool {
    const result = std.process.run(c.arena, c._io, .{
        .argv = argv,
    }) catch return false;
    return switch (result.term) {
        .exited => |code| code == 0,
        else => false,
    };
}

pub fn runtimeLogExcerpt(raw: []const u8) []const u8 {
    const limit: usize = 1800;
    if (raw.len <= limit) return raw;
    return raw[raw.len - limit ..];
}

pub fn runtimeHostPort(workspace_id: i32) i32 {
    const base_port = spider.env.getInt(i32, "ZIVYAR_RUNTIME_HOST_PORT_BASE", 43000);
    return base_port + workspace_id;
}

pub fn waitForOpenCodeHealth(c: *spider.Ctx, server_url: []const u8) bool {
    const health_url = std.fmt.allocPrint(c.arena, "{s}/global/health", .{server_url}) catch return false;
    var attempt: usize = 0;
    while (attempt < 12) : (attempt += 1) {
        if (commandSucceeded(c, &.{"curl", "-fsS", health_url})) return true;
        std.Io.sleep(c._io, std.Io.Duration.fromMilliseconds(500), .real) catch {};
    }
    return false;
}

pub fn containsAsciiCaseInsensitive(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (haystack.len < needle.len) return false;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        var j: usize = 0;
        while (j < needle.len) : (j += 1) {
            if (std.ascii.toLower(haystack[i + j]) != std.ascii.toLower(needle[j])) break;
        }
        if (j == needle.len) return true;
    }
    return false;
}
