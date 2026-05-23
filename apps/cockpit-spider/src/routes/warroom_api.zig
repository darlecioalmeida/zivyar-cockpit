const std = @import("std");
const spider = @import("spider");
const db = spider.pg;

const WarRoomWorkspaceRow = struct {
    id: i32,
    name: []const u8,
    local_path: []const u8,
    stack_name: []const u8,
    squad_name: []const u8,
    status: []const u8,
};

const WarRoomRuntimeRow = struct {
    state: []const u8,
    container_name: []const u8,
    opencode_port_label: []const u8,
    server_url_label: []const u8,
    status_message: []const u8,
    is_prepared: bool,
};

const WarRoomPaneRow = struct {
    id: i32,
    role_name: []const u8,
    pane_state: []const u8,
    session_external_id: []const u8,
    context_state: []const u8,
    stale_reason: []const u8,
    agent_name: []const u8,
    agent_handle: []const u8,
    stack_name: []const u8,
};

const WarRoomMissionRow = struct {
    id: i32,
    title: []const u8,
    objective: []const u8,
    status: []const u8,
    priority: []const u8,
    execution_mode: []const u8,
    mission_operational_closure_status: []const u8,
    next_step_detected_action: []const u8,
    next_step_detected_code: []const u8,
    next_step_detected_route: []const u8,
    pilot_dispatch_status: []const u8,
    pilot_operational_brief_status: []const u8,
    planner_dispatch_status: []const u8,
    planner_operational_plan_status: []const u8,
    scout_dispatch_status: []const u8,
    scout_report_status: []const u8,
    builder_dispatch_status: []const u8,
    builder_implementation_report_status: []const u8,
    reviewer_dispatch_status: []const u8,
    reviewer_review_report_status: []const u8,
    executor_dispatch_status: []const u8,
    executor_verification_report_status: []const u8,
    pilot_delivery_dispatch_status: []const u8,
    pilot_delivery_report_status: []const u8,
};

const WarRoomEventRow = struct {
    id: i32,
    event_type: []const u8,
    title: []const u8,
    message: []const u8,
    created_at_label: []const u8,
};

