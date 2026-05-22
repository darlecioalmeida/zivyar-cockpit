const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const core = @import("core");
const helpers = @import("../../shared/helpers.zig");
const model = @import("./mission_model.zig");
const workspace_model = @import("../workspaces/workspace_model.zig");
const workspace_repo = @import("../workspaces/workspace_repository.zig");

const mission_select_fields =
    \\    m.id,
    \\    m.workspace_id,
    \\    w.name AS workspace_name,
    \\    m.squad_id,
    \\    COALESCE(s.name, 'Squad não localizada') AS squad_name,
    \\    m.title,
    \\    m.objective,
    \\    m.status,
    \\    m.priority,
    \\    m.execution_mode,
    \\    m.pilot_dispatch_status,
    \\    m.pilot_session_external_id,
    \\    COALESCE(
    \\        TO_CHAR(m.dispatched_to_pilot_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS'),
    \\        'Ainda não enviado'
    \\    ) AS dispatched_to_pilot_at_label,
    \\    m.pilot_operational_brief,
    \\    m.pilot_operational_brief_status,
    \\    COALESCE(
    \\        TO_CHAR(m.pilot_operational_brief_captured_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS'),
    \\        'Ainda não capturado'
    \\    ) AS pilot_operational_brief_captured_at_label,
    \\    m.planner_dispatch_status,
    \\    m.planner_session_external_id,
    \\    COALESCE(
    \\        TO_CHAR(m.dispatched_to_planner_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS'),
    \\        'Ainda não enviado'
    \\    ) AS dispatched_to_planner_at_label,
    \\    m.planner_operational_plan,
    \\    m.planner_operational_plan_status,
    \\    COALESCE(
    \\        TO_CHAR(m.planner_operational_plan_captured_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS'),
    \\        'Ainda não capturado'
    \\    ) AS planner_operational_plan_captured_at_label,
    \\    m.scout_dispatch_status,
    \\    m.scout_session_external_id,
    \\    COALESCE(
    \\        TO_CHAR(m.dispatched_to_scout_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS'),
    \\        'Ainda não enviado'
    \\    ) AS dispatched_to_scout_at_label,
    \\    m.scout_report,
    \\    m.scout_report_status,
    \\    COALESCE(
    \\        TO_CHAR(m.scout_report_captured_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS'),
    \\        'Ainda não capturado'
    \\    ) AS scout_report_captured_at_label,
    \\    m.builder_dispatch_status,
    \\    m.builder_session_external_id,
    \\    COALESCE(
    \\        TO_CHAR(m.dispatched_to_builder_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS'),
    \\        'Ainda não enviado'
    \\    ) AS dispatched_to_builder_at_label,
    \\    m.builder_implementation_report,
    \\    m.builder_implementation_report_status,
    \\    COALESCE(
    \\        TO_CHAR(m.builder_implementation_report_captured_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS'),
    \\        'Ainda não capturado'
    \\    ) AS builder_implementation_report_captured_at_label,
    \\    m.reviewer_dispatch_status,
    \\    m.reviewer_session_external_id,
    \\    COALESCE(
    \\        TO_CHAR(m.dispatched_to_reviewer_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS'),
    \\        'Ainda não enviado'
    \\    ) AS dispatched_to_reviewer_at_label,
    \\    m.reviewer_review_report,
    \\    m.reviewer_review_report_status,
    \\    COALESCE(
    \\        TO_CHAR(m.reviewer_review_report_captured_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS'),
    \\        'Ainda não capturado'
    \\    ) AS reviewer_review_report_captured_at_label,
    \\    m.executor_dispatch_status,
    \\    m.executor_session_external_id,
    \\    COALESCE(
    \\        TO_CHAR(m.dispatched_to_executor_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS'),
    \\        'Ainda não enviado'
    \\    ) AS dispatched_to_executor_at_label,
    \\    m.executor_verification_report,
    \\    m.executor_verification_report_status,
    \\    COALESCE(
    \\        TO_CHAR(m.executor_verification_report_captured_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS'),
    \\        'Ainda não capturado'
    \\    ) AS executor_verification_report_captured_at_label,
    \\    m.pilot_delivery_dispatch_status,
    \\    m.pilot_delivery_session_external_id,
    \\    COALESCE(
    \\        TO_CHAR(m.dispatched_to_pilot_delivery_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS'),
    \\        'Ainda não enviado'
    \\    ) AS dispatched_to_pilot_delivery_at_label,
    \\    m.pilot_delivery_report,
    \\    m.pilot_delivery_report_status,
    \\    COALESCE(
    \\        TO_CHAR(m.pilot_delivery_report_captured_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS'),
    \\        'Ainda não capturado'
    \\    ) AS pilot_delivery_report_captured_at_label,
    \\    m.mission_final_verdict,
    \\    m.mission_operational_closure_status,
    \\    COALESCE(
    \\        TO_CHAR(m.mission_operational_closed_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS'),
    \\        'Ainda não encerrada'
    \\    ) AS mission_operational_closed_at_label,
    \\    m.next_step_detected_action,
    \\    m.next_step_detected_code,
    \\    m.next_step_detected_route,
    \\    COALESCE(
    \\        TO_CHAR(m.next_step_detected_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS'),
    \\        'Ainda não detectada'
    \\    ) AS next_step_detected_at_label
;

const mission_from_join =
    \\FROM missions m
    \\INNER JOIN workspaces w ON w.id = m.workspace_id
    \\LEFT JOIN squads s ON s.id = m.squad_id
;

const mission_from_active_join =
    \\FROM workspaces w
    \\INNER JOIN missions m ON m.id = w.active_mission_id
    \\LEFT JOIN squads s ON s.id = m.squad_id
;

pub fn getMissionById(c: *spider.Ctx, mission_id: i32) ![]model.MissionRow {
    const sql = try std.fmt.allocPrint(c.arena, "SELECT {s} {s} WHERE m.id = $1 LIMIT 1", .{ mission_select_fields, mission_from_join });
    return db.query(model.MissionRow, c.arena, sql, .{mission_id});
}

pub fn getActiveMissionForWorkspace(c: *spider.Ctx, workspace_id: i32, mission_id: i32) ![]model.MissionRow {
    const sql = try std.fmt.allocPrint(c.arena, "SELECT {s} {s} WHERE w.id = $1 AND m.id = $2 LIMIT 1", .{ mission_select_fields, mission_from_active_join });
    return db.query(model.MissionRow, c.arena, sql, .{ workspace_id, mission_id });
}

pub fn getMissionActivationTarget(c: *spider.Ctx, mission_id: i32, workspace_id: i32) ![]model.MissionActivationTargetRow {
    return db.query(
        model.MissionActivationTargetRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    mission_operational_closure_status
        \\FROM missions
        \\WHERE id = $1
        \\AND workspace_id = $2
        \\LIMIT 1
    ,
        .{ mission_id, workspace_id },
    );
}

pub fn listMissions(c: *spider.Ctx) ![]model.MissionRow {
    const sql = try std.fmt.allocPrint(c.arena, "SELECT {s} {s} ORDER BY m.id DESC", .{ mission_select_fields, mission_from_join });
    return db.query(model.MissionRow, c.arena, sql, .{});
}

pub fn listMissionWorkspaces(c: *spider.Ctx) ![]model.MissionWorkspaceOptionRow {
    return db.query(
        model.MissionWorkspaceOptionRow,
        c.arena,
        \\SELECT
        \\    w.id,
        \\    w.id::TEXT AS id_label,
        \\    w.name,
        \\    w.local_path,
        \\    w.default_squad_id,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name
        \\FROM workspaces w
        \\INNER JOIN squads s ON s.id = w.default_squad_id
        \\WHERE w.default_squad_id IS NOT NULL
        \\ORDER BY w.name ASC
    ,
        .{},
    );
}

pub fn listMissionEvents(c: *spider.Ctx, mission_id: i32) ![]model.MissionEventRow {
    return db.query(
        model.MissionEventRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    event_type,
        \\    title,
        \\    message,
        \\    TO_CHAR(created_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS') AS created_at_label
        \\FROM mission_events
        \\WHERE mission_id = $1
        \\ORDER BY id DESC
    ,
        .{mission_id},
    );
}

pub fn insertMissionEvent(c: *spider.Ctx, mission_id: i32, workspace_id: i32, event_type: []const u8, title: []const u8, message: []const u8) !void {
    try db.query(
        void,
        c.arena,
        \\INSERT INTO mission_events (
        \\    mission_id,
        \\    workspace_id,
        \\    event_type,
        \\    title,
        \\    message
        \\)
        \\VALUES (
        \\    $1,
        \\    $2,
        \\    $3,
        \\    $4,
        \\    $5
        \\)
    ,
        .{ mission_id, workspace_id, event_type, title, message },
    );
}

pub fn getActiveMissionForActivation(c: *spider.Ctx, workspace_id: i32) ![]model.MissionActivationTargetRow {
    return db.query(
        model.MissionActivationTargetRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.mission_operational_closure_status
        \\FROM workspaces w
        \\INNER JOIN missions m ON m.id = w.active_mission_id
        \\WHERE w.id = $1
        \\LIMIT 1
    ,
        .{workspace_id},
    );
}

pub fn createMission(c: *spider.Ctx, workspace_id: i32, squad_id: i32, title: []const u8, objective: []const u8, priority: []const u8) ![]model.MissionIdRow {
    return db.query(
        model.MissionIdRow,
        c.arena,
        \\INSERT INTO missions (
        \\    workspace_id,
        \\    squad_id,
        \\    title,
        \\    objective,
        \\    status,
        \\    priority
        \\)
        \\VALUES ($1, $2, $3, $4, $5, $6)
        \\RETURNING id
    ,
        .{
            workspace_id,
            squad_id,
            title,
            objective,
            "briefing",
            priority,
        },
    );
}

pub fn activateMissionForWorkspace(c: *spider.Ctx, mission_id: i32, workspace_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE workspaces
        \\SET active_mission_id = $1
        \\WHERE id = $2
    ,
        .{ mission_id, workspace_id },
    );
}

pub fn getSelectedWorkspaceForMission(c: *spider.Ctx, workspace_id: i32) ![]model.MissionWorkspaceOptionRow {
    return db.query(
        model.MissionWorkspaceOptionRow,
        c.arena,
        \\SELECT
        \\    w.id,
        \\    w.id::TEXT AS id_label,
        \\    w.name,
        \\    w.local_path,
        \\    w.default_squad_id,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name
        \\FROM workspaces w
        \\INNER JOIN squads s ON s.id = w.default_squad_id
        \\WHERE w.id = $1
        \\AND w.default_squad_id IS NOT NULL
        \\LIMIT 1
    ,
        .{workspace_id},
    );
}

pub fn updateMission(c: *spider.Ctx, mission_id: i32, title: []const u8, objective: []const u8, status: []const u8, priority: []const u8, execution_mode: []const u8) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET title = $1,
        \\    objective = $2,
        \\    status = $3,
        \\    priority = $4,
        \\    execution_mode = $5
        \\WHERE id = $6
    ,
        .{
            title,
            objective,
            status,
            priority,
            execution_mode,
            mission_id,
        },
    );
}

pub fn deleteMission(c: *spider.Ctx, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\DELETE FROM missions
        \\WHERE id = $1
    ,
        .{mission_id},
    );
}

pub fn getClosureRow(c: *spider.Ctx, mission_id: i32) ![]model.MissionClosureFinalizeRow {
    return db.query(
        model.MissionClosureFinalizeRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    workspace_id,
        \\    title,
        \\    pilot_delivery_report,
        \\    pilot_delivery_report_status,
        \\    mission_final_verdict,
        \\    mission_operational_closure_status
        \\FROM missions
        \\WHERE id = $1
        \\LIMIT 1
    ,
        .{mission_id},
    );
}

pub fn getNextStepMission(c: *spider.Ctx, mission_id: i32) ![]model.MissionNextStepRow {
    return db.query(
        model.MissionNextStepRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    workspace_id,
        \\    title,
        \\    execution_mode,
        \\    mission_operational_closure_status,
        \\    pilot_dispatch_status,
        \\    pilot_operational_brief_status,
        \\    planner_dispatch_status,
        \\    planner_operational_plan_status,
        \\    scout_dispatch_status,
        \\    scout_report_status,
        \\    builder_dispatch_status,
        \\    builder_implementation_report_status,
        \\    reviewer_dispatch_status,
        \\    reviewer_review_report_status,
        \\    executor_dispatch_status,
        \\    executor_verification_report_status,
        \\    pilot_delivery_dispatch_status,
        \\    pilot_delivery_report_status
        \\FROM missions
        \\WHERE id = $1
        \\LIMIT 1
    ,
        .{mission_id},
    );
}

pub fn updateMissionNextStep(c: *spider.Ctx, mission_id: i32, action: []const u8, code: []const u8, route: []const u8) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET next_step_detected_action = $1,
        \\    next_step_detected_code = $2,
        \\    next_step_detected_route = $3,
        \\    next_step_detected_at = NOW()
        \\WHERE id = $4
    ,
        .{ action, code, route, mission_id },
    );
}

pub fn getPaneByRole(c: *spider.Ctx, workspace_id: i32, role_name: []const u8) ![]model.WorkspaceMissionPaneDispatchRow {
    return db.query(
        model.WorkspaceMissionPaneDispatchRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    role_name,
        \\    pane_state,
        \\    session_external_id,
        \\    context_state
        \\FROM workspace_panes
        \\WHERE workspace_id = $1
        \\AND role_name = $2
        \\LIMIT 1
    ,
        .{ workspace_id, role_name },
    );
}

pub fn updateMissionAfterPilotDispatch(c: *spider.Ctx, pilot_session_id: []const u8, dispatch_user_message_id: []const u8, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET pilot_dispatch_status = 'sent',
        \\    next_step_detected_action = '',
        \\    next_step_detected_code = '',
        \\    next_step_detected_route = '',
        \\    next_step_detected_at = NULL,
        \\    pilot_session_external_id = $1,
        \\    pilot_dispatch_user_message_id = $2,
        \\    dispatched_to_pilot_at = NOW(),
        \\    pilot_operational_brief = '',
        \\    pilot_operational_brief_status = 'pending_capture',
        \\    pilot_operational_brief_captured_at = NULL
        \\WHERE id = $3
    ,
        .{ pilot_session_id, dispatch_user_message_id, mission_id },
    );
}

pub fn setPilotDispatchError(c: *spider.Ctx, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET pilot_dispatch_status = 'error'
        \\WHERE id = $1
    ,
        .{mission_id},
    );
}

pub fn updateMissionAfterPlannerDispatch(c: *spider.Ctx, planner_session_id: []const u8, dispatch_user_message_id: []const u8, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET planner_dispatch_status = 'sent',
        \\    planner_session_external_id = $1,
        \\    planner_dispatch_user_message_id = $2,
        \\    dispatched_to_planner_at = NOW(),
        \\    planner_operational_plan = '',
        \\    planner_operational_plan_status = 'pending_capture',
        \\    planner_operational_plan_captured_at = NULL
        \\WHERE id = $3
    ,
        .{ planner_session_id, dispatch_user_message_id, mission_id },
    );
}

pub fn setPlannerDispatchError(c: *spider.Ctx, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET planner_dispatch_status = 'error'
        \\WHERE id = $1
    ,
        .{mission_id},
    );
}

pub fn updateMissionAfterScoutDispatch(c: *spider.Ctx, scout_session_id: []const u8, dispatch_user_message_id: []const u8, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET scout_dispatch_status = 'sent',
        \\    scout_session_external_id = $1,
        \\    scout_dispatch_user_message_id = $2,
        \\    dispatched_to_scout_at = NOW(),
        \\    scout_report = '',
        \\    scout_report_status = 'pending_capture',
        \\    scout_report_captured_at = NULL
        \\WHERE id = $3
    ,
        .{ scout_session_id, dispatch_user_message_id, mission_id },
    );
}

pub fn setScoutDispatchError(c: *spider.Ctx, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET scout_dispatch_status = 'error'
        \\WHERE id = $1
    ,
        .{mission_id},
    );
}

pub fn updateMissionAfterBuilderDispatch(c: *spider.Ctx, builder_session_id: []const u8, dispatch_user_message_id: []const u8, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET builder_dispatch_status = 'sent',
        \\    builder_session_external_id = $1,
        \\    builder_dispatch_user_message_id = $2,
        \\    dispatched_to_builder_at = NOW(),
        \\    builder_implementation_report = '',
        \\    builder_implementation_report_status = 'pending_capture',
        \\    builder_implementation_report_captured_at = NULL,
        \\    status = 'active'
        \\WHERE id = $3
    ,
        .{ builder_session_id, dispatch_user_message_id, mission_id },
    );
}

pub fn setBuilderDispatchError(c: *spider.Ctx, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET builder_dispatch_status = 'error'
        \\WHERE id = $1
    ,
        .{mission_id},
    );
}

pub fn updateMissionAfterReviewerDispatch(c: *spider.Ctx, reviewer_session_id: []const u8, dispatch_user_message_id: []const u8, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET reviewer_dispatch_status = 'sent',
        \\    reviewer_session_external_id = $1,
        \\    reviewer_dispatch_user_message_id = $2,
        \\    dispatched_to_reviewer_at = NOW(),
        \\    reviewer_review_report = '',
        \\    reviewer_review_report_status = 'pending_capture',
        \\    reviewer_review_report_captured_at = NULL,
        \\    status = 'review'
        \\WHERE id = $3
    ,
        .{ reviewer_session_id, dispatch_user_message_id, mission_id },
    );
}

pub fn setReviewerDispatchError(c: *spider.Ctx, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET reviewer_dispatch_status = 'error'
        \\WHERE id = $1
    ,
        .{mission_id},
    );
}

pub fn updateMissionAfterExecutorDispatch(c: *spider.Ctx, executor_session_id: []const u8, dispatch_user_message_id: []const u8, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET executor_dispatch_status = 'sent',
        \\    executor_session_external_id = $1,
        \\    executor_dispatch_user_message_id = $2,
        \\    dispatched_to_executor_at = NOW(),
        \\    executor_verification_report = '',
        \\    executor_verification_report_status = 'pending_capture',
        \\    executor_verification_report_captured_at = NULL
        \\WHERE id = $3
    ,
        .{ executor_session_id, dispatch_user_message_id, mission_id },
    );
}

