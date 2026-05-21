const std = @import("std");
const spider = @import("spider");
const repo = @import("./graphify_repository.zig");

pub fn workspaceShow(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse return c.text("Workspace não informado.", .{.status = .bad_request});
    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch return c.text("Workspace inválido.", .{.status = .bad_request});
    const workspace = (try repo.getWorkspace(c, workspace_id)) orelse return c.text("Workspace não encontrado.", .{.status = .not_found});
    const memory_entries = try repo.listMemoryEntries(c, workspace_id);
    const handoffs = try repo.listHandoffs(c, workspace_id);
    const decision_records = try repo.listDecisionRecords(c, workspace_id);
    const snapshots = try repo.listSnapshots(c, workspace_id);
    return c.view("workspaces/graphify", .{
        .title = workspace.name,
        .workspace = workspace,
        .workspace_memory_entries = memory_entries,
        .workspace_memory_count = memory_entries.len,
        .workspace_handoffs = handoffs,
        .workspace_handoff_count = handoffs.len,
        .workspace_decision_records = decision_records,
        .workspace_decision_record_count = decision_records.len,
        .workspace_snapshots = snapshots,
        .workspace_snapshot_count = snapshots.len,
    }, .{});
}

pub fn index(c: *spider.Ctx) !spider.Response {
    const rows = try spider.pg.query(WorkspaceLinkRow, c.arena,
        \\SELECT id, name FROM workspaces ORDER BY name ASC
    , .{});
    return c.view("graphify/index", .{
        .title = "Graphify",
        .workspaces = rows,
    }, .{});
}

const WorkspaceLinkRow = struct { id: i32, name: []const u8 };
