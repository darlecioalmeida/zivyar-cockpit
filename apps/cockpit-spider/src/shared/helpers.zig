const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const core = @import("core");

pub fn ensureWorkspaceLocalPath(c: *spider.Ctx, local_path: []const u8) bool {
    if (local_path.len == 0) return false;
    return core.commandSucceeded(c, &.{"mkdir", "-p", local_path});
}

pub fn insertRuntimeEvent(c: *spider.Ctx, workspace_id: i32, event_type: []const u8, title: []const u8, message: []const u8) !void {
    try db.query(void, c.arena,
        \\INSERT INTO workspace_runtime_events (workspace_id, event_type, title, message)
        \\VALUES ($1, $2, $3, $4)
    , .{workspace_id, event_type, title, message});
}

pub fn openCodeSessionExists(c: *spider.Ctx, server_url: []const u8, session_id: []const u8) core.RuntimeCommandResult {
    const session_url = std.fmt.allocPrint(c.arena, "{s}/session/{s}", .{server_url, session_id}) catch {
        return .{.ok = false, .exit_code = -1, .stdout = "", .stderr = "Falha ao montar URL da sessão OpenCode."};
    };
    return core.runRuntimeCommand(c, &.{"curl", "-fsS", session_url});
}

pub fn extractOpenCodeSessionId(raw: []const u8) ?[]const u8 {
    const key = "\"id\"";
    const key_index = std.mem.indexOf(u8, raw, key) orelse return null;
    var cursor: usize = key_index + key.len;
    while (cursor < raw.len and raw[cursor] != ':') : (cursor += 1) {}
    if (cursor >= raw.len) return null;
    cursor += 1;
    while (cursor < raw.len and (raw[cursor] == ' ' or raw[cursor] == '\n' or raw[cursor] == '\r' or raw[cursor] == '\t')) : (cursor += 1) {}
    if (cursor >= raw.len or raw[cursor] != '"') return null;
    const start = cursor + 1;
    cursor = start;
    while (cursor < raw.len and raw[cursor] != '"') : (cursor += 1) {}
    if (cursor >= raw.len) return null;
    return raw[start..cursor];
}

pub fn extractLatestUserMessageIdMatchingText(allocator: std.mem.Allocator, raw: []const u8, expected_text: []const u8) !?[]const u8 {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, raw, .{});
    defer parsed.deinit();
    const root = parsed.value;
    if (root != .array) return null;
    var latest_id: ?[]const u8 = null;
    for (root.array.items) |message_value| {
        if (message_value != .object) continue;
        const message_obj = message_value.object;
        const info_value = message_obj.get("info") orelse continue;
        if (info_value != .object) continue;
        const role_value = info_value.object.get("role") orelse continue;
        if (role_value != .string) continue;
        if (!std.mem.eql(u8, role_value.string, "user")) continue;
        const message_id_value = info_value.object.get("id") orelse continue;
        if (message_id_value != .string) continue;
        const parts_value = message_obj.get("parts") orelse continue;
        if (parts_value != .array) continue;
        var matches_dispatch = false;
        for (parts_value.array.items) |part_value| {
            if (part_value != .object) continue;
            const part_obj = part_value.object;
            const type_value = part_obj.get("type") orelse continue;
            if (type_value != .string) continue;
            if (!std.mem.eql(u8, type_value.string, "text")) continue;
            const text_value = part_obj.get("text") orelse continue;
            if (text_value != .string) continue;
            if (std.mem.eql(u8, text_value.string, expected_text)) { matches_dispatch = true; break; }
        }
        if (matches_dispatch) latest_id = try allocator.dupe(u8, message_id_value.string);
    }
    return latest_id;
}