pub fn setExecutorDispatchError(c: *spider.Ctx, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET executor_dispatch_status = 'error'
        \\WHERE id = $1
    ,
        .{mission_id},
    );
}

pub fn updateMissionAfterPilotDeliveryDispatch(c: *spider.Ctx, pilot_session_id: []const u8, dispatch_user_message_id: []const u8, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET pilot_delivery_dispatch_status = 'sent',
        \\    pilot_delivery_session_external_id = $1,
        \\    pilot_delivery_dispatch_user_message_id = $2,
        \\    dispatched_to_pilot_delivery_at = NOW(),
        \\    pilot_delivery_report = '',
        \\    pilot_delivery_report_status = 'pending_capture',
        \\    pilot_delivery_report_captured_at = NULL
        \\WHERE id = $3
    ,
        .{ pilot_session_id, dispatch_user_message_id, mission_id },
    );
}

pub fn setPilotDeliveryDispatchError(c: *spider.Ctx, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET pilot_delivery_dispatch_status = 'error'
        \\WHERE id = $1
    ,
        .{mission_id},
    );
}

pub fn updateMissionAfterPilotBriefCapture(c: *spider.Ctx, brief_text: []const u8, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET pilot_operational_brief = $1,
        \\    pilot_operational_brief_status = 'captured',
        \\    next_step_detected_action = '',
        \\    next_step_detected_code = '',
        \\    next_step_detected_route = '',
        \\    next_step_detected_at = NULL,
        \\    pilot_operational_brief_captured_at = NOW()
        \\WHERE id = $2
    ,
        .{ brief_text, mission_id },
    );
}

