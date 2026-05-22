const std = @import("std");
const spider = @import("spider");
const model = @import("./stack_model.zig");
const repo = @import("./stack_repository.zig");

pub fn index(c: *spider.Ctx) !spider.Response {
    const stacks_list = try repo.listAll(c);
    var active_count: i32 = 0;
    for (stacks_list) |s| {
        if (s.is_active) active_count += 1;
    }
    return c.view("stacks/index", .{
        .title = "Stacks",
        .stacks = stacks_list,
        .stack_count = stacks_list.len,
        .active_count = active_count,
    }, .{});
}

pub fn newForm(c: *spider.Ctx) !spider.Response {
    const model_options = try repo.listModelOptions(c);
    return c.view("stacks/new", .{
        .title = "Nova Stack",
        .model_options = model_options,
    }, .{});
}

pub fn create(c: *spider.Ctx) !spider.Response {
    const form = try c.parseForm(model.StackForm);
    try repo.create(c, form);
    return c.redirect("/stacks");
}

pub fn edit(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse return c.text("Stack não informada.", .{.status = .bad_request});
    const id = std.fmt.parseInt(i32, id_raw, 10) catch return c.text("Stack inválida.", .{.status = .bad_request});
    const stack = (try repo.getById(c, id)) orelse return c.text("Stack não encontrada.", .{.status = .not_found});
    const model_options = try repo.listModelOptions(c);
    return c.view("stacks/edit", .{
        .title = stack.name,
        .stack = stack,
        .model_options = model_options,
    }, .{});
}

pub fn update(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse return c.text("Stack não informada.", .{.status = .bad_request});
    const id = std.fmt.parseInt(i32, id_raw, 10) catch return c.text("Stack inválida.", .{.status = .bad_request});
    const form = try c.parseForm(model.StackForm);
    try repo.update(c, id, form);
    return c.redirect("/stacks");
}

pub fn delete(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse return c.text("Stack não informada.", .{.status = .bad_request});
    const id = std.fmt.parseInt(i32, id_raw, 10) catch return c.text("Stack inválida.", .{.status = .bad_request});
    try repo.delete(c, id);
    return c.redirect("/stacks");
}
