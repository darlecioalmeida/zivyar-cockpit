const spider = @import("spider");

pub fn main() !void {
    var server = spider.server();
    defer server.deinit();

    server
        .get("/", dashboard)
        .get("/workspaces", workspaces)
        .get("/missions", missions)
        .get("/agents", agents)
        .get("/squads", squads)
        .get("/providers", providers)
        .listen(.{}) catch {};
}

fn dashboard(c: *spider.Ctx) !spider.Response {
    return c.view("features/dashboard/views/index", .{
        .title = "Zivyar Cockpit",
        .subtitle = "Desktop Multi-Agent Engineering Cockpit",
    }, .{});
}

fn workspaces(c: *spider.Ctx) !spider.Response {
    return c.view("features/workspaces/views/index", .{ .title = "Workspaces" }, .{});
}

fn missions(c: *spider.Ctx) !spider.Response {
    return c.view("features/missions/views/index", .{ .title = "Missions" }, .{});
}

fn agents(c: *spider.Ctx) !spider.Response {
    return c.view("features/agents/views/index", .{ .title = "Agents" }, .{});
}

fn squads(c: *spider.Ctx) !spider.Response {
    return c.view("features/squads/views/index", .{ .title = "Squads" }, .{});
}

fn providers(c: *spider.Ctx) !spider.Response {
    return c.view("features/providers/views/index", .{ .title = "Providers" }, .{});
}