pub fn updateMissionAfterPlannerPlanCapture(c: *spider.Ctx, plan_text: []const u8, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET planner_operational_plan = $1,
        \\    planner_operational_plan_status = 'captured',
        \\    next_step_detected_action = '',
        \\    next_step_detected_code = '',
        \\    next_step_detected_route = '',
        \\    next_step_detected_at = NULL,
        \\    planner_operational_plan_captured_at = NOW(),
        \\    status = 'planned'
        \\WHERE id = $2
    ,
        .{ plan_text, mission_id },
    );
}

pub fn updateMissionAfterScoutReportCapture(c: *spider.Ctx, report_text: []const u8, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET scout_report = $1,
        \\    scout_report_status = 'captured',
        \\    next_step_detected_action = '',
        \\    next_step_detected_code = '',
        \\    next_step_detected_route = '',
        \\    next_step_detected_at = NULL,
        \\    scout_report_captured_at = NOW()
        \\WHERE id = $2
    ,
        .{ report_text, mission_id },
    );
}

pub fn updateMissionAfterBuilderReportCapture(c: *spider.Ctx, report_text: []const u8, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET builder_implementation_report = $1,
        \\    builder_implementation_report_status = 'captured',
        \\    next_step_detected_action = '',
        \\    next_step_detected_code = '',
        \\    next_step_detected_route = '',
        \\    next_step_detected_at = NULL,
        \\    builder_implementation_report_captured_at = NOW()
        \\WHERE id = $2
    ,
        .{ report_text, mission_id },
    );
}

