const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const model = @import("./dashboard_model.zig");

pub fn countWorkspaces(c: *spider.Ctx) !i64 {
    const rows = try db.query(model.DashboardCountRow, c.arena, "SELECT COUNT(*) AS total FROM workspaces", .{});
    if (rows.len == 0) return 0;
    return rows[0].total;
}

pub fn countMissions(c: *spider.Ctx) !i64 {
    const rows = try db.query(model.DashboardCountRow, c.arena, "SELECT COUNT(*) AS total FROM missions", .{});
    if (rows.len == 0) return 0;
    return rows[0].total;
}

pub fn countAgents(c: *spider.Ctx) !i64 {
    const rows = try db.query(model.DashboardCountRow, c.arena, "SELECT COUNT(*) AS total FROM agents", .{});
    if (rows.len == 0) return 0;
    return rows[0].total;
}

pub fn listRecentWorkspaces(c: *spider.Ctx) ![]model.DashboardWorkspaceRow {
    return db.query(model.DashboardWorkspaceRow, c.arena,
        \\SELECT w.id, w.name, w.local_path, COALESCE(s.name, 'Sem squad') AS squad_name
        \\FROM workspaces w
        \\LEFT JOIN squads s ON s.id = w.default_squad_id
        \\ORDER BY w.id DESC
        \\LIMIT 8
    , .{});
}

pub fn listRecentMissions(c: *spider.Ctx) ![]model.DashboardMissionRow {
    return db.query(model.DashboardMissionRow, c.arena,
        \\SELECT m.id, m.title, COALESCE(w.name, 'Sem workspace') AS workspace_name,
        \\       COALESCE(s.name, 'Sem squad') AS squad_name, m.status, m.priority
        \\FROM missions m
        \\LEFT JOIN workspaces w ON w.id = m.workspace_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\ORDER BY m.id DESC
        \\LIMIT 8
    , .{});
}

pub fn countOpenMissions(c: *spider.Ctx) !i64 {
    const rows = try db.query(model.DashboardCountRow, c.arena,
        "SELECT COUNT(*) AS total FROM missions WHERE status != 'closed' AND status != 'canceled'", .{});
    if (rows.len == 0) return 0;
    return rows[0].total;
}

pub fn countSquads(c: *spider.Ctx) !i64 {
    const rows = try db.query(model.DashboardCountRow, c.arena,
        "SELECT COUNT(*) AS total FROM squads", .{});
    if (rows.len == 0) return 0;
    return rows[0].total;
}

pub fn countProviders(c: *spider.Ctx) !i64 {
    const rows = try db.query(model.DashboardCountRow, c.arena,
        "SELECT COUNT(*) AS total FROM providers", .{});
    if (rows.len == 0) return 0;
    return rows[0].total;
}

pub fn countStacks(c: *spider.Ctx) !i64 {
    const rows = try db.query(model.DashboardCountRow, c.arena,
        "SELECT COUNT(*) AS total FROM stacks", .{});
    if (rows.len == 0) return 0;
    return rows[0].total;
}