pub fn extractAssistantTextForParentMessage(allocator: std.mem.Allocator, raw: []const u8, parent_message_id: []const u8) !?[]const u8 {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, raw, .{});
    defer parsed.deinit();
    const root = parsed.value;
    if (root != .array) return null;
    var latest_text: ?[]const u8 = null;
    for (root.array.items) |message_value| {
        if (message_value != .object) continue;
        const message_obj = message_value.object;
        const info_value = message_obj.get("info") orelse continue;
        if (info_value != .object) continue;
        const role_value = info_value.object.get("role") orelse continue;
        if (role_value != .string) continue;
        if (!std.mem.eql(u8, role_value.string, "assistant")) continue;
        const parent_value = info_value.object.get("parentID") orelse continue;
        if (parent_value != .string) continue;
        if (!std.mem.eql(u8, parent_value.string, parent_message_id)) continue;
        const parts_value = message_obj.get("parts") orelse continue;
        if (parts_value != .array) continue;
        var collected: std.ArrayList(u8) = .empty;
        errdefer collected.deinit(allocator);
        var found_text = false;
        for (parts_value.array.items) |part_value| {
            if (part_value != .object) continue;
            const part_obj = part_value.object;
            const type_value = part_obj.get("type") orelse continue;
            if (type_value != .string) continue;
            if (!std.mem.eql(u8, type_value.string, "text")) continue;
            const text_value = part_obj.get("text") orelse continue;
            if (text_value != .string) continue;
            if (found_text) try collected.appendSlice(allocator, "\n\n");
            try collected.appendSlice(allocator, text_value.string);
            found_text = true;
        }
        if (found_text) latest_text = try collected.toOwnedSlice(allocator) else collected.deinit(allocator);
    }
    return latest_text;
}

pub fn extractLatestAssistantTextFromOpenCodeMessages(allocator: std.mem.Allocator, raw: []const u8) !?[]const u8 {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, raw, .{});
    defer parsed.deinit();
    const root = parsed.value;
    if (root != .array) return null;
    var latest_text: ?[]const u8 = null;
    for (root.array.items) |message_value| {
        if (message_value != .object) continue;
        const message_obj = message_value.object;
        const info_value = message_obj.get("info") orelse continue;
        if (info_value != .object) continue;
        const role_value = info_value.object.get("role") orelse continue;
        if (role_value != .string) continue;
        if (!std.mem.eql(u8, role_value.string, "assistant")) continue;
        const parts_value = message_obj.get("parts") orelse continue;
        if (parts_value != .array) continue;
        var collected: std.ArrayList(u8) = .empty;
        errdefer collected.deinit(allocator);
        var found_text = false;
        for (parts_value.array.items) |part_value| {
            if (part_value != .object) continue;
            const part_obj = part_value.object;
            const type_value = part_obj.get("type") orelse continue;
            if (type_value != .string) continue;
            if (!std.mem.eql(u8, type_value.string, "text")) continue;
            const text_value = part_obj.get("text") orelse continue;
            if (text_value != .string) continue;
            if (found_text) try collected.appendSlice(allocator, "\n\n");
            try collected.appendSlice(allocator, text_value.string);
            found_text = true;
        }
        if (found_text) latest_text = try collected.toOwnedSlice(allocator) else collected.deinit(allocator);
    }
    return latest_text;
}

pub fn extractMissionFinalVerdictFromPilotDeliveryReport(report: []const u8) []const u8 {
    const completed_patterns = [_][]const u8{
        "**status final:** completed", "status final: completed",
        "**veredito final:** completed", "veredito final: completed",
        "**conclusão operacional:** completed", "conclusão operacional: completed",
        "**status** | `completed`", "status | `completed`",
        "**status** | completed", "status | completed",
        "## ✅ completed", "## 🟢 completed", "## completed",
    };
    for (completed_patterns) |p| { if (containsAsciiCaseInsensitive(report, p)) return "completed"; }
    const follow_up_patterns = [_][]const u8{
        "**status final:** needs_follow_up", "status final: needs_follow_up",
        "**veredito final:** needs_follow_up", "veredito final: needs_follow_up",
        "**conclusão operacional:** needs_follow_up", "conclusão operacional: needs_follow_up",
        "**status** | `needs_follow_up`", "status | `needs_follow_up`",
        "**status** | needs_follow_up", "status | needs_follow_up",
        "## 🟡 needs_follow_up", "## needs_follow_up",
    };
    for (follow_up_patterns) |p| { if (containsAsciiCaseInsensitive(report, p)) return "needs_follow_up"; }
    const blocked_patterns = [_][]const u8{
        "**status final:** blocked", "status final: blocked",
        "**veredito final:** blocked", "veredito final: blocked",
        "**conclusão operacional:** blocked", "conclusão operacional: blocked",
        "**status** | `blocked`", "status | `blocked`",
        "**status** | blocked", "status | blocked",
        "## 🔴 blocked", "## blocked",
    };
    for (blocked_patterns) |p| { if (containsAsciiCaseInsensitive(report, p)) return "blocked"; }
    return "";
}

fn containsAsciiCaseInsensitive(haystack: []const u8, needle: []const u8) bool {
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
