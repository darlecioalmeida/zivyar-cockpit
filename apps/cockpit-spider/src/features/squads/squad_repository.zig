const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const model = @import("./squad_model.zig");

pub fn listAll(c: *spider.Ctx) ![]model.SquadRow {
    return db.query(model.SquadRow, c.arena,
        \\SELECT id, name, slug, summary, is_default, is_active
        \\FROM squads ORDER BY is_default DESC, name ASC
    , .{});
}

pub fn getById(c: *spider.Ctx, id: i32) !?model.SquadRow {
    const rows = try db.query(model.SquadRow, c.arena,
        \\SELECT id, name, slug, summary, is_default, is_active
        \\FROM squads WHERE id = $1 LIMIT 1
    , .{id});
    if (rows.len == 0) return null;
    return rows[0];
}

pub fn create(c: *spider.Ctx, form: model.SquadForm) !i32 {
    const result = try db.query(model.SquadIdRow, c.arena,
        \\INSERT INTO squads (name, slug, summary, is_default, is_active)
        \\VALUES ($1, $2, $3, $4, $5) RETURNING id
    , .{form.name, form.slug, form.summary, form.is_default, form.is_active});
    return result[0].id;
}

pub fn update(c: *spider.Ctx, id: i32, form: model.SquadForm) !void {
    try db.query(void, c.arena,
        \\UPDATE squads SET name=$1, slug=$2, summary=$3, is_default=$4, is_active=$5
        \\WHERE id=$6
    , .{form.name, form.slug, form.summary, form.is_default, form.is_active, id});
}

pub fn delete(c: *spider.Ctx, id: i32) !void {
    try db.query(void, c.arena, "DELETE FROM squads WHERE id = $1", .{id});
}

pub fn listAgentOptions(c: *spider.Ctx) ![]model.SquadAgentOptionRow {
    return db.query(model.SquadAgentOptionRow, c.arena,
        \\SELECT id, name, handle, agent_role
        \\FROM agents WHERE is_active = TRUE ORDER BY name ASC
    , .{});
}

pub fn listMembers(c: *spider.Ctx, squad_id: i32) ![]model.SquadMemberRow {
    return db.query(model.SquadMemberRow, c.arena,
        \\SELECT sm.id, sm.squad_id, sm.role_name, sm.agent_id, sm.display_order,
        \\       COALESCE(a.name, '') AS agent_name,
        \\       COALESCE(a.handle, '') AS agent_handle,
        \\       COALESCE(a.agent_role, '') AS agent_role,
        \\       COALESCE(s.name, '') AS stack_name
        \\FROM squad_members sm
        \\LEFT JOIN agents a ON a.id = sm.agent_id
        \\LEFT JOIN stacks s ON s.id = a.default_stack_id
        \\WHERE sm.squad_id = $1
        \\ORDER BY sm.display_order ASC
    , .{squad_id});
}

pub fn insertMember(c: *spider.Ctx, squad_id: i32, role_name: []const u8, agent_id: i32, display_order: i32) !void {
    try db.query(void, c.arena,
        \\INSERT INTO squad_members (squad_id, role_name, agent_id, display_order)
        \\VALUES ($1, $2, $3, $4)
        \\ON CONFLICT (squad_id, role_name) DO UPDATE SET agent_id = $3, display_order = $4
    , .{squad_id, role_name, agent_id, display_order});
}

pub fn removeMembers(c: *spider.Ctx, squad_id: i32) !void {
    try db.query(void, c.arena, "DELETE FROM squad_members WHERE squad_id = $1", .{squad_id});
}
