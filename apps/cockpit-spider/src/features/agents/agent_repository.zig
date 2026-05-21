const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const model = @import("./agent_model.zig");

pub fn listAll(c: *spider.Ctx) ![]model.AgentRow {
    return db.query(model.AgentRow, c.arena,
        \\SELECT a.id, a.name, a.handle, a.agent_role, a.summary, a.system_prompt,
        \\       a.operating_rules, a.default_stack_id, COALESCE(s.name, 'Nenhuma') AS stack_name,
        \\       COALESCE(s.runtime_tool, '') AS runtime_tool,
        \\       COALESCE(pm.model_name, '') AS model_name,
        \\       a.is_active
        \\FROM agents a
        \\LEFT JOIN stacks s ON s.id = a.default_stack_id
        \\LEFT JOIN provider_models pm ON pm.id = s.provider_model_id
        \\ORDER BY a.name ASC
    , .{});
}

pub fn getById(c: *spider.Ctx, id: i32) !?model.AgentRow {
    const rows = try db.query(model.AgentRow, c.arena,
        \\SELECT a.id, a.name, a.handle, a.agent_role, a.summary, a.system_prompt,
        \\       a.operating_rules, a.default_stack_id, COALESCE(s.name, 'Nenhuma') AS stack_name,
        \\       COALESCE(s.runtime_tool, '') AS runtime_tool,
        \\       COALESCE(pm.model_name, '') AS model_name,
        \\       a.is_active
        \\FROM agents a
        \\LEFT JOIN stacks s ON s.id = a.default_stack_id
        \\LEFT JOIN provider_models pm ON pm.id = s.provider_model_id
        \\WHERE a.id = $1
        \\LIMIT 1
    , .{id});
    if (rows.len == 0) return null;
    return rows[0];
}

pub fn create(c: *spider.Ctx, form: model.AgentForm) !void {
    try db.query(void, c.arena,
        \\INSERT INTO agents (name, handle, agent_role, summary, system_prompt, operating_rules, default_stack_id, is_active)
        \\VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    , .{form.name, form.handle, form.agent_role, form.summary, form.system_prompt, form.operating_rules, form.default_stack_id, form.is_active});
}

pub fn update(c: *spider.Ctx, id: i32, form: model.AgentForm) !void {
    try db.query(void, c.arena,
        \\UPDATE agents SET name=$1, handle=$2, agent_role=$3, summary=$4, system_prompt=$5,
        \\    operating_rules=$6, default_stack_id=$7, is_active=$8
        \\WHERE id=$9
    , .{form.name, form.handle, form.agent_role, form.summary, form.system_prompt, form.operating_rules, form.default_stack_id, form.is_active, id});
}

pub fn delete(c: *spider.Ctx, id: i32) !void {
    try db.query(void, c.arena, "DELETE FROM agents WHERE id = $1", .{id});
}

pub fn listStackOptions(c: *spider.Ctx) ![]model.AgentStackOptionRow {
    return db.query(model.AgentStackOptionRow, c.arena,
        \\SELECT s.id, s.name, s.runtime_tool, COALESCE(pm.model_name, '') AS model_name
        \\FROM stacks s
        \\LEFT JOIN provider_models pm ON pm.id = s.provider_model_id
        \\WHERE s.is_active = TRUE
        \\ORDER BY s.name ASC
    , .{});
}