pub fn updateMissionAfterReviewerReportCapture(c: *spider.Ctx, report_text: []const u8, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET reviewer_review_report = $1,
        \\    reviewer_review_report_status = 'captured',
        \\    next_step_detected_action = '',
        \\    next_step_detected_code = '',
        \\    next_step_detected_route = '',
        \\    next_step_detected_at = NULL,
        \\    reviewer_review_report_captured_at = NOW()
        \\WHERE id = $2
    ,
        .{ report_text, mission_id },
    );
}

pub fn updateMissionAfterExecutorReportCapture(c: *spider.Ctx, report_text: []const u8, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET executor_verification_report = $1,
        \\    executor_verification_report_status = 'captured',
        \\    next_step_detected_action = '',
        \\    next_step_detected_code = '',
        \\    next_step_detected_route = '',
        \\    next_step_detected_at = NULL,
        \\    executor_verification_report_captured_at = NOW()
        \\WHERE id = $2
    ,
        .{ report_text, mission_id },
    );
}

pub fn updateMissionAfterPilotDeliveryReportCapture(c: *spider.Ctx, report_text: []const u8, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET pilot_delivery_report = $1,
        \\    pilot_delivery_report_status = 'captured',
        \\    next_step_detected_action = '',
        \\    next_step_detected_code = '',
        \\    next_step_detected_route = '',
        \\    next_step_detected_at = NULL,
        \\    pilot_delivery_report_captured_at = NOW()
        \\WHERE id = $2
    ,
        .{ report_text, mission_id },
    );
}

