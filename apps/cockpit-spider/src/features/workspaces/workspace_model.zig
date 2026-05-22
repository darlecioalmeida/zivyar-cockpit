pub const WorkspaceRow = struct {
    id: i32,
    name: []const u8,
    local_path: []const u8,
    stack_name: []const u8,
    default_squad_id: ?i32,
    squad_name: []const u8,
    status: []const u8,
};

pub const WorkspaceIndexRow = struct {
    id: i32,
    name: []const u8,
    local_path: []const u8,
    stack_name: []const u8,
    default_squad_id: ?i32,
    squad_name: []const u8,
    status: []const u8,
    runtime_state: []const u8,
    runtime_container_name: []const u8,
    runtime_port_label: []const u8,
    runtime_server_url_label: []const u8,
    runtime_is_prepared: bool,
    runtime_is_running: bool,
};

pub const WorkspaceForm = struct {
    name: []const u8,
    local_path: []const u8,
    stack_name: []const u8,
    default_squad_id: []const u8,
};

pub const WorkspaceLocalPathConfirmForm = struct {
    name: []const u8,
    local_path: []const u8,
    stack_name: []const u8,
    default_squad_id: []const u8,
    confirm_local_path_change: []const u8,
};

pub const WorkspaceIdRow = struct {
    id: i32,
};

pub const WorkspaceSquadOptionRow = struct {
    id: i32,
    name: []const u8,
    slug: []const u8,
};

pub const WorkspacePaneRow = struct {
    id: i32,
    workspace_id: i32,
    role_name: []const u8,
    squad_member_id: ?i32,
    agent_id: i32,
    pane_state: []const u8,
    session_external_id: []const u8,
    session_agent_id: ?i32,
    session_agent_handle: []const u8,
    context_state: []const u8,
    stale_reason: []const u8,
    display_order: i32,
    agent_name: []const u8,
    agent_handle: []const u8,
    agent_role: []const u8,
    stack_name: []const u8,
};

pub const WorkspacePaneControlRow = struct {
    id: i32,
    workspace_id: i32,
    role_name: []const u8,
    agent_id: i32,
    pane_state: []const u8,
    session_external_id: []const u8,
    session_agent_id: ?i32,
    session_agent_handle: []const u8,
    context_state: []const u8,
    stale_reason: []const u8,
};

pub const WorkspacePaneBootstrapRow = struct {
    pane_id: i32,
    workspace_id: i32,
    role_name: []const u8,
    workspace_name: []const u8,
    local_path: []const u8,
    agent_name: []const u8,
    agent_handle: []const u8,
    agent_role: []const u8,
    agent_summary: []const u8,
    system_prompt: []const u8,
    operating_rules: []const u8,
    stack_name: []const u8,
    runtime_tool: []const u8,
    model_name: []const u8,
    model_id: []const u8,
    provider_type: []const u8,
};

pub const WorkspacePaneSessionHistoryRow = struct {
    id: i32,
    role_name: []const u8,
    previous_session_external_id: []const u8,
    replacement_session_external_id: []const u8,
    replacement_reason: []const u8,
    previous_session_agent_handle: []const u8,
    replacement_session_agent_handle: []const u8,
    created_at_label: []const u8,
};

pub const WorkspaceRuntimeRow = struct {
    workspace_id: i32,
    state: []const u8,
    container_name: []const u8,
    opencode_port_label: []const u8,
    server_url_label: []const u8,
    status_message: []const u8,
    is_prepared: bool,
};

pub const WorkspaceRuntimeCountRow = struct {
    total: i64,
};

pub const WorkspaceRuntimeControlRow = struct {
    workspace_id: i32,
    local_path: []const u8,
    container_name: []const u8,
    state: []const u8,
};

pub const WorkspaceRuntimeEventRow = struct {
    id: i32,
    event_type: []const u8,
    title: []const u8,
    message: []const u8,
};

pub const WorkspaceRuntimeLogRow = struct {
    id: i32,
    action: []const u8,
    command_label: []const u8,
    exit_code: i32,
    succeeded: bool,
    stdout_excerpt: []const u8,
    stderr_excerpt: []const u8,
};

pub const WorkspaceMemoryEntryRow = struct {
    id: i32,
    title: []const u8,
    content: []const u8,
    created_at_label: []const u8,
};

pub const WorkspaceMemoryForm = struct {
    title: []const u8,
    content: []const u8,
};

pub const WorkspaceHandoffRow = struct {
    id: i32,
    from_role: []const u8,
    to_role: []const u8,
    summary: []const u8,
    context: []const u8,
    created_at_label: []const u8,
};

pub const WorkspaceHandoffForm = struct {
    from_role: []const u8,
    to_role: []const u8,
    summary: []const u8,
    context: []const u8,
};

pub const WorkspaceDecisionRecordRow = struct {
    id: i32,
    title: []const u8,
    decision: []const u8,
    rationale: []const u8,
    created_at_label: []const u8,
};

pub const WorkspaceDecisionRecordForm = struct {
    title: []const u8,
    decision: []const u8,
    rationale: []const u8,
};

pub const WorkspaceSnapshotRow = struct {
    id: i32,
    title: []const u8,
    scope: []const u8,
    content: []const u8,
    created_at_label: []const u8,
};

pub const WorkspaceSnapshotForm = struct {
    title: []const u8,
    scope: []const u8,
    content: []const u8,
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

pub const WorkspaceMissionPaneDispatchRow = struct {
    id: i32,
    role_name: []const u8,
    pane_state: []const u8,
    session_external_id: []const u8,
    context_state: []const u8,
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

pub const MissionActivationTargetRow = struct {
    id: i32,
    mission_operational_closure_status: []const u8,
};

pub const SquadMemberRow = struct {
    id: i32,
    squad_id: i32,
    role_name: []const u8,
    agent_id: i32,
    display_order: i32,
    agent_name: []const u8,
    agent_handle: []const u8,
    agent_role: []const u8,
    stack_name: []const u8,
};
