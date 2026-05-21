const std = @import("std");
const spider = @import("spider");
const model = @import("./provider_model.zig");
const repo = @import("./provider_repository.zig");

pub fn index(c: *spider.Ctx) !spider.Response {
    const providers_list = try repo.listProviders(c);
    return c.view("providers/index", .{
        .title = "Provedores",
        .provider_list = providers_list,
    }, .{});
}

pub fn newForm(c: *spider.Ctx) !spider.Response {
    return c.view("providers/new", .{.title = "Novo Provedor"}, .{});
}

pub fn create(c: *spider.Ctx) !spider.Response {
    const form = try c.parseForm(model.ProviderForm);
    try repo.createProvider(c, form);
    return c.redirect("/providers");
}

pub fn show(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse return c.text("Provedor não informado.", .{.status = .bad_request});
    const id = std.fmt.parseInt(i32, id_raw, 10) catch return c.text("Provedor inválido.", .{.status = .bad_request});
    const provider = (try repo.getProvider(c, id)) orelse return c.text("Provedor não encontrado.", .{.status = .not_found});
    const models = try repo.listModels(c, id);
    return c.view("providers/show", .{
        .title = provider.name,
        .provider = provider,
        .model_list = models,
    }, .{});
}

pub fn edit(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse return c.text("Provedor não informado.", .{.status = .bad_request});
    const id = std.fmt.parseInt(i32, id_raw, 10) catch return c.text("Provedor inválido.", .{.status = .bad_request});
    const provider = (try repo.getProvider(c, id)) orelse return c.text("Provedor não encontrado.", .{.status = .not_found});
    return c.view("providers/edit", .{
        .title = provider.name,
        .provider = provider,
    }, .{});
}

pub fn update(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse return c.text("Provedor não informado.", .{.status = .bad_request});
    const id = std.fmt.parseInt(i32, id_raw, 10) catch return c.text("Provedor inválido.", .{.status = .bad_request});
    const form = try c.parseForm(model.ProviderForm);
    try repo.updateProvider(c, id, form);
    return c.redirect("/providers");
}

pub fn delete(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse return c.text("Provedor não informado.", .{.status = .bad_request});
    const id = std.fmt.parseInt(i32, id_raw, 10) catch return c.text("Provedor inválido.", .{.status = .bad_request});
    try repo.deleteProvider(c, id);
    return c.redirect("/providers");
}

pub fn modelNewForm(c: *spider.Ctx) !spider.Response {
    const provider_id_raw = c.params.get("provider_id") orelse return c.text("Provedor não informado.", .{.status = .bad_request});
    const provider_id = std.fmt.parseInt(i32, provider_id_raw, 10) catch return c.text("Provedor inválido.", .{.status = .bad_request});
    const provider = (try repo.getProvider(c, provider_id)) orelse return c.text("Provedor não encontrado.", .{.status = .not_found});
    return c.view("providers/models_new", .{
        .title = "Novo Modelo",
        .provider = provider,
    }, .{});
}

pub fn modelCreate(c: *spider.Ctx) !spider.Response {
    const provider_id_raw = c.params.get("provider_id") orelse return c.text("Provedor não informado.", .{.status = .bad_request});
    const provider_id = std.fmt.parseInt(i32, provider_id_raw, 10) catch return c.text("Provedor inválido.", .{.status = .bad_request});
    const form = try c.parseForm(model.ProviderModelForm);
    try repo.createModel(c, provider_id, form);
    return c.redirect(try std.fmt.allocPrint(c.arena, "/providers/{d}", .{provider_id}));
}

pub fn modelEdit(c: *spider.Ctx) !spider.Response {
    const provider_id_raw = c.params.get("provider_id") orelse return c.text("Provedor não informado.", .{.status = .bad_request});
    const model_id_raw = c.params.get("model_id") orelse return c.text("Modelo não informado.", .{.status = .bad_request});
    const provider_id = std.fmt.parseInt(i32, provider_id_raw, 10) catch return c.text("Provedor inválido.", .{.status = .bad_request});
    const model_id = std.fmt.parseInt(i32, model_id_raw, 10) catch return c.text("Modelo inválido.", .{.status = .bad_request});
    const provider = (try repo.getProvider(c, provider_id)) orelse return c.text("Provedor não encontrado.", .{.status = .not_found});
    const model_row = (try repo.getModel(c, model_id)) orelse return c.text("Modelo não encontrado.", .{.status = .not_found});
    return c.view("providers/models_edit", .{
        .title = "Editar Modelo",
        .provider = provider,
        .model = model_row,
    }, .{});
}

pub fn modelUpdate(c: *spider.Ctx) !spider.Response {
    const provider_id_raw = c.params.get("provider_id") orelse return c.text("Provedor não informado.", .{.status = .bad_request});
    const model_id_raw = c.params.get("model_id") orelse return c.text("Modelo não informado.", .{.status = .bad_request});
    const provider_id = std.fmt.parseInt(i32, provider_id_raw, 10) catch return c.text("Provedor inválido.", .{.status = .bad_request});
    const model_id = std.fmt.parseInt(i32, model_id_raw, 10) catch return c.text("Modelo inválido.", .{.status = .bad_request});
    const form = try c.parseForm(model.ProviderModelForm);
    try repo.updateModel(c, model_id, form);
    return c.redirect(try std.fmt.allocPrint(c.arena, "/providers/{d}", .{provider_id}));
}

pub fn modelDelete(c: *spider.Ctx) !spider.Response {
    const provider_id_raw = c.params.get("provider_id") orelse return c.text("Provedor não informado.", .{.status = .bad_request});
    const model_id_raw = c.params.get("model_id") orelse return c.text("Modelo não informado.", .{.status = .bad_request});
    const provider_id = std.fmt.parseInt(i32, provider_id_raw, 10) catch return c.text("Provedor inválido.", .{.status = .bad_request});
    const model_id = std.fmt.parseInt(i32, model_id_raw, 10) catch return c.text("Modelo inválido.", .{.status = .bad_request});
    try repo.deleteModel(c, model_id);
    return c.redirect(try std.fmt.allocPrint(c.arena, "/providers/{d}", .{provider_id}));
}
