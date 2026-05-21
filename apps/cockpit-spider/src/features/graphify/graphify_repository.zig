const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const model = @import("./graphify_model.zig");

pub fn getWorkspace(c: *spider.Ctx, id: i32) !?model.WorkspaceRow {
    const rows = try db.query(model.WorkspaceRow, c.arena,
        \\SELECT w.id, w.name, w.local_path, w.stack_name, w.default_squad_id,
        \\       COALESCE(s.name, 'Sem squad vinculada') AS squad_name, w.status
        \\FROM workspaces w
        \\LEFT JOIN squads s ON s.id = w.default_squad_id
        \\WHERE w.id = $1 LIMIT 1
    , .{id});
    if (rows.len == 0) return null;
    return rows[0];
}

pub fn listMemoryEntries(c: *spider.Ctx, workspace_id: i32) ![]model.WorkspaceMemoryEntryRow {
    return db.query(model.WorkspaceMemoryEntryRow, c.arena,
        \\SELECT id, title, content, TO_CHAR(created_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS') AS created_at_label
        \\FROM workspace_memory_entries WHERE workspace_id = $1 ORDER BY id DESC LIMIT 8
    , .{workspace_id});
}

pub fn listHandoffs(c: *spider.Ctx, workspace_id: i32) ![]model.WorkspaceHandoffRow {
    return db.query(model.WorkspaceHandoffRow, c.arena,
        \\SELECT id, from_role, to_role, summary, context, TO_CHAR(created_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS') AS created_at_label
        \\FROM workspace_handoffs WHERE workspace_id = $1 ORDER BY id DESC LIMIT 8
    , .{workspace_id});
}

pub fn listDecisionRecords(c: *spider.Ctx, workspace_id: i32) ![]model.WorkspaceDecisionRecordRow {
    return db.query(model.WorkspaceDecisionRecordRow, c.arena,
        \\SELECT id, title, decision, rationale, TO_CHAR(created_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS') AS created_at_label
        \\FROM workspace_decision_records WHERE workspace_id = $1 ORDER BY id DESC LIMIT 8
    , .{workspace_id});
}

pub fn listSnapshots(c: *spider.Ctx, workspace_id: i32) ![]model.WorkspaceSnapshotRow {
    return db.query(model.WorkspaceSnapshotRow, c.arena,
        \\SELECT id, title, scope, content, TO_CHAR(created_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS') AS created_at_label
        \\FROM workspace_snapshots WHERE workspace_id = $1 ORDER BY id DESC LIMIT 8
    , .{workspace_id});
}