pub fn finalizeMission(c: *spider.Ctx, final_verdict: []const u8, formal_status: []const u8, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET mission_final_verdict = $1,
        \\    mission_operational_closure_status = 'closed',
        \\    next_step_detected_action = '',
        \\    next_step_detected_code = '',
        \\    next_step_detected_route = '',
        \\    next_step_detected_at = NULL,
        \\    mission_operational_closed_at = NOW(),
        \\    status = $2
        \\WHERE id = $3
    ,
        .{ final_verdict, formal_status, mission_id },
    );
}

pub fn releaseActiveMission(c: *spider.Ctx, workspace_id: i32, mission_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE workspaces
        \\SET active_mission_id = NULL
        \\WHERE id = $1
        \\AND active_mission_id = $2
    ,
        .{ workspace_id, mission_id },
    );
}

pub fn loadWorkspaceRuntime(c: *spider.Ctx, workspace_id: i32) ![]workspace_model.WorkspaceRuntimeRow {
    return workspace_repo.getRuntimeRow(c, workspace_id);
}

pub fn insertRuntimeCommandLog(c: *spider.Ctx, workspace_id: i32, action: []const u8, command_label: []const u8, result: core.RuntimeCommandResult) !void {
    return workspace_repo.insertRuntimeCommandLogEntry(c, workspace_id, action, command_label, result);
}

