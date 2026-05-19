const spider = @import("spider");

pub const spider_templates = @import("embedded_templates.zig").EmbeddedTemplates;

pub fn main() !void {
    var server = spider.server();
    defer server.deinit();

    server
        .get("/", dashboard)
        .get("/workspaces", workspaces)
        .get("/workspaces/new", workspaceNew)
        .get("/missions", missions)
        .get("/agents", agents)
        .get("/squads", squads)
        .get("/providers", providers)
        .listen(.{}) catch {};
}

fn dashboard(c: *spider.Ctx) !spider.Response {
    return c.view("dashboard/index", .{
        .title = "Zivyar Cockpit",
        .subtitle = "Desktop Multi-Agent Engineering Cockpit",
    }, .{});
}

fn workspaces(c: *spider.Ctx) !spider.Response {
    return c.view("workspaces/index", .{ .title = "Workspaces" }, .{});
}

fn workspaceNew(c: *spider.Ctx) !spider.Response {
    return c.view("workspaces/new", .{ .title = "Novo Workspace" }, .{});
}

fn missions(c: *spider.Ctx) !spider.Response {
    return c.view("missions/index", .{ .title = "Missions" }, .{});
}

fn agents(c: *spider.Ctx) !spider.Response {
    return c.view("agents/index", .{ .title = "Agents" }, .{});
}

fn squads(c: *spider.Ctx) !spider.Response {
    return c.view("squads/index", .{ .title = "Squads" }, .{});
}

fn providers(c: *spider.Ctx) !spider.Response {
    return c.view("providers/index", .{ .title = "Providers" }, .{});
}
