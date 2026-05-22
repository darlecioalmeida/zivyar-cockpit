const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const model = @import("./provider_model.zig");

pub fn listProviders(c: *spider.Ctx) ![]model.ProviderRow {
    return db.query(model.ProviderRow, c.arena,
        \\SELECT id, name, provider_type, base_url, api_key, is_active
        \\FROM providers ORDER BY name ASC
    , .{});
}

pub fn getProvider(c: *spider.Ctx, id: i32) !?model.ProviderRow {
    const rows = try db.query(model.ProviderRow, c.arena,
        \\SELECT id, name, provider_type, base_url, api_key, is_active
        \\FROM providers WHERE id = $1 LIMIT 1
    , .{id});
    if (rows.len == 0) return null;
    return rows[0];
}

pub fn createProvider(c: *spider.Ctx, form: model.ProviderForm) !void {
    try db.query(void, c.arena,
        \\INSERT INTO providers (name, provider_type, base_url, api_key, is_active)
        \\VALUES ($1, $2, $3, $4, $5)
    , .{form.name, form.provider_type, form.base_url, form.api_key, form.is_active});
}

pub fn updateProvider(c: *spider.Ctx, id: i32, form: model.ProviderForm) !void {
    try db.query(void, c.arena,
        \\UPDATE providers SET name=$1, provider_type=$2, base_url=$3, api_key=$4, is_active=$5
        \\WHERE id=$6
    , .{form.name, form.provider_type, form.base_url, form.api_key, form.is_active, id});
}

pub fn deleteProvider(c: *spider.Ctx, id: i32) !void {
    try db.query(void, c.arena, "DELETE FROM providers WHERE id = $1", .{id});
}

pub fn listModels(c: *spider.Ctx, provider_id: i32) ![]model.ProviderModelWithProviderRow {
    return db.query(model.ProviderModelWithProviderRow, c.arena,
        \\SELECT pm.id, pm.provider_id, pm.model_name, pm.model_id, pm.context_window, pm.is_active,
        \\       COALESCE(p.name, '') AS provider_name, COALESCE(p.provider_type, '') AS provider_type
        \\FROM provider_models pm
        \\LEFT JOIN providers p ON p.id = pm.provider_id
        \\WHERE pm.provider_id = $1
        \\ORDER BY pm.model_name ASC
    , .{provider_id});
}

pub fn getModel(c: *spider.Ctx, model_id: i32) !?model.ProviderModelWithProviderRow {
    const rows = try db.query(model.ProviderModelWithProviderRow, c.arena,
        \\SELECT pm.id, pm.provider_id, pm.model_name, pm.model_id, pm.context_window, pm.is_active,
        \\       COALESCE(p.name, '') AS provider_name, COALESCE(p.provider_type, '') AS provider_type
        \\FROM provider_models pm
        \\LEFT JOIN providers p ON p.id = pm.provider_id
        \\WHERE pm.id = $1 LIMIT 1
    , .{model_id});
    if (rows.len == 0) return null;
    return rows[0];
}

pub fn createModel(c: *spider.Ctx, provider_id: i32, form: model.ProviderModelForm) !void {
    try db.query(void, c.arena,
        \\INSERT INTO provider_models (provider_id, model_name, model_id, context_window, is_active)
        \\VALUES ($1, $2, $3, $4, $5)
    , .{provider_id, form.model_name, form.model_id, form.context_window, form.is_active});
}

pub fn updateModel(c: *spider.Ctx, model_id: i32, form: model.ProviderModelForm) !void {
    try db.query(void, c.arena,
        \\UPDATE provider_models SET model_name=$1, model_id=$2, context_window=$3, is_active=$4
        \\WHERE id=$5
    , .{form.model_name, form.model_id, form.context_window, form.is_active, model_id});
}

pub fn deleteModel(c: *spider.Ctx, model_id: i32) !void {
    try db.query(void, c.arena, "DELETE FROM provider_models WHERE id = $1", .{model_id});
}

pub fn countAllModels(c: *spider.Ctx) !i32 {
    const rows = try db.query(i32, c.arena, "SELECT COUNT(*) FROM provider_models", .{});
    return rows;
}
