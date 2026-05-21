const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const model = @import("./agent_model.zig");
const repo = @import("./agent_repository.zig");

pub fn index(c: *spider.Ctx) !spider.Response {
    const agents_list = try repo.listAll(c);
    return c.view("agents/index", .{
        .title = "Agentes",
        .agent_list = agents_list,
    }, .{});
}

pub fn newForm(c: *spider.Ctx) !spider.Response {
    const stacks_options = try repo.listStackOptions(c);
    return c.view("agents/new", .{
        .title = "Novo Agente",
        .stack_options = stacks_options,
    }, .{});
}

pub fn create(c: *spider.Ctx) !spider.Response {
    const form = try c.parseForm(model.AgentForm);
    try repo.create(c, form);
    return c.redirect("/agents");
}

pub fn show(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse return c.text("Agente não informado.", .{.status = .bad_request});
    const id = std.fmt.parseInt(i32, id_raw, 10) catch return c.text("Agente inválido.", .{.status = .bad_request});
    const agent = (try repo.getById(c, id)) orelse return c.text("Agente não encontrado.", .{.status = .not_found});
    return c.view("agents/show", .{
        .title = agent.name,
        .agent = agent,
    }, .{});
}

pub fn edit(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse return c.text("Agente não informado.", .{.status = .bad_request});
    const id = std.fmt.parseInt(i32, id_raw, 10) catch return c.text("Agente inválido.", .{.status = .bad_request});
    const agent = (try repo.getById(c, id)) orelse return c.text("Agente não encontrado.", .{.status = .not_found});
    const stacks_options = try repo.listStackOptions(c);
    return c.view("agents/edit", .{
        .title = agent.name,
        .agent = agent,
        .stack_options = stacks_options,
    }, .{});
}

pub fn update(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse return c.text("Agente não informado.", .{.status = .bad_request});
    const id = std.fmt.parseInt(i32, id_raw, 10) catch return c.text("Agente inválido.", .{.status = .bad_request});
    const form = try c.parseForm(model.AgentForm);
    try repo.update(c, id, form);
    return c.redirect("/agents");
}

pub fn delete(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse return c.text("Agente não informado.", .{.status = .bad_request});
    const id = std.fmt.parseInt(i32, id_raw, 10) catch return c.text("Agente inválido.", .{.status = .bad_request});
    try repo.delete(c, id);
    return c.redirect("/agents");
}
