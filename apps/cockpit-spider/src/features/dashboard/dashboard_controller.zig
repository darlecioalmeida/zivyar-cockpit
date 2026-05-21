const std = @import("std");
const spider = @import("spider");
const repo = @import("./dashboard_repository.zig");

pub fn index(c: *spider.Ctx) !spider.Response {
    const ws_count = try repo.countWorkspaces(c);
    const mission_count = try repo.countMissions(c);
    const agent_count = try repo.countAgents(c);
    const recent_workspaces = try repo.listRecentWorkspaces(c);
    const recent_missions = try repo.listRecentMissions(c);
    return c.view("dashboard/index", .{
        .title = "Dashboard",
        .workspace_count = ws_count,
        .mission_count = mission_count,
        .agent_count = agent_count,
        .recent_workspaces = recent_workspaces,
        .recent_missions = recent_missions,
    }, .{});
}
