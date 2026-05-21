const std = @import("std");

pub const OpenCodeTextPart = struct {
    type: []const u8,
    text: []const u8,
};

pub const OpenCodePromptModel = struct {
    providerID: []const u8,
    modelID: []const u8,
};

pub const OpenCodeBootstrapMessageRequest = struct {
    noReply: bool,
    parts: []const OpenCodeTextPart,
};

pub const open_code_prompt_model = OpenCodePromptModel{
    .providerID = "github-copilot",
    .modelID = "gpt-5.4-mini",
};

pub const MissionRow = struct {
    id: i32,
    workspace_id: i32,
    workspace_name: []const u8,
    squad_id: i32,
    squad_name: []const u8,
    title: []const u8,
    objective: []const u8,
    status: []const u8,
    priority: []const u8,
    execution_mode: []const u8,
    pilot_operational_brief: []const u8,
    pilot_operational_brief_status: []const u8,
    pilot_operational_brief_captured_at_label: []const u8,
    planner_dispatch_status: []const u8,
    planner_session_external_id: []const u8,
    dispatched_to_planner_at_label: []const u8,
    planner_operational_plan: []const u8,
    planner_operational_plan_status: []const u8,
    planner_operational_plan_captured_at_label: []const u8,
    scout_dispatch_status: []const u8,
    scout_session_external_id: []const u8,
    dispatched_to_scout_at_label: []const u8,
    scout_report: []const u8,
    scout_report_status: []const u8,
    scout_report_captured_at_label: []const u8,
    builder_dispatch_status: []const u8,
    builder_session_external_id: []const u8,
    dispatched_to_builder_at_label: []const u8,
    builder_implementation_report: []const u8,
    builder_implementation_report_status: []const u8,
    builder_implementation_report_captured_at_label: []const u8,
    reviewer_dispatch_status: []const u8,
    reviewer_session_external_id: []const u8,
    dispatched_to_reviewer_at_label: []const u8,
    reviewer_review_report: []const u8,
    reviewer_review_report_status: []const u8,
    reviewer_review_report_captured_at_label: []const u8,
    executor_dispatch_status: []const u8,
    executor_session_external_id: []const u8,
    dispatched_to_executor_at_label: []const u8,
    executor_verification_report: []const u8,
    executor_verification_report_status: []const u8,
    executor_verification_report_captured_at_label: []const u8,
    pilot_delivery_dispatch_status: []const u8,
    pilot_delivery_session_external_id: []const u8,
    dispatched_to_pilot_delivery_at_label: []const u8,
    pilot_delivery_report: []const u8,
    pilot_delivery_report_status: []const u8,
    pilot_delivery_report_captured_at_label: []const u8,
    mission_final_verdict: []const u8,
    mission_operational_closure_status: []const u8,
    mission_operational_closed_at_label: []const u8,
    next_step_detected_action: []const u8,
    next_step_detected_code: []const u8,
    next_step_detected_route: []const u8,
    next_step_detected_at_label: []const u8,
};

pub const WorkspaceMissionPreviewRow = struct {
    id: i32,
    workspace_id: i32,
    workspace_name: []const u8,
    squad_id: i32,
    squad_name: []const u8,
    title: []const u8,
    objective: []const u8,
    status: []const u8,
    priority: []const u8,
    execution_mode: []const u8,
    mission_operational_closure_status: []const u8,
    is_active_in_cockpit: bool,
    mission_final_verdict: []const u8,
    mission_operational_closed_at_label: []const u8,
};

pub const ActiveMissionPanelRow = struct {
    id: i32,
    workspace_id: i32,
    workspace_name: []const u8,
    squad_id: i32,
    squad_name: []const u8,
    title: []const u8,
    objective: []const u8,
    status: []const u8,
    priority: []const u8,
    execution_mode: []const u8,
    execution_controls_enabled: bool,
    pilot_dispatch_status: []const u8,
    pilot_session_external_id: []const u8,
    dispatched_to_pilot_at_label: []const u8,
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
    next_step_detected_action: []const u8,
    next_step_detected_code: []const u8,
    next_step_detected_route: []const u8,
    next_step_detected_at_label: []const u8,
};

