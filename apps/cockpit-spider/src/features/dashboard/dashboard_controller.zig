const std = @import("std");
const spider = @import("spider");
const repo = @import("./dashboard_repository.zig");

pub fn index(c: *spider.Ctx) !spider.Response {
    const ws_count = try repo.countWorkspaces(c);
    const mission_count = try repo.countMissions(c);
    const open_mission_count = try repo.countOpenMissions(c);
    const agent_count = try repo.countAgents(c);
    const squad_count = try repo.countSquads(c);
    const provider_count = try repo.countProviders(c);
    const stack_count = try repo.countStacks(c);
    const recent_workspaces = try repo.listRecentWorkspaces(c);
    const recent_missions = try repo.listRecentMissions(c);
    return c.view("dashboard/index", .{
        .title = "Dashboard",
        .subtitle = "Fundação operacional",
        .workspace_count = ws_count,
        .mission_count = mission_count,
        .open_mission_count = open_mission_count,
        .agent_count = agent_count,
        .squad_count = squad_count,
        .provider_count = provider_count,
        .stack_count = stack_count,
        .recent_workspace_count = recent_workspaces.len,
        .recent_workspaces = recent_workspaces,
        .recent_mission_count = recent_missions.len,
        .recent_missions = recent_missions,
    }, .{});
}
