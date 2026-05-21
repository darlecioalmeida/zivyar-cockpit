pub const DashboardCountRow = struct { total: i64 };

pub const DashboardWorkspaceRow = struct {
    id: i32,
    name: []const u8,
    local_path: []const u8,
    squad_name: []const u8,
};

pub const DashboardMissionRow = struct {
    id: i32,
    title: []const u8,
    workspace_name: []const u8,
    squad_name: []const u8,
    status: []const u8,
    priority: []const u8,
};