pub fn reconcileWorkspaceRuntimeState(c: *spider.Ctx, runtime: workspace_model.WorkspaceRuntimeRow) !void {
    if (!runtime.is_prepared) return;

    const inspect_result = core.runRuntimeCommand(c, &.{
        "docker", "inspect", "--format", "{{.State.Running}}", runtime.container_name,
    });

    if (!inspect_result.ok) {
        if (!std.mem.eql(u8, runtime.state, "missing")) {
            try workspace_repo.updateRuntimeState(c, runtime.workspace_id, "missing", "O container do runtime não foi encontrado no Docker.");
            try helpers.insertRuntimeEvent(c, runtime.workspace_id, "missing", "Container não encontrado", "O Zivyar detectou que o container registrado para este workspace não existe mais no Docker.");
            try workspace_repo.insertRuntimeCommandLogEntry(c, runtime.workspace_id, "inspect-container-state", "docker inspect --format {{.State.Running}} <workspace-container>", inspect_result);
        }
        return;
    }

    const inspected_value = std.mem.trim(u8, inspect_result.stdout, " \r\n\t");
    const docker_state = if (std.mem.eql(u8, inspected_value, "true")) "running" else "stopped";

    if (std.mem.eql(u8, runtime.state, docker_state)) return;

    if (std.mem.eql(u8, docker_state, "running")) {
        try workspace_repo.updateRuntimeState(c, runtime.workspace_id, "running", "Estado reconciliado: o container está em execução no Docker.");
        try helpers.insertRuntimeEvent(c, runtime.workspace_id, "reconciled-running", "Runtime reconciliado como ativo", "O Zivyar verificou o Docker e encontrou o container deste workspace em execução.");
    } else {
        try workspace_repo.updateRuntimeState(c, runtime.workspace_id, "stopped", "Estado reconciliado: o container está parado no Docker.");
        try helpers.insertRuntimeEvent(c, runtime.workspace_id, "reconciled-stopped", "Runtime reconciliado como parado", "O Zivyar verificou o Docker e encontrou o container deste workspace interrompido.");
    }

    try workspace_repo.insertRuntimeCommandLogEntry(c, runtime.workspace_id, "inspect-container-state", "docker inspect --format {{.State.Running}} <workspace-container>", inspect_result);
}