pub fn show(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const workspace_rows = try db.query(
        WarRoomWorkspaceRow,
        c.arena,
        \\SELECT
        \\    w.id,
        \\    w.name,
        \\    w.local_path,
        \\    w.stack_name,
        \\    COALESCE(s.name, 'Sem squad vinculada') AS squad_name,
        \\    w.status
        \\FROM workspaces w
        \\LEFT JOIN squads s ON s.id = w.default_squad_id
        \\WHERE w.id = $1
        \\LIMIT 1
    ,
        .{workspace_id},
    );

    if (workspace_rows.len == 0) {
        return c.text("Workspace não encontrado.", .{ .status = .not_found });
    }

    const runtime_rows = try db.query(
        WarRoomRuntimeRow,
        c.arena,
        \\SELECT
        \\    state,
        \\    container_name,
        \\    CASE WHEN opencode_port = 0 THEN 'Não alocado' ELSE opencode_port::TEXT END AS opencode_port_label,
        \\    CASE WHEN server_url = '' THEN 'Servidor não iniciado' ELSE server_url END AS server_url_label,
        \\    status_message,
        \\    state <> 'missing' AS is_prepared
        \\FROM workspace_runtimes
        \\WHERE workspace_id = $1
        \\LIMIT 1
    ,
        .{workspace_id},
    );

    const panes = try db.query(
        WarRoomPaneRow,
        c.arena,
        \\SELECT
        \\    wp.id,
        \\    wp.role_name,
        \\    wp.pane_state,
        \\    wp.session_external_id,
        \\    wp.context_state,
        \\    wp.stale_reason,
        \\    a.name AS agent_name,
        \\    a.handle AS agent_handle,
        \\    s.name AS stack_name
        \\FROM workspace_panes wp
        \\INNER JOIN agents a ON a.id = wp.agent_id
        \\INNER JOIN stacks s ON s.id = a.default_stack_id
        \\WHERE wp.workspace_id = $1
        \\ORDER BY wp.display_order ASC
    ,
        .{workspace_id},
    );

    const active_missions = try db.query(
        WarRoomMissionRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.title,
        \\    m.objective,
        \\    m.status,
        \\    m.priority,
        \\    m.execution_mode,
        \\    m.mission_operational_closure_status,
        \\    m.next_step_detected_action,
        \\    m.next_step_detected_code,
        \\    m.next_step_detected_route,
        \\    m.pilot_dispatch_status,
        \\    m.pilot_operational_brief_status,
        \\    m.planner_dispatch_status,
        \\    m.planner_operational_plan_status,
        \\    m.scout_dispatch_status,
        \\    m.scout_report_status,
        \\    m.builder_dispatch_status,
        \\    m.builder_implementation_report_status,
        \\    m.reviewer_dispatch_status,
        \\    m.reviewer_review_report_status,
        \\    m.executor_dispatch_status,
        \\    m.executor_verification_report_status,
        \\    m.pilot_delivery_dispatch_status,
        \\    m.pilot_delivery_report_status
        \\FROM missions m
        \\INNER JOIN workspaces w ON w.active_mission_id = m.id
        \\WHERE w.id = $1
        \\LIMIT 1
    ,
        .{workspace_id},
    );

    const mission_events = try db.query(
        WarRoomEventRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    event_type,
        \\    title,
        \\    message,
        \\    TO_CHAR(created_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS') AS created_at_label
        \\FROM mission_events
        \\WHERE workspace_id = $1
        \\ORDER BY id DESC
        \\LIMIT 12
    ,
        .{workspace_id},
    );

    return c.view("workspaces/war_room", .{
        .title = try std.fmt.allocPrint(c.arena, "War Room · {s}", .{workspace_rows[0].name}),
        .workspace = workspace_rows[0],
        .runtime_rows = runtime_rows,
        .runtime_count = runtime_rows.len,
        .panes = panes,
        .pane_count = panes.len,
        .active_missions = active_missions,
        .active_mission_count = active_missions.len,
        .mission_events = mission_events,
        .mission_event_count = mission_events.len,
    }, .{});
}

pub fn live(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.json(.{
            .ok = false,
            .message = "Workspace não informado.",
        }, .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.json(.{
            .ok = false,
            .message = "Workspace inválido.",
        }, .{ .status = .bad_request });

    const workspace_rows = try db.query(
        WarRoomWorkspaceRow,
        c.arena,
        \\SELECT
        \\    w.id,
        \\    w.name,
        \\    w.local_path,
        \\    w.stack_name,
        \\    COALESCE(s.name, 'Sem squad vinculada') AS squad_name,
        \\    w.status
        \\FROM workspaces w
        \\LEFT JOIN squads s ON s.id = w.default_squad_id
        \\WHERE w.id = $1
        \\LIMIT 1
    ,
        .{workspace_id},
    );

    if (workspace_rows.len == 0) {
        return c.json(.{
            .ok = false,
            .message = "Workspace não encontrado.",
        }, .{ .status = .not_found });
    }

    const runtime_rows = try db.query(
        WarRoomRuntimeRow,
        c.arena,
        \\SELECT
        \\    state,
        \\    container_name,
        \\    CASE WHEN opencode_port = 0 THEN 'Não alocado' ELSE opencode_port::TEXT END AS opencode_port_label,
        \\    CASE WHEN server_url = '' THEN 'Servidor não iniciado' ELSE server_url END AS server_url_label,
        \\    status_message,
        \\    state <> 'missing' AS is_prepared
        \\FROM workspace_runtimes
        \\WHERE workspace_id = $1
        \\LIMIT 1
    ,
        .{workspace_id},
    );

    const panes = try db.query(
        WarRoomPaneRow,
        c.arena,
        \\SELECT
        \\    wp.id,
        \\    wp.role_name,
        \\    wp.pane_state,
        \\    wp.session_external_id,
        \\    wp.context_state,
        \\    wp.stale_reason,
        \\    a.name AS agent_name,
        \\    a.handle AS agent_handle,
        \\    s.name AS stack_name
        \\FROM workspace_panes wp
        \\INNER JOIN agents a ON a.id = wp.agent_id
        \\INNER JOIN stacks s ON s.id = a.default_stack_id
        \\WHERE wp.workspace_id = $1
        \\ORDER BY wp.display_order ASC
    ,
        .{workspace_id},
    );

    const active_missions = try db.query(
        WarRoomMissionRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.title,
        \\    m.objective,
        \\    m.status,
        \\    m.priority,
        \\    m.execution_mode,
        \\    m.mission_operational_closure_status,
        \\    m.next_step_detected_action,
        \\    m.next_step_detected_code,
        \\    m.next_step_detected_route,
        \\    m.pilot_dispatch_status,
        \\    m.pilot_operational_brief_status,
        \\    m.planner_dispatch_status,
        \\    m.planner_operational_plan_status,
        \\    m.scout_dispatch_status,
        \\    m.scout_report_status,
        \\    m.builder_dispatch_status,
        \\    m.builder_implementation_report_status,
        \\    m.reviewer_dispatch_status,
        \\    m.reviewer_review_report_status,
        \\    m.executor_dispatch_status,
        \\    m.executor_verification_report_status,
        \\    m.pilot_delivery_dispatch_status,
        \\    m.pilot_delivery_report_status
        \\FROM missions m
        \\INNER JOIN workspaces w ON w.active_mission_id = m.id
        \\WHERE w.id = $1
        \\LIMIT 1
    ,
        .{workspace_id},
    );

    const mission_events = try db.query(
        WarRoomEventRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    event_type,
        \\    title,
        \\    message,
        \\    TO_CHAR(created_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS') AS created_at_label
        \\FROM mission_events
        \\WHERE workspace_id = $1
        \\ORDER BY id DESC
        \\LIMIT 12
    ,
        .{workspace_id},
    );

    const runtime_events = try db.query(
        WarRoomEventRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    event_type,
        \\    title,
        \\    message,
        \\    TO_CHAR(created_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS') AS created_at_label
        \\FROM workspace_runtime_events
        \\WHERE workspace_id = $1
        \\ORDER BY id DESC
        \\LIMIT 8
    ,
        .{workspace_id},
    );

    return c.json(.{
        .ok = true,
        .workspace = workspace_rows[0],
        .runtime = if (runtime_rows.len > 0) runtime_rows[0] else null,
        .runtime_is_running = runtime_rows.len > 0 and std.mem.eql(u8, runtime_rows[0].state, "running"),
        .panes = panes,
        .pane_count = panes.len,
        .active_mission = if (active_missions.len > 0) active_missions[0] else null,
        .has_active_mission = active_missions.len > 0,
        .mission_events = mission_events,
        .mission_event_count = mission_events.len,
        .runtime_events = runtime_events,
        .runtime_event_count = runtime_events.len,
    }, .{});
}
