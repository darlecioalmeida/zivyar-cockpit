const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const model = @import("./stack_model.zig");

pub fn listAll(c: *spider.Ctx) ![]model.StackRow {
    return db.query(model.StackRow, c.arena,
        \\SELECT s.id, s.name, s.runtime_tool, s.provider_model_id,
        \\       COALESCE(pm.model_name, '') AS model_name,
        \\       COALESCE(pm.model_id, '') AS model_identifier,
        \\       COALESCE(p.name, '') AS provider_name,
        \\       s.is_active
        \\FROM stacks s
        \\LEFT JOIN provider_models pm ON pm.id = s.provider_model_id
        \\LEFT JOIN providers p ON p.id = pm.provider_id
        \\ORDER BY s.name ASC
    , .{});
}

pub fn getById(c: *spider.Ctx, id: i32) !?model.StackRow {
    const rows = try db.query(model.StackRow, c.arena,
        \\SELECT s.id, s.name, s.runtime_tool, s.provider_model_id,
        \\       COALESCE(pm.model_name, '') AS model_name,
        \\       COALESCE(pm.model_id, '') AS model_identifier,
        \\       COALESCE(p.name, '') AS provider_name,
        \\       s.is_active
        \\FROM stacks s
        \\LEFT JOIN provider_models pm ON pm.id = s.provider_model_id
        \\LEFT JOIN providers p ON p.id = pm.provider_id
        \\WHERE s.id = $1
        \\LIMIT 1
    , .{id});
    if (rows.len == 0) return null;
    return rows[0];
}

pub fn create(c: *spider.Ctx, form: model.StackForm) !void {
    try db.query(void, c.arena,
        \\INSERT INTO stacks (name, runtime_tool, provider_model_id, is_active)
        \\VALUES ($1, $2, $3, $4)
    , .{form.name, form.runtime_tool, form.provider_model_id, form.is_active});
}

pub fn update(c: *spider.Ctx, id: i32, form: model.StackForm) !void {
    try db.query(void, c.arena,
        \\UPDATE stacks SET name=$1, runtime_tool=$2, provider_model_id=$3, is_active=$4
        \\WHERE id=$5
    , .{form.name, form.runtime_tool, form.provider_model_id, form.is_active, id});
}

pub fn delete(c: *spider.Ctx, id: i32) !void {
    try db.query(void, c.arena, "DELETE FROM stacks WHERE id = $1", .{id});
}

pub fn listModelOptions(c: *spider.Ctx) ![]model.StackModelOptionRow {
    return db.query(model.StackModelOptionRow, c.arena,
        \\SELECT pm.id, pm.model_name, pm.model_id AS model_identifier,
        \\       COALESCE(p.name, '') AS provider_name
        \\FROM provider_models pm
        \\LEFT JOIN providers p ON p.id = pm.provider_id
        \\WHERE pm.is_active = TRUE
        \\ORDER BY p.name ASC, pm.model_name ASC
    , .{});
}