pub fn getPilotDispatchTrace(c: *spider.Ctx, mission_id: i32) ![]model.MissionPilotDispatchTraceRow {
    return db.query(
        model.MissionPilotDispatchTraceRow,
        c.arena,
        \\SELECT pilot_dispatch_user_message_id
        \\FROM missions
        \\WHERE id = $1
        \\LIMIT 1
    ,
        .{mission_id},
    );
}

pub fn getPlannerDispatchTrace(c: *spider.Ctx, mission_id: i32) ![]model.MissionPlannerDispatchTraceRow {
    return db.query(
        model.MissionPlannerDispatchTraceRow,
        c.arena,
        \\SELECT planner_dispatch_user_message_id
        \\FROM missions
        \\WHERE id = $1
        \\LIMIT 1
    ,
        .{mission_id},
    );
}

pub fn getScoutDispatchTrace(c: *spider.Ctx, mission_id: i32) ![]model.MissionScoutDispatchTraceRow {
    return db.query(
        model.MissionScoutDispatchTraceRow,
        c.arena,
        \\SELECT scout_dispatch_user_message_id
        \\FROM missions
        \\WHERE id = $1
        \\LIMIT 1
    ,
        .{mission_id},
    );
}

pub fn getBuilderDispatchTrace(c: *spider.Ctx, mission_id: i32) ![]model.MissionBuilderDispatchTraceRow {
    return db.query(
        model.MissionBuilderDispatchTraceRow,
        c.arena,
        \\SELECT builder_dispatch_user_message_id
        \\FROM missions
        \\WHERE id = $1
        \\LIMIT 1
    ,
        .{mission_id},
    );
}

pub fn getReviewerDispatchTrace(c: *spider.Ctx, mission_id: i32) ![]model.MissionReviewerDispatchTraceRow {
    return db.query(
        model.MissionReviewerDispatchTraceRow,
        c.arena,
        \\SELECT reviewer_dispatch_user_message_id
        \\FROM missions
        \\WHERE id = $1
        \\LIMIT 1
    ,
        .{mission_id},
    );
}

pub fn getExecutorDispatchTrace(c: *spider.Ctx, mission_id: i32) ![]model.MissionExecutorDispatchTraceRow {
    return db.query(
        model.MissionExecutorDispatchTraceRow,
        c.arena,
        \\SELECT executor_dispatch_user_message_id
        \\FROM missions
        \\WHERE id = $1
        \\LIMIT 1
    ,
        .{mission_id},
    );
}

pub fn getPilotDeliveryDispatchTrace(c: *spider.Ctx, mission_id: i32) ![]model.MissionPilotDeliveryDispatchTraceRow {
    return db.query(
        model.MissionPilotDeliveryDispatchTraceRow,
        c.arena,
        \\SELECT pilot_delivery_dispatch_user_message_id
        \\FROM missions
        \\WHERE id = $1
        \\LIMIT 1
    ,
        .{mission_id},
    );
}
