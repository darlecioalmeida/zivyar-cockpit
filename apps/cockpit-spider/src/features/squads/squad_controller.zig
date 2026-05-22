const std = @import("std");
const spider = @import("spider");
const model = @import("./squad_model.zig");
const repo = @import("./squad_repository.zig");

pub fn index(c: *spider.Ctx) !spider.Response {
    const squads_list = try repo.listAll(c);
    var active_count: i32 = 0;
    for (squads_list) |s| {
        if (s.is_active) active_count += 1;
    }
    return c.view("squads/index", .{
        .title = "Squads",
        .squads = squads_list,
        .squad_count = squads_list.len,
        .active_count = active_count,
    }, .{});
}

pub fn newForm(c: *spider.Ctx) !spider.Response {
    const agent_options = try repo.listAgentOptions(c);
    return c.view("squads/new", .{
        .title = "Nova Squad",
        .agent_options = agent_options,
    }, .{});
}

pub fn create(c: *spider.Ctx) !spider.Response {
    const form = try c.parseForm(model.SquadForm);
    const squad_id = try repo.create(c, form);
    const role_agent_pairs = [_]struct { role: []const u8, field: []const u8, order: i32 }{
        .{.role = "Piloto", .field = form.pilot_agent_id, .order = 1},
        .{.role = "Planner", .field = form.planner_agent_id, .order = 2},
        .{.role = "Scout", .field = form.scout_agent_id, .order = 3},
        .{.role = "Builder", .field = form.builder_agent_id, .order = 4},
        .{.role = "Reviewer", .field = form.reviewer_agent_id, .order = 5},
        .{.role = "Executor", .field = form.executor_agent_id, .order = 6},
    };
    inline for (role_agent_pairs) |pair| {
        if (pair.field.len > 0) {
            const agent_id = try std.fmt.parseInt(i32, pair.field, 10);
            try repo.insertMember(c, squad_id, pair.role, agent_id, pair.order);
        }
    }
    return c.redirect("/squads");
}

pub fn show(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse return c.text("Squad não informada.", .{.status = .bad_request});
    const id = std.fmt.parseInt(i32, id_raw, 10) catch return c.text("Squad inválida.", .{.status = .bad_request});
    const squad = (try repo.getById(c, id)) orelse return c.text("Squad não encontrada.", .{.status = .not_found});
    const members = try repo.listMembers(c, id);
    return c.view("squads/show", .{
        .title = squad.name,
        .squad = squad,
        .members = members,
    }, .{});
}

pub fn edit(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse return c.text("Squad não informada.", .{.status = .bad_request});
    const id = std.fmt.parseInt(i32, id_raw, 10) catch return c.text("Squad inválida.", .{.status = .bad_request});
    const squad = (try repo.getById(c, id)) orelse return c.text("Squad não encontrada.", .{.status = .not_found});
    const agent_options = try repo.listAgentOptions(c);
    const members = try repo.listMembers(c, id);
    return c.view("squads/edit", .{
        .title = squad.name,
        .squad = squad,
        .agent_options = agent_options,
        .members = members,
    }, .{});
}

pub fn update(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse return c.text("Squad não informada.", .{.status = .bad_request});
    const id = std.fmt.parseInt(i32, id_raw, 10) catch return c.text("Squad inválida.", .{.status = .bad_request});
    const form = try c.parseForm(model.SquadForm);
    try repo.update(c, id, form);
    try repo.removeMembers(c, id);
    const role_agent_pairs = [_]struct { role: []const u8, field: []const u8, order: i32 }{
        .{.role = "Piloto", .field = form.pilot_agent_id, .order = 1},
        .{.role = "Planner", .field = form.planner_agent_id, .order = 2},
        .{.role = "Scout", .field = form.scout_agent_id, .order = 3},
        .{.role = "Builder", .field = form.builder_agent_id, .order = 4},
        .{.role = "Reviewer", .field = form.reviewer_agent_id, .order = 5},
        .{.role = "Executor", .field = form.executor_agent_id, .order = 6},
    };
    inline for (role_agent_pairs) |pair| {
        if (pair.field.len > 0) {
            const agent_id = try std.fmt.parseInt(i32, pair.field, 10);
            try repo.insertMember(c, id, pair.role, agent_id, pair.order);
        }
    }
    return c.redirect("/squads");
}

pub fn delete(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse return c.text("Squad não informada.", .{.status = .bad_request});
    const id = std.fmt.parseInt(i32, id_raw, 10) catch return c.text("Squad inválida.", .{.status = .bad_request});
    try repo.delete(c, id);
    return c.redirect("/squads");
}