pub const WorkspaceMissionPaneDispatchRow = struct {
    id: i32,
    role_name: []const u8,
    pane_state: []const u8,
    session_external_id: []const u8,
    context_state: []const u8,
};

pub const OpenCodePromptAsyncRequest = struct {
    model: OpenCodePromptModel,
    parts: []const OpenCodeTextPart,
};

pub const MissionForm = struct {
    workspace_id: []const u8,
    context_workspace_id: []const u8,
    title: []const u8,
    objective: []const u8,
    status: []const u8,
    priority: []const u8,
};

pub const MissionUpdateForm = struct {
    title: []const u8,
    objective: []const u8,
    status: []const u8,
    priority: []const u8,
    execution_mode: []const u8,
};

pub const MissionIdRow = struct {
    id: i32,
};

pub const MissionActivationTargetRow = struct {
    id: i32,
    mission_operational_closure_status: []const u8,
};

pub const MissionPilotDispatchTraceRow = struct {
    pilot_dispatch_user_message_id: []const u8,
};

pub const MissionPlannerDispatchTraceRow = struct {
    planner_dispatch_user_message_id: []const u8,
};

pub const MissionReviewerDispatchTraceRow = struct {
    reviewer_dispatch_user_message_id: []const u8,
};

pub const MissionScoutDispatchTraceRow = struct {
    scout_dispatch_user_message_id: []const u8,
};

pub const MissionBuilderDispatchTraceRow = struct {
    builder_dispatch_user_message_id: []const u8,
};

pub const MissionExecutorDispatchTraceRow = struct {
    executor_dispatch_user_message_id: []const u8,
};

pub const MissionPilotDeliveryDispatchTraceRow = struct {
    pilot_delivery_dispatch_user_message_id: []const u8,
};

pub const MissionNextStepRow = struct {
    id: i32,
    workspace_id: i32,
    title: []const u8,
    execution_mode: []const u8,
    mission_operational_closure_status: []const u8,
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

pub const MissionClosureFinalizeRow = struct {
    id: i32,
    workspace_id: i32,
    title: []const u8,
    pilot_delivery_report: []const u8,
    pilot_delivery_report_status: []const u8,
    mission_final_verdict: []const u8,
    mission_operational_closure_status: []const u8,
};

pub const MissionEventRow = struct {
    id: i32,
    event_type: []const u8,
    title: []const u8,
    message: []const u8,
    created_at_label: []const u8,
};

pub const MissionWorkspaceOptionRow = struct {
    id: i32,
    id_label: []const u8,
    name: []const u8,
    local_path: []const u8,
    default_squad_id: i32,
    squad_name: []const u8,
};

pub fn isSupervisedExecutionEventType(event_type: []const u8) bool {
    return std.mem.eql(u8, event_type, "mission-next-step-detected") or
        std.mem.eql(u8, event_type, "mission-operationally-closed") or
        std.mem.indexOf(u8, event_type, "dispatch") != null or
        std.mem.indexOf(u8, event_type, "captured") != null;
}

pub fn collectSupervisedExecutionEvents(
    allocator: std.mem.Allocator,
    events: []const MissionEventRow,
) ![]MissionEventRow {
    var supervised_count: usize = 0;

    for (events) |event| {
        if (isSupervisedExecutionEventType(event.event_type)) {
            supervised_count += 1;
        }
    }

    const supervised_events = try allocator.alloc(MissionEventRow, supervised_count);

    var supervised_index: usize = 0;
    for (events) |event| {
        if (isSupervisedExecutionEventType(event.event_type)) {
            supervised_events[supervised_index] = event;
            supervised_index += 1;
        }
    }

    return supervised_events;
}
