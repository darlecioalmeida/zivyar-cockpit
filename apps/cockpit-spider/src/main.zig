const std = @import("std");
const spider = @import("spider");
const db = spider.pg;

pub const spider_templates = @import("embedded_templates.zig").EmbeddedTemplates;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;

    try db.init(arena, io, .{
        .host = spider.env.getOr("PG_HOST", "127.0.0.1"),
        .port = spider.env.getInt(u16, "PG_PORT", 55432),
        .user = spider.env.getOr("PG_USER", "zivyar"),
        .password = spider.env.getOr("PG_PASSWORD", "zivyar_dev_password"),
        .database = spider.env.getOr("PG_DB", "zivyar_cockpit"),
    });
    defer db.deinit();

    var server = spider.server();
    defer server.deinit();

    server
        .get("/", dashboard)
        .get("/workspaces", workspaces)
        .get("/workspaces/new", workspaceNew)
        .post("/workspaces", workspaceCreate)
        .get("/workspaces/:id/edit", workspaceEdit)
        .post("/workspaces/:id/update", workspaceUpdate)
        .post("/workspaces/:id/local-path/confirm", workspaceConfirmLocalPathChange)
        .post("/workspaces/:id/delete", workspaceDelete)
        .post("/workspaces/:id/runtime/prepare", workspaceRuntimePrepare)
        .post("/workspaces/:id/runtime/start", workspaceRuntimeStart)
        .post("/workspaces/:id/runtime/stop", workspaceRuntimeStop)
        .get("/workspaces/:id/runtime/live", workspaceRuntimeLiveStatus)
        .post("/workspaces/:id/panes/:pane_id/session/open", workspacePaneOpenSession)
        .post("/workspaces/:id/panes/:pane_id/session/close", workspacePaneCloseSession)
        .post("/workspaces/:id/panes/:pane_id/session/resume", workspacePaneResumeSession)
        .post("/workspaces/:id/panes/:pane_id/session/recreate", workspacePaneRecreateSession)
        .post("/workspaces/:id/missions/:mission_id/activate", workspaceMissionActivate)
        .post("/workspaces/:id/missions/:mission_id/dispatch/pilot", workspaceMissionDispatchToPilot)
        .post("/workspaces/:id/missions/:mission_id/dispatch/planner", workspaceMissionDispatchPilotBriefToPlanner)
        .post("/workspaces/:id/missions/:mission_id/dispatch/scout", workspaceMissionDispatchPlannerPlanToScout)
        .post("/workspaces/:id/missions/:mission_id/dispatch/builder", workspaceMissionDispatchScoutReportToBuilder)
        .post("/workspaces/:id/missions/:mission_id/dispatch/reviewer", workspaceMissionDispatchBuilderReportToReviewer)
        .post("/workspaces/:id/missions/:mission_id/dispatch/executor", workspaceMissionDispatchReviewerReportToExecutor)
        .post("/workspaces/:id/missions/:mission_id/dispatch/pilot-delivery", workspaceMissionDispatchExecutorReportToPilot)
        .post("/missions/:id/capture/pilot-brief", missionCapturePilotOperationalBrief)
        .post("/missions/:id/capture/planner-plan", missionCapturePlannerOperationalPlan)
        .post("/missions/:id/capture/scout-report", missionCaptureScoutReport)
        .post("/missions/:id/capture/builder-report", missionCaptureBuilderImplementationReport)
        .post("/missions/:id/capture/reviewer-report", missionCaptureReviewerReviewReport)
        .post("/missions/:id/capture/executor-report", missionCaptureExecutorVerificationReport)
        .post("/missions/:id/capture/pilot-delivery-report", missionCapturePilotDeliveryReport)
        .post("/missions/:id/finalize", missionFinalizeFromPilotDeliveryReport)
        .get("/workspaces/:id", workspaceShow)
        .get("/missions", missions)
        .get("/missions/new", missionNew)
        .post("/missions", missionCreate)
        .get("/missions/:id", missionShow)
        .get("/missions/:id/edit", missionEdit)
        .post("/missions/:id/update", missionUpdate)
        .post("/missions/:id/delete", missionDelete)
        .get("/agents", agents)
        .get("/agents/new", agentNew)
        .post("/agents", agentCreate)
        .get("/agents/:id", agentShow)
        .get("/agents/:id/edit", agentEdit)
        .post("/agents/:id/update", agentUpdate)
        .post("/agents/:id/delete", agentDelete)
        .get("/squads", squads)
        .get("/squads/new", squadNew)
        .post("/squads", squadCreate)
        .get("/squads/:id", squadShow)
        .get("/squads/:id/edit", squadEdit)
        .post("/squads/:id/update", squadUpdate)
        .post("/squads/:id/delete", squadDelete)
        .get("/providers", providers)
        .get("/providers/new", providerNew)
        .post("/providers", providerCreate)
        .get("/providers/:id", providerShow)
        .get("/providers/:id/edit", providerEdit)
        .post("/providers/:id/update", providerUpdate)
        .post("/providers/:id/delete", providerDelete)
        .get("/providers/:id/models/new", providerModelNew)
        .post("/providers/:id/models", providerModelCreate)
        .get("/providers/:id/models/:model_id/edit", providerModelEdit)
        .post("/providers/:id/models/:model_id/update", providerModelUpdate)
        .post("/providers/:id/models/:model_id/delete", providerModelDelete)
        .get("/stacks", stacks)
        .get("/stacks/new", stackNew)
        .post("/stacks", stackCreate)
        .get("/stacks/:id/edit", stackEdit)
        .post("/stacks/:id/update", stackUpdate)
        .post("/stacks/:id/delete", stackDelete)
        .listen(.{}) catch {};
}

const WorkspaceRow = struct {
    id: i32,
    name: []const u8,
    local_path: []const u8,
    stack_name: []const u8,
    default_squad_id: ?i32,
    squad_name: []const u8,
    status: []const u8,
};


const WorkspaceIndexRow = struct {
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

const WorkspaceForm = struct {
    name: []const u8,
    local_path: []const u8,
    stack_name: []const u8,
    default_squad_id: []const u8,
};


const WorkspaceLocalPathConfirmForm = struct {
    name: []const u8,
    local_path: []const u8,
    stack_name: []const u8,
    default_squad_id: []const u8,
    confirm_local_path_change: []const u8,
};

const WorkspaceIdRow = struct {
    id: i32,
};


const WorkspaceSquadOptionRow = struct {
    id: i32,
    name: []const u8,
    slug: []const u8,
};


const ProviderRow = struct {
    id: i32,
    name: []const u8,
    provider_type: []const u8,
    base_url: []const u8,
    api_key: []const u8,
    is_active: bool,
};

const ProviderForm = struct {
    name: []const u8,
    provider_type: []const u8,
    base_url: []const u8,
    api_key: []const u8,
    is_active: []const u8,
};

const ProviderIdRow = struct {
    id: i32,
};


const ProviderModelRow = struct {
    id: i32,
    provider_id: i32,
    model_name: []const u8,
    model_id: []const u8,
    context_window: i32,
    is_active: bool,
};

const ProviderModelForm = struct {
    model_name: []const u8,
    model_id: []const u8,
    context_window: []const u8,
    is_active: []const u8,
};

const ProviderModelIdRow = struct {
    id: i32,
};


const StackRow = struct {
    id: i32,
    name: []const u8,
    runtime_tool: []const u8,
    provider_model_id: i32,
    model_name: []const u8,
    model_identifier: []const u8,
    provider_name: []const u8,
    is_active: bool,
};

const StackForm = struct {
    name: []const u8,
    runtime_tool: []const u8,
    provider_model_id: []const u8,
    is_active: []const u8,
};

const StackIdRow = struct {
    id: i32,
};

const StackModelOptionRow = struct {
    id: i32,
    model_name: []const u8,
    model_identifier: []const u8,
    provider_name: []const u8,
};


const AgentRow = struct {
    id: i32,
    name: []const u8,
    handle: []const u8,
    agent_role: []const u8,
    summary: []const u8,
    system_prompt: []const u8,
    operating_rules: []const u8,
    default_stack_id: i32,
    stack_name: []const u8,
    runtime_tool: []const u8,
    model_name: []const u8,
    is_active: bool,
};

const AgentForm = struct {
    name: []const u8,
    handle: []const u8,
    agent_role: []const u8,
    summary: []const u8,
    system_prompt: []const u8,
    operating_rules: []const u8,
    default_stack_id: []const u8,
    is_active: []const u8,
};

const AgentIdRow = struct {
    id: i32,
};

const AgentStackOptionRow = struct {
    id: i32,
    name: []const u8,
    runtime_tool: []const u8,
    model_name: []const u8,
};


const SquadRow = struct {
    id: i32,
    name: []const u8,
    slug: []const u8,
    summary: []const u8,
    is_default: bool,
    is_active: bool,
};

const SquadIdRow = struct {
    id: i32,
};

const SquadForm = struct {
    name: []const u8,
    slug: []const u8,
    summary: []const u8,
    is_default: []const u8,
    is_active: []const u8,
    pilot_agent_id: []const u8,
    planner_agent_id: []const u8,
    scout_agent_id: []const u8,
    builder_agent_id: []const u8,
    reviewer_agent_id: []const u8,
    executor_agent_id: []const u8,
};

const SquadAgentOptionRow = struct {
    id: i32,
    name: []const u8,
    handle: []const u8,
    agent_role: []const u8,
};

const SquadMemberRow = struct {
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

const SquadMemberAgentIdRow = struct {
    agent_id: i32,
};


const WorkspacePaneRow = struct {
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


const WorkspacePaneControlRow = struct {
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

const WorkspacePaneBootstrapRow = struct {
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
};

const OpenCodeTextPart = struct {
    type: []const u8,
    text: []const u8,
};

const OpenCodeBootstrapMessageRequest = struct {
    noReply: bool,
    parts: []const OpenCodeTextPart,
};



const MissionRow = struct {
    id: i32,
    workspace_id: i32,
    workspace_name: []const u8,
    squad_id: i32,
    squad_name: []const u8,
    title: []const u8,
    objective: []const u8,
    status: []const u8,
    priority: []const u8,
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
};


const WorkspaceMissionPreviewRow = struct {
    id: i32,
    workspace_id: i32,
    workspace_name: []const u8,
    squad_id: i32,
    squad_name: []const u8,
    title: []const u8,
    objective: []const u8,
    status: []const u8,
    priority: []const u8,
    mission_operational_closure_status: []const u8,
    is_active_in_cockpit: bool,
    mission_final_verdict: []const u8,
    mission_operational_closed_at_label: []const u8,
};


const ActiveMissionPanelRow = struct {
    id: i32,
    workspace_id: i32,
    workspace_name: []const u8,
    squad_id: i32,
    squad_name: []const u8,
    title: []const u8,
    objective: []const u8,
    status: []const u8,
    priority: []const u8,
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
};


const WorkspaceMissionPaneDispatchRow = struct {
    id: i32,
    role_name: []const u8,
    pane_state: []const u8,
    session_external_id: []const u8,
    context_state: []const u8,
};

const OpenCodePromptAsyncRequest = struct {
    parts: []const OpenCodeTextPart,
};

const MissionForm = struct {
    workspace_id: []const u8,
    context_workspace_id: []const u8,
    title: []const u8,
    objective: []const u8,
    status: []const u8,
    priority: []const u8,
};

const MissionUpdateForm = struct {
    title: []const u8,
    objective: []const u8,
    status: []const u8,
    priority: []const u8,
};

const MissionIdRow = struct {
    id: i32,
};

const MissionActivationTargetRow = struct {
    id: i32,
    mission_operational_closure_status: []const u8,
};


const MissionPilotDispatchTraceRow = struct {
    pilot_dispatch_user_message_id: []const u8,
};

const MissionPlannerDispatchTraceRow = struct {
    planner_dispatch_user_message_id: []const u8,
};

const MissionReviewerDispatchTraceRow = struct {
    reviewer_dispatch_user_message_id: []const u8,
};

const MissionScoutDispatchTraceRow = struct {
    scout_dispatch_user_message_id: []const u8,
};

const MissionBuilderDispatchTraceRow = struct {
    builder_dispatch_user_message_id: []const u8,
};


const MissionExecutorDispatchTraceRow = struct {
    executor_dispatch_user_message_id: []const u8,
};

const MissionPilotDeliveryDispatchTraceRow = struct {
    pilot_delivery_dispatch_user_message_id: []const u8,
};

const MissionClosureFinalizeRow = struct {
    id: i32,
    workspace_id: i32,
    title: []const u8,
    pilot_delivery_report: []const u8,
    pilot_delivery_report_status: []const u8,
    mission_final_verdict: []const u8,
    mission_operational_closure_status: []const u8,
};


const MissionEventRow = struct {
    id: i32,
    event_type: []const u8,
    title: []const u8,
    message: []const u8,
    created_at_label: []const u8,
};

const MissionWorkspaceOptionRow = struct {
    id: i32,
    id_label: []const u8,
    name: []const u8,
    local_path: []const u8,
    default_squad_id: i32,
    squad_name: []const u8,
};


const DashboardCountRow = struct {
    total: i64,
};

const DashboardWorkspaceRow = struct {
    id: i32,
    name: []const u8,
    local_path: []const u8,
    squad_name: []const u8,
};

const DashboardMissionRow = struct {
    id: i32,
    title: []const u8,
    workspace_name: []const u8,
    squad_name: []const u8,
    status: []const u8,
    priority: []const u8,
};


const WorkspaceRuntimeRow = struct {
    workspace_id: i32,
    state: []const u8,
    container_name: []const u8,
    opencode_port_label: []const u8,
    server_url_label: []const u8,
    status_message: []const u8,
    is_prepared: bool,
};

const WorkspaceRuntimeCountRow = struct {
    total: i64,
};


const WorkspaceRuntimeControlRow = struct {
    workspace_id: i32,
    local_path: []const u8,
    container_name: []const u8,
    state: []const u8,
};


const WorkspaceRuntimeEventRow = struct {
    id: i32,
    event_type: []const u8,
    title: []const u8,
    message: []const u8,
};


const WorkspaceRuntimeLogRow = struct {
    id: i32,
    action: []const u8,
    command_label: []const u8,
    exit_code: i32,
    succeeded: bool,
    stdout_excerpt: []const u8,
    stderr_excerpt: []const u8,
};


const WorkspacePaneSessionHistoryRow = struct {
    id: i32,
    role_name: []const u8,
    previous_session_external_id: []const u8,
    replacement_session_external_id: []const u8,
    replacement_reason: []const u8,
    previous_session_agent_handle: []const u8,
    replacement_session_agent_handle: []const u8,
    created_at_label: []const u8,
};

const RuntimeCommandResult = struct {
    ok: bool,
    exit_code: i32,
    stdout: []const u8,
    stderr: []const u8,
};


fn loadWorkspaceSquads(c: *spider.Ctx) ![]WorkspaceSquadOptionRow {
    return db.query(
        WorkspaceSquadOptionRow,
        c.arena,
        \\SELECT id, name, slug
        \\FROM squads
        \\WHERE is_active = TRUE
        \\ORDER BY is_default DESC, name ASC
        ,
        .{},
    );
}


fn loadWorkspaceSquadsForSelected(c: *spider.Ctx, selected_squad_id: i32) ![]WorkspaceSquadOptionRow {
    return db.query(
        WorkspaceSquadOptionRow,
        c.arena,
        \\SELECT id, name, slug
        \\FROM squads
        \\WHERE is_active = TRUE
        \\ORDER BY CASE WHEN id = $1 THEN 0 ELSE 1 END,
        \\         is_default DESC,
        \\         name ASC
        ,
        .{ selected_squad_id },
    );
}

fn openCodeSessionExists(
    c: *spider.Ctx,
    server_url: []const u8,
    session_id: []const u8,
) RuntimeCommandResult {
    const session_url = std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}",
        .{ server_url, session_id },
    ) catch {
        return .{
            .ok = false,
            .exit_code = -1,
            .stdout = "",
            .stderr = "Falha ao montar URL da sessão OpenCode.",
        };
    };

    return runRuntimeCommand(c, &.{
        "curl",
        "-fsS",
        session_url,
    });
}



fn extractLatestUserMessageIdMatchingText(
    allocator: std.mem.Allocator,
    raw: []const u8,
    expected_text: []const u8,
) !?[]const u8 {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, raw, .{});
    defer parsed.deinit();

    const root = parsed.value;
    if (root != .array) return null;

    var latest_id: ?[]const u8 = null;

    for (root.array.items) |message_value| {
        if (message_value != .object) continue;

        const message_obj = message_value.object;
        const info_value = message_obj.get("info") orelse continue;
        if (info_value != .object) continue;

        const role_value = info_value.object.get("role") orelse continue;
        if (role_value != .string) continue;
        if (!std.mem.eql(u8, role_value.string, "user")) continue;

        const message_id_value = info_value.object.get("id") orelse continue;
        if (message_id_value != .string) continue;

        const parts_value = message_obj.get("parts") orelse continue;
        if (parts_value != .array) continue;

        var matches_dispatch = false;

        for (parts_value.array.items) |part_value| {
            if (part_value != .object) continue;

            const part_obj = part_value.object;

            const type_value = part_obj.get("type") orelse continue;
            if (type_value != .string) continue;
            if (!std.mem.eql(u8, type_value.string, "text")) continue;

            const text_value = part_obj.get("text") orelse continue;
            if (text_value != .string) continue;

            if (std.mem.eql(u8, text_value.string, expected_text)) {
                matches_dispatch = true;
                break;
            }
        }

        if (matches_dispatch) {
            latest_id = try allocator.dupe(u8, message_id_value.string);
        }
    }

    return latest_id;
}

fn extractAssistantTextForParentMessage(
    allocator: std.mem.Allocator,
    raw: []const u8,
    parent_message_id: []const u8,
) !?[]const u8 {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, raw, .{});
    defer parsed.deinit();

    const root = parsed.value;
    if (root != .array) return null;

    var latest_text: ?[]const u8 = null;

    for (root.array.items) |message_value| {
        if (message_value != .object) continue;

        const message_obj = message_value.object;
        const info_value = message_obj.get("info") orelse continue;
        if (info_value != .object) continue;

        const role_value = info_value.object.get("role") orelse continue;
        if (role_value != .string) continue;
        if (!std.mem.eql(u8, role_value.string, "assistant")) continue;

        const parent_value = info_value.object.get("parentID") orelse continue;
        if (parent_value != .string) continue;
        if (!std.mem.eql(u8, parent_value.string, parent_message_id)) continue;

        const parts_value = message_obj.get("parts") orelse continue;
        if (parts_value != .array) continue;

        var collected: std.ArrayList(u8) = .empty;
        errdefer collected.deinit(allocator);

        var found_text = false;

        for (parts_value.array.items) |part_value| {
            if (part_value != .object) continue;

            const part_obj = part_value.object;

            const type_value = part_obj.get("type") orelse continue;
            if (type_value != .string) continue;
            if (!std.mem.eql(u8, type_value.string, "text")) continue;

            const text_value = part_obj.get("text") orelse continue;
            if (text_value != .string) continue;

            if (found_text) {
                try collected.appendSlice(allocator, "\n\n");
            }

            try collected.appendSlice(allocator, text_value.string);
            found_text = true;
        }

        if (found_text) {
            latest_text = try collected.toOwnedSlice(allocator);
        } else {
            collected.deinit(allocator);
        }
    }

    return latest_text;
}

fn extractLatestAssistantTextFromOpenCodeMessages(
    allocator: std.mem.Allocator,
    raw: []const u8,
) !?[]const u8 {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, raw, .{});
    defer parsed.deinit();

    const root = parsed.value;
    if (root != .array) return null;

    var latest_text: ?[]const u8 = null;

    for (root.array.items) |message_value| {
        if (message_value != .object) continue;

        const message_obj = message_value.object;

        const info_value = message_obj.get("info") orelse continue;
        if (info_value != .object) continue;

        const role_value = info_value.object.get("role") orelse continue;
        if (role_value != .string) continue;

        if (!std.mem.eql(u8, role_value.string, "assistant")) continue;

        const parts_value = message_obj.get("parts") orelse continue;
        if (parts_value != .array) continue;

        var collected: std.ArrayList(u8) = .empty;
        errdefer collected.deinit(allocator);

        var found_text = false;

        for (parts_value.array.items) |part_value| {
            if (part_value != .object) continue;

            const part_obj = part_value.object;

            const type_value = part_obj.get("type") orelse continue;
            if (type_value != .string) continue;

            if (!std.mem.eql(u8, type_value.string, "text")) continue;

            const text_value = part_obj.get("text") orelse continue;
            if (text_value != .string) continue;

            if (found_text) {
                try collected.appendSlice(allocator, "\n\n");
            }

            try collected.appendSlice(allocator, text_value.string);
            found_text = true;
        }

        if (found_text) {
            latest_text = try collected.toOwnedSlice(allocator);
        } else {
            collected.deinit(allocator);
        }
    }

    return latest_text;
}

fn containsAsciiCaseInsensitive(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (haystack.len < needle.len) return false;

    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        var j: usize = 0;

        while (j < needle.len) : (j += 1) {
            const left = std.ascii.toLower(haystack[i + j]);
            const right = std.ascii.toLower(needle[j]);

            if (left != right) break;
        }

        if (j == needle.len) {
            return true;
        }
    }

    return false;
}

fn extractMissionFinalVerdictFromPilotDeliveryReport(report: []const u8) []const u8 {
    const completed_patterns = [_][]const u8{
        "**status final:** completed",
        "status final: completed",
        "**veredito final:** completed",
        "veredito final: completed",
        "**conclusão operacional:** completed",
        "conclusão operacional: completed",
        "**status** | `completed`",
        "status | `completed`",
        "**status** | completed",
        "status | completed",
        "## ✅ completed",
        "## 🟢 completed",
        "## completed",
    };

    for (completed_patterns) |pattern| {
        if (containsAsciiCaseInsensitive(report, pattern)) {
            return "completed";
        }
    }

    const follow_up_patterns = [_][]const u8{
        "**status final:** needs_follow_up",
        "status final: needs_follow_up",
        "**veredito final:** needs_follow_up",
        "veredito final: needs_follow_up",
        "**conclusão operacional:** needs_follow_up",
        "conclusão operacional: needs_follow_up",
        "**status** | `needs_follow_up`",
        "status | `needs_follow_up`",
        "**status** | needs_follow_up",
        "status | needs_follow_up",
        "## 🟡 needs_follow_up",
        "## needs_follow_up",
    };

    for (follow_up_patterns) |pattern| {
        if (containsAsciiCaseInsensitive(report, pattern)) {
            return "needs_follow_up";
        }
    }

    const blocked_patterns = [_][]const u8{
        "**status final:** blocked",
        "status final: blocked",
        "**veredito final:** blocked",
        "veredito final: blocked",
        "**conclusão operacional:** blocked",
        "conclusão operacional: blocked",
        "**status** | `blocked`",
        "status | `blocked`",
        "**status** | blocked",
        "status | blocked",
        "## 🔴 blocked",
        "## blocked",
    };

    for (blocked_patterns) |pattern| {
        if (containsAsciiCaseInsensitive(report, pattern)) {
            return "blocked";
        }
    }

    return "";
}

fn extractOpenCodeSessionId(raw: []const u8) ?[]const u8 {
    const key = "\"id\"";
    const key_index = std.mem.indexOf(u8, raw, key) orelse return null;

    var cursor: usize = key_index + key.len;

    while (cursor < raw.len and raw[cursor] != ':') : (cursor += 1) {}
    if (cursor >= raw.len) return null;

    cursor += 1;

    while (
        cursor < raw.len and
        (raw[cursor] == ' ' or raw[cursor] == '\n' or raw[cursor] == '\r' or raw[cursor] == '\t')
    ) : (cursor += 1) {}

    if (cursor >= raw.len or raw[cursor] != '"') return null;

    const start = cursor + 1;
    cursor = start;

    while (cursor < raw.len and raw[cursor] != '"') : (cursor += 1) {}
    if (cursor >= raw.len) return null;

    return raw[start..cursor];
}

fn runtimeLogExcerpt(raw: []const u8) []const u8 {
    const limit: usize = 1800;

    if (raw.len <= limit) {
        return raw;
    }

    return raw[raw.len - limit ..];
}

fn runRuntimeCommand(c: *spider.Ctx, argv: []const []const u8) RuntimeCommandResult {
    const result = std.process.run(c.arena, c._io, .{
        .argv = argv,
    }) catch {
        return .{
            .ok = false,
            .exit_code = -1,
            .stdout = "",
            .stderr = "Falha ao executar processo externo.",
        };
    };

    const exit_code: i32 = switch (result.term) {
        .exited => |code| @intCast(code),
        else => -1,
    };

    return .{
        .ok = exit_code == 0,
        .exit_code = exit_code,
        .stdout = result.stdout,
        .stderr = result.stderr,
    };
}

fn insertRuntimeCommandLog(
    c: *spider.Ctx,
    workspace_id: i32,
    action: []const u8,
    command_label: []const u8,
    result: RuntimeCommandResult,
) !void {
    try db.query(
        void,
        c.arena,
        \\INSERT INTO workspace_runtime_logs (
        \\    workspace_id,
        \\    action,
        \\    command_label,
        \\    exit_code,
        \\    succeeded,
        \\    stdout_excerpt,
        \\    stderr_excerpt
        \\)
        \\VALUES ($1, $2, $3, $4, $5, $6, $7)
        ,
        .{
            workspace_id,
            action,
            command_label,
            result.exit_code,
            result.ok,
            runtimeLogExcerpt(result.stdout),
            runtimeLogExcerpt(result.stderr),
        },
    );
}

fn commandSucceeded(c: *spider.Ctx, argv: []const []const u8) bool {
    const result = std.process.run(c.arena, c._io, .{
        .argv = argv,
    }) catch return false;

    return switch (result.term) {
        .exited => |code| code == 0,
        else => false,
    };
}


fn ensureWorkspaceLocalPath(c: *spider.Ctx, local_path: []const u8) bool {
    if (local_path.len == 0) {
        return false;
    }

    return commandSucceeded(c, &.{
        "mkdir",
        "-p",
        local_path,
    });
}

fn runtimeHostPort(workspace_id: i32) i32 {
    const base_port = spider.env.getInt(i32, "ZIVYAR_RUNTIME_HOST_PORT_BASE", 43000);
    return base_port + workspace_id;
}

fn waitForOpenCodeHealth(c: *spider.Ctx, server_url: []const u8) bool {
    const health_url = std.fmt.allocPrint(
        c.arena,
        "{s}/global/health",
        .{ server_url },
    ) catch return false;

    var attempt: usize = 0;
    while (attempt < 12) : (attempt += 1) {
        if (commandSucceeded(c, &.{
            "curl",
            "-fsS",
            health_url,
        })) {
            return true;
        }

        std.Io.sleep(c._io, std.Io.Duration.fromMilliseconds(500), .real) catch {};
    }

    return false;
}

fn insertRuntimeEvent(
    c: *spider.Ctx,
    workspace_id: i32,
    event_type: []const u8,
    title: []const u8,
    message: []const u8,
) !void {
    try db.query(
        void,
        c.arena,
        \\INSERT INTO workspace_runtime_events (
        \\    workspace_id,
        \\    event_type,
        \\    title,
        \\    message
        \\)
        \\VALUES ($1, $2, $3, $4)
        ,
        .{
            workspace_id,
            event_type,
            title,
            message,
        },
    );
}

fn reconcileWorkspacePaneSessions(
    c: *spider.Ctx,
    workspace_id: i32,
    runtime: WorkspaceRuntimeRow,
) !void {
    if (!std.mem.eql(u8, runtime.state, "running")) {
        return;
    }

    const panes = try db.query(
        WorkspacePaneControlRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    workspace_id,
        \\    role_name,
        \\    agent_id,
        \\    pane_state,
        \\    session_external_id,
        \\    session_agent_id,
        \\    session_agent_handle,
        \\    context_state,
        \\    stale_reason
        \\FROM workspace_panes
        \\WHERE workspace_id = $1
        \\AND session_external_id <> ''
        \\AND pane_state IN ('active', 'closed')
        \\ORDER BY id ASC
        ,
        .{ workspace_id },
    );

    for (panes) |pane| {
        const check_result = openCodeSessionExists(
            c,
            runtime.server_url_label,
            pane.session_external_id,
        );

        if (check_result.ok) {
            continue;
        }

        try db.query(
            void,
            c.arena,
            \\UPDATE workspace_panes
            \\SET pane_state = 'stale',
            \\    updated_at = NOW()
            \\WHERE id = $1
            \\AND workspace_id = $2
            ,
            .{ pane.id, workspace_id },
        );

        try insertRuntimeCommandLog(
            c,
            workspace_id,
            "opencode-validate-session",
            "GET <opencode-server>/session/<session-id>",
            check_result,
        );

        const stale_message = try std.fmt.allocPrint(
            c.arena,
            "A sessão {s} vinculada ao pane {s} não foi localizada no OpenCode Server.",
            .{ pane.session_external_id, pane.role_name },
        );

        try insertRuntimeEvent(
            c,
            workspace_id,
            "pane-session-stale",
            "Sessão do pane indisponível",
            stale_message,
        );
    }
}

fn reconcileWorkspaceRuntimeState(
    c: *spider.Ctx,
    runtime: WorkspaceRuntimeRow,
) !void {
    if (!runtime.is_prepared) {
        return;
    }

    const inspect_result = runRuntimeCommand(c, &.{
        "docker",
        "inspect",
        "--format",
        "{{.State.Running}}",
        runtime.container_name,
    });

    if (!inspect_result.ok) {
        if (!std.mem.eql(u8, runtime.state, "missing")) {
            try db.query(
                void,
                c.arena,
                \\UPDATE workspace_runtimes
                \\SET state = 'missing',
                \\    status_message = 'O container do runtime não foi encontrado no Docker.',
                \\    updated_at = NOW()
                \\WHERE workspace_id = $1
                ,
                .{ runtime.workspace_id },
            );

            try insertRuntimeEvent(
                c,
                runtime.workspace_id,
                "missing",
                "Container não encontrado",
                "O Zivyar detectou que o container registrado para este workspace não existe mais no Docker.",
            );

            try insertRuntimeCommandLog(
                c,
                runtime.workspace_id,
                "inspect-container-state",
                "docker inspect --format {{.State.Running}} <workspace-container>",
                inspect_result,
            );
        }

        return;
    }

    const inspected_value = std.mem.trim(
        u8,
        inspect_result.stdout,
        " \r\n\t",
    );

    const docker_state =
        if (std.mem.eql(u8, inspected_value, "true"))
            "running"
        else
            "stopped";

    if (std.mem.eql(u8, runtime.state, docker_state)) {
        return;
    }

    if (std.mem.eql(u8, docker_state, "running")) {
        try db.query(
            void,
            c.arena,
            \\UPDATE workspace_runtimes
            \\SET state = 'running',
            \\    status_message = 'Estado reconciliado: o container está em execução no Docker.',
            \\    updated_at = NOW()
            \\WHERE workspace_id = $1
            ,
            .{ runtime.workspace_id },
        );

        try insertRuntimeEvent(
            c,
            runtime.workspace_id,
            "reconciled-running",
            "Runtime reconciliado como ativo",
            "O Zivyar verificou o Docker e encontrou o container deste workspace em execução.",
        );
    } else {
        try db.query(
            void,
            c.arena,
            \\UPDATE workspace_runtimes
            \\SET state = 'stopped',
            \\    status_message = 'Estado reconciliado: o container está parado no Docker.',
            \\    updated_at = NOW()
            \\WHERE workspace_id = $1
            ,
            .{ runtime.workspace_id },
        );

        try insertRuntimeEvent(
            c,
            runtime.workspace_id,
            "reconciled-stopped",
            "Runtime reconciliado como parado",
            "O Zivyar verificou o Docker e encontrou o container deste workspace interrompido.",
        );
    }

    try insertRuntimeCommandLog(
        c,
        runtime.workspace_id,
        "inspect-container-state",
        "docker inspect --format {{.State.Running}} <workspace-container>",
        inspect_result,
    );
}

fn loadWorkspaceRuntime(c: *spider.Ctx, workspace_id: i32) ![]WorkspaceRuntimeRow {
    return db.query(
        WorkspaceRuntimeRow,
        c.arena,
        \\SELECT
        \\    w.id AS workspace_id,
        \\    COALESCE(r.state, 'not_prepared') AS state,
        \\    COALESCE(NULLIF(r.container_name, ''), 'Ainda não criado') AS container_name,
        \\    CASE
        \\        WHEN r.opencode_port IS NULL OR r.opencode_port = 0 THEN 'A definir'
        \\        ELSE r.opencode_port::text
        \\    END AS opencode_port_label,
        \\    COALESCE(NULLIF(r.server_url, ''), 'A definir') AS server_url_label,
        \\    COALESCE(NULLIF(r.status_message, ''), 'Runtime ainda não preparado.') AS status_message,
        \\    CASE
        \\        WHEN r.id IS NULL THEN FALSE
        \\        ELSE TRUE
        \\    END AS is_prepared
        \\FROM workspaces w
        \\LEFT JOIN workspace_runtimes r ON r.workspace_id = w.id
        \\WHERE w.id = $1
        \\LIMIT 1
        ,
        .{ workspace_id },
    );
}

fn dashboard(c: *spider.Ctx) !spider.Response {
    const workspace_count_rows = try db.query(
        DashboardCountRow,
        c.arena,
        \\SELECT COUNT(*)::bigint AS total
        \\FROM workspaces
        ,
        .{},
    );

    const mission_count_rows = try db.query(
        DashboardCountRow,
        c.arena,
        \\SELECT COUNT(*)::bigint AS total
        \\FROM missions
        ,
        .{},
    );

    const open_mission_count_rows = try db.query(
        DashboardCountRow,
        c.arena,
        \\SELECT COUNT(*)::bigint AS total
        \\FROM missions
        \\WHERE status <> 'completed'
        ,
        .{},
    );

    const agent_count_rows = try db.query(
        DashboardCountRow,
        c.arena,
        \\SELECT COUNT(*)::bigint AS total
        \\FROM agents
        ,
        .{},
    );

    const squad_count_rows = try db.query(
        DashboardCountRow,
        c.arena,
        \\SELECT COUNT(*)::bigint AS total
        \\FROM squads
        ,
        .{},
    );

    const provider_count_rows = try db.query(
        DashboardCountRow,
        c.arena,
        \\SELECT COUNT(*)::bigint AS total
        \\FROM providers
        ,
        .{},
    );

    const stack_count_rows = try db.query(
        DashboardCountRow,
        c.arena,
        \\SELECT COUNT(*)::bigint AS total
        \\FROM stacks
        ,
        .{},
    );

    const recent_workspaces = try db.query(
        DashboardWorkspaceRow,
        c.arena,
        \\SELECT
        \\    w.id,
        \\    w.name,
        \\    w.local_path,
        \\    COALESCE(s.name, 'Sem squad vinculada') AS squad_name
        \\FROM workspaces w
        \\LEFT JOIN squads s ON s.id = w.default_squad_id
        \\ORDER BY w.id DESC
        \\LIMIT 4
        ,
        .{},
    );

    const recent_missions = try db.query(
        DashboardMissionRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.title,
        \\    w.name AS workspace_name,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name,
        \\    m.status,
        \\    m.priority,
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
        \\    ) AS mission_operational_closed_at_label
        \\FROM missions m
        \\INNER JOIN workspaces w ON w.id = m.workspace_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\ORDER BY m.id DESC
        \\LIMIT 4
        ,
        .{},
    );

    return c.view("dashboard/index", .{
        .title = "Zivyar Cockpit",
        .subtitle = "Desktop Multi-Agent Engineering Cockpit",
        .workspace_count = workspace_count_rows[0].total,
        .mission_count = mission_count_rows[0].total,
        .open_mission_count = open_mission_count_rows[0].total,
        .agent_count = agent_count_rows[0].total,
        .squad_count = squad_count_rows[0].total,
        .provider_count = provider_count_rows[0].total,
        .stack_count = stack_count_rows[0].total,
        .recent_workspaces = recent_workspaces,
        .recent_workspace_count = recent_workspaces.len,
        .recent_missions = recent_missions,
        .recent_mission_count = recent_missions.len,
    }, .{});
}

fn workspaces(c: *spider.Ctx) !spider.Response {
    const initial_rows = try db.query(
        WorkspaceIndexRow,
        c.arena,
        \\SELECT
        \\    w.id,
        \\    w.name,
        \\    w.local_path,
        \\    w.stack_name,
        \\    w.default_squad_id,
        \\    COALESCE(s.name, 'Sem squad vinculada') AS squad_name,
        \\    w.status,
        \\    COALESCE(r.state, 'not_prepared') AS runtime_state,
        \\    COALESCE(NULLIF(r.container_name, ''), 'Ainda não criado') AS runtime_container_name,
        \\    CASE
        \\        WHEN r.opencode_port IS NULL OR r.opencode_port = 0 THEN 'A definir'
        \\        ELSE r.opencode_port::text
        \\    END AS runtime_port_label,
        \\    COALESCE(NULLIF(r.server_url, ''), 'A definir') AS runtime_server_url_label,
        \\    CASE
        \\        WHEN r.id IS NULL THEN FALSE
        \\        ELSE TRUE
        \\    END AS runtime_is_prepared,
        \\    CASE
        \\        WHEN r.state = 'running' THEN TRUE
        \\        ELSE FALSE
        \\    END AS runtime_is_running
        \\FROM workspaces w
        \\LEFT JOIN squads s ON s.id = w.default_squad_id
        \\LEFT JOIN workspace_runtimes r ON r.workspace_id = w.id
        \\ORDER BY w.id DESC
        ,
        .{},
    );

    for (initial_rows) |workspace| {
        if (!workspace.runtime_is_prepared) {
            continue;
        }

        const runtime_rows = try loadWorkspaceRuntime(c, workspace.id);

        if (runtime_rows.len == 0) {
            continue;
        }

        try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);
    }

    const rows = try db.query(
        WorkspaceIndexRow,
        c.arena,
        \\SELECT
        \\    w.id,
        \\    w.name,
        \\    w.local_path,
        \\    w.stack_name,
        \\    w.default_squad_id,
        \\    COALESCE(s.name, 'Sem squad vinculada') AS squad_name,
        \\    w.status,
        \\    COALESCE(r.state, 'not_prepared') AS runtime_state,
        \\    COALESCE(NULLIF(r.container_name, ''), 'Ainda não criado') AS runtime_container_name,
        \\    CASE
        \\        WHEN r.opencode_port IS NULL OR r.opencode_port = 0 THEN 'A definir'
        \\        ELSE r.opencode_port::text
        \\    END AS runtime_port_label,
        \\    COALESCE(NULLIF(r.server_url, ''), 'A definir') AS runtime_server_url_label,
        \\    CASE
        \\        WHEN r.id IS NULL THEN FALSE
        \\        ELSE TRUE
        \\    END AS runtime_is_prepared,
        \\    CASE
        \\        WHEN r.state = 'running' THEN TRUE
        \\        ELSE FALSE
        \\    END AS runtime_is_running
        \\FROM workspaces w
        \\LEFT JOIN squads s ON s.id = w.default_squad_id
        \\LEFT JOIN workspace_runtimes r ON r.workspace_id = w.id
        \\ORDER BY w.id DESC
        ,
        .{},
    );

    const runtime_count_rows = try db.query(
        WorkspaceRuntimeCountRow,
        c.arena,
        \\SELECT COUNT(*)::bigint AS total
        \\FROM workspace_runtimes
        \\WHERE state = 'running'
        ,
        .{},
    );

    const mission_count_rows = try db.query(
        WorkspaceRuntimeCountRow,
        c.arena,
        \\SELECT COUNT(*)::bigint AS total
        \\FROM missions
        \\WHERE status <> 'completed'
        ,
        .{},
    );

    const notice =
        if (c.query("created") != null)
            "Workspace cadastrado com sucesso."
        else if (c.query("updated") != null)
            "Workspace atualizado com sucesso."
        else if (c.query("deleted") != null)
            "Workspace removido com sucesso."
        else
            "";

    return c.view("workspaces/index", .{
        .title = "Workspaces",
        .workspaces = rows,
        .workspace_count = rows.len,
        .runtime_count = runtime_count_rows[0].total,
        .mission_count = mission_count_rows[0].total,
        .notice = notice,
    }, .{});
}

fn workspaceNew(c: *spider.Ctx) !spider.Response {
    const squads_rows = try loadWorkspaceSquads(c);

    return c.view("workspaces/new", .{
        .title = "Novo Workspace",
        .squads = squads_rows,
        .squad_count = squads_rows.len,
        .error_message = "",
        .form = .{
            .name = "",
            .local_path = "",
            .stack_name = "Spider + Zig",
            .default_squad_id = "",
        },
    }, .{});
}


fn workspaceEdit(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const rows = try db.query(
        WorkspaceRow,
        c.arena,
        \\SELECT
        \\    w.id,
        \\    w.name,
        \\    w.local_path,
        \\    w.stack_name,
        \\    w.default_squad_id,
        \\    COALESCE(s.name, 'Sem squad vinculada') AS squad_name,
        \\    w.status
        \\FROM workspaces w
        \\LEFT JOIN squads s ON s.id = w.default_squad_id
        \\WHERE w.id = $1
        \\LIMIT 1
        ,
        .{ workspace_id },
    );

    if (rows.len == 0) {
        return c.text("Workspace não encontrado.", .{ .status = .not_found });
    }

    const workspace = rows[0];
    const squads_rows = try loadWorkspaceSquadsForSelected(
        c,
        workspace.default_squad_id orelse 0,
    );

    return c.view("workspaces/edit", .{
        .title = "Editar Workspace",
        .workspace = workspace,
        .squads = squads_rows,
        .squad_count = squads_rows.len,
        .error_message = "",
        .path_change_confirmation_required = false,
        .pending_name = "",
        .pending_local_path = "",
        .pending_stack_name = "",
        .pending_default_squad_id = "",
    }, .{});
}

fn workspaceUpdate(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const form = try c.parseForm(WorkspaceForm);
    const squads_rows = try loadWorkspaceSquads(c);
    const default_squad_id = std.fmt.parseInt(i32, form.default_squad_id, 10) catch 0;

    const current_rows = try db.query(
        WorkspaceRow,
        c.arena,
        \\SELECT
        \\    w.id,
        \\    w.name,
        \\    w.local_path,
        \\    w.stack_name,
        \\    w.default_squad_id,
        \\    COALESCE(s.name, 'Sem squad vinculada') AS squad_name,
        \\    w.status
        \\FROM workspaces w
        \\LEFT JOIN squads s ON s.id = w.default_squad_id
        \\WHERE w.id = $1
        \\LIMIT 1
        ,
        .{ workspace_id },
    );

    if (current_rows.len == 0) {
        return c.text("Workspace não encontrado.", .{ .status = .not_found });
    }

    const duplicated = try db.query(
        WorkspaceIdRow,
        c.arena,
        \\SELECT id
        \\FROM workspaces
        \\WHERE local_path = $1
        \\AND id <> $2
        \\LIMIT 1
        ,
        .{ form.local_path, workspace_id },
    );

    if (duplicated.len > 0) {
        return c.view("workspaces/edit", .{
            .title = "Editar Workspace",
            .workspace = current_rows[0],
            .squads = squads_rows,
            .squad_count = squads_rows.len,
            .error_message = "Outro workspace já utiliza este caminho local.",
            .path_change_confirmation_required = false,
            .pending_name = "",
            .pending_local_path = "",
            .pending_stack_name = "",
            .pending_default_squad_id = "",
        }, .{ .status = .bad_request });
    }

    if (default_squad_id <= 0) {
        return c.view("workspaces/edit", .{
            .title = "Editar Workspace",
            .workspace = current_rows[0],
            .squads = squads_rows,
            .squad_count = squads_rows.len,
            .error_message = "Selecione uma squad padrão válida.",
            .path_change_confirmation_required = false,
            .pending_name = "",
            .pending_local_path = "",
            .pending_stack_name = "",
            .pending_default_squad_id = "",
        }, .{ .status = .bad_request });
    }

    const selected_squad_rows = try db.query(
        WorkspaceSquadOptionRow,
        c.arena,
        \\SELECT id, name, slug
        \\FROM squads
        \\WHERE id = $1
        \\AND is_active = TRUE
        \\LIMIT 1
        ,
        .{ default_squad_id },
    );

    if (selected_squad_rows.len == 0) {
        return c.view("workspaces/edit", .{
            .title = "Editar Workspace",
            .workspace = current_rows[0],
            .squads = squads_rows,
            .squad_count = squads_rows.len,
            .error_message = "A squad selecionada não está disponível.",
            .path_change_confirmation_required = false,
            .pending_name = "",
            .pending_local_path = "",
            .pending_stack_name = "",
            .pending_default_squad_id = "",
        }, .{ .status = .bad_request });
    }

    const local_path_changed = !std.mem.eql(
        u8,
        form.local_path,
        current_rows[0].local_path,
    );

    if (local_path_changed) {
        return c.view("workspaces/edit", .{
            .title = "Editar Workspace",
            .workspace = current_rows[0],
            .squads = squads_rows,
            .squad_count = squads_rows.len,
            .error_message = "",
            .path_change_confirmation_required = true,
            .pending_name = form.name,
            .pending_local_path = form.local_path,
            .pending_stack_name = form.stack_name,
            .pending_default_squad_id = form.default_squad_id,
        }, .{ .status = .bad_request });
    }

    if (!ensureWorkspaceLocalPath(c, form.local_path)) {
        return c.view("workspaces/edit", .{
            .title = "Editar Workspace",
            .workspace = current_rows[0],
            .squads = squads_rows,
            .squad_count = squads_rows.len,
            .error_message = "Não foi possível criar ou acessar o novo caminho local informado para o workspace.",
            .path_change_confirmation_required = false,
            .pending_name = "",
            .pending_local_path = "",
            .pending_stack_name = "",
            .pending_default_squad_id = "",
        }, .{ .status = .bad_request });
    }

    try db.query(
        void,
        c.arena,
        \\UPDATE workspaces
        \\SET name = $1,
        \\    local_path = $2,
        \\    stack_name = $3,
        \\    default_squad = $4,
        \\    default_squad_id = $5
        \\WHERE id = $6
        ,
        .{
            form.name,
            form.local_path,
            form.stack_name,
            selected_squad_rows[0].name,
            default_squad_id,
            workspace_id,
        },
    );

    return c.redirect("/workspaces?updated=1");
}

fn workspaceRuntimeLiveStatus(c: *spider.Ctx) !spider.Response {
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

    const runtime_rows = try loadWorkspaceRuntime(c, workspace_id);

    if (runtime_rows.len == 0) {
        return c.json(.{
            .ok = false,
            .message = "Runtime não encontrado.",
        }, .{ .status = .not_found });
    }

    try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_rows = try loadWorkspaceRuntime(c, workspace_id);

    if (refreshed_rows.len == 0) {
        return c.json(.{
            .ok = false,
            .message = "Runtime não encontrado após reconciliação.",
        }, .{ .status = .not_found });
    }

    const runtime = refreshed_rows[0];

    try reconcileWorkspacePaneSessions(c, workspace_id, runtime);

    const runtime_events = try db.query(
        WorkspaceRuntimeEventRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    event_type,
        \\    title,
        \\    message
        \\FROM workspace_runtime_events
        \\WHERE workspace_id = $1
        \\ORDER BY id DESC
        \\LIMIT 8
        ,
        .{ workspace_id },
    );

    const runtime_logs = try db.query(
        WorkspaceRuntimeLogRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    action,
        \\    command_label,
        \\    exit_code,
        \\    succeeded,
        \\    stdout_excerpt,
        \\    stderr_excerpt
        \\FROM workspace_runtime_logs
        \\WHERE workspace_id = $1
        \\ORDER BY id DESC
        \\LIMIT 8
        ,
        .{ workspace_id },
    );

    const workspace_panes = try db.query(
        WorkspacePaneRow,
        c.arena,
        \\SELECT
        \\    wp.id,
        \\    wp.workspace_id,
        \\    wp.role_name,
        \\    wp.squad_member_id,
        \\    wp.agent_id,
        \\    wp.pane_state,
        \\    wp.session_external_id,
        \\    wp.session_agent_id,
        \\    wp.session_agent_handle,
        \\    wp.context_state,
        \\    wp.stale_reason,
        \\    wp.display_order,
        \\    a.name AS agent_name,
        \\    a.handle AS agent_handle,
        \\    a.agent_role,
        \\    s.name AS stack_name
        \\FROM workspace_panes wp
        \\INNER JOIN agents a ON a.id = wp.agent_id
        \\INNER JOIN stacks s ON s.id = a.default_stack_id
        \\WHERE wp.workspace_id = $1
        \\ORDER BY wp.display_order ASC
        ,
        .{ workspace_id },
    );

    const pane_session_history = try db.query(
        WorkspacePaneSessionHistoryRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    role_name,
        \\    previous_session_external_id,
        \\    replacement_session_external_id,
        \\    replacement_reason,
        \\    previous_session_agent_handle,
        \\    replacement_session_agent_handle,
        \\    TO_CHAR(created_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS') AS created_at_label
        \\FROM workspace_pane_session_history
        \\WHERE workspace_id = $1
        \\ORDER BY id DESC
        \\LIMIT 8
        ,
        .{ workspace_id },
    );

    return c.json(.{
        .ok = true,
        .workspace_id = workspace_id,
        .state = runtime.state,
        .container_name = runtime.container_name,
        .opencode_port = runtime.opencode_port_label,
        .server_url = runtime.server_url_label,
        .status_message = runtime.status_message,
        .is_prepared = runtime.is_prepared,
        .is_running = std.mem.eql(u8, runtime.state, "running"),
        .runtime_events = runtime_events,
        .runtime_event_count = runtime_events.len,
        .runtime_logs = runtime_logs,
        .runtime_log_count = runtime_logs.len,
        .pane_session_history = pane_session_history,
        .pane_session_history_count = pane_session_history.len,
        .workspace_panes = workspace_panes,
        .workspace_pane_count = workspace_panes.len,
    }, .{});
}

fn workspaceRuntimeStart(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const runtime_rows = try db.query(
        WorkspaceRuntimeControlRow,
        c.arena,
        \\SELECT
        \\    w.id AS workspace_id,
        \\    w.local_path,
        \\    r.container_name,
        \\    r.state
        \\FROM workspaces w
        \\INNER JOIN workspace_runtimes r ON r.workspace_id = w.id
        \\WHERE w.id = $1
        \\LIMIT 1
        ,
        .{ workspace_id },
    );

    if (runtime_rows.len == 0) {
        return c.text("Prepare o runtime antes de iniciar.", .{ .status = .bad_request });
    }

    const runtime = runtime_rows[0];

    if (!ensureWorkspaceLocalPath(c, runtime.local_path)) {
        try db.query(
            void,
            c.arena,
            \\UPDATE workspace_runtimes
            \\SET state = 'error',
            \\    status_message = 'Falha ao criar ou acessar o diretório local do workspace.',
            \\    updated_at = NOW()
            \\WHERE workspace_id = $1
            ,
            .{ workspace_id },
        );

        try insertRuntimeEvent(
            c,
            workspace_id,
            "error",
            "Diretório do workspace indisponível",
            "O Zivyar não conseguiu criar ou acessar o caminho local configurado para este workspace.",
        );

        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{ workspace_id });
        return c.redirect(redirect_url);
    }

    const image_name = spider.env.getOr("ZIVYAR_RUNTIME_IMAGE", "zivyar-opencode-runtime:latest");
    const runtime_context = spider.env.getOr("ZIVYAR_RUNTIME_CONTEXT", "../../infra/docker/opencode-runtime");
    const internal_port = spider.env.getInt(i32, "ZIVYAR_RUNTIME_INTERNAL_PORT", 4096);
    const host_port = runtimeHostPort(workspace_id);

    const host_port_text = try std.fmt.allocPrint(c.arena, "{d}", .{ host_port });
    const internal_port_text = try std.fmt.allocPrint(c.arena, "{d}", .{ internal_port });
    const published_port = try std.fmt.allocPrint(
        c.arena,
        "127.0.0.1:{d}:{d}",
        .{ host_port, internal_port },
    );
    const volume_mount = try std.fmt.allocPrint(
        c.arena,
        "{s}:/workspace",
        .{ runtime.local_path },
    );
    const server_url = try std.fmt.allocPrint(
        c.arena,
        "http://127.0.0.1:{d}",
        .{ host_port },
    );

    try db.query(
        void,
        c.arena,
        \\UPDATE workspace_runtimes
        \\SET state = 'starting',
        \\    status_message = 'Preparando imagem e iniciando OpenCode Server...',
        \\    updated_at = NOW()
        \\WHERE workspace_id = $1
        ,
        .{ workspace_id },
    );


    try insertRuntimeEvent(
        c,
        workspace_id,
        "starting",
        "Inicialização solicitada",
        "O Zivyar iniciou o fluxo de validação da imagem Docker e abertura do OpenCode Server.",
    );

    const image_exists = commandSucceeded(c, &.{
        "docker",
        "image",
        "inspect",
        image_name,
    });

    if (!image_exists) {
        const build_result = runRuntimeCommand(c, &.{
            "docker",
            "build",
            "-t",
            image_name,
            runtime_context,
        });

        try insertRuntimeCommandLog(
            c,
            workspace_id,
            "build-image",
            "docker build -t zivyar-opencode-runtime:latest <runtime-context>",
            build_result,
        );

        if (!build_result.ok) {
            try db.query(
                void,
                c.arena,
                \\UPDATE workspace_runtimes
                \\SET state = 'error',
                \\    status_message = 'Falha ao construir a imagem do runtime Zivyar.',
                \\    updated_at = NOW()
                \\WHERE workspace_id = $1
                ,
                .{ workspace_id },
            );


            try insertRuntimeEvent(
                c,
                workspace_id,
                "error",
                "Falha ao construir imagem",
                "O Docker não conseguiu construir a imagem zivyar-opencode-runtime:latest.",
            );

            const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{ workspace_id });
            return c.redirect(redirect_url);
        }
    }

    const container_exists = commandSucceeded(c, &.{
        "docker",
        "container",
        "inspect",
        runtime.container_name,
    });

    var container_result = RuntimeCommandResult{
        .ok = false,
        .exit_code = -1,
        .stdout = "",
        .stderr = "",
    };

    if (container_exists) {
        container_result = runRuntimeCommand(c, &.{
            "docker",
            "start",
            runtime.container_name,
        });

        try insertRuntimeCommandLog(
            c,
            workspace_id,
            "start-container",
            "docker start <workspace-container>",
            container_result,
        );
    } else {
        container_result = runRuntimeCommand(c, &.{
            "docker",
            "run",
            "-d",
            "--name",
            runtime.container_name,
            "-p",
            published_port,
            "-e",
            "OPENCODE_HOST=0.0.0.0",
            "-e",
            "OPENCODE_PORT=4096",
            "-v",
            volume_mount,
            "-w",
            "/workspace",
            image_name,
        });

        try insertRuntimeCommandLog(
            c,
            workspace_id,
            "create-container",
            "docker run -d --name <workspace-container> -p <host>:<container> -v <workspace>:/workspace",
            container_result,
        );
    }

    if (!container_result.ok) {
        try db.query(
            void,
            c.arena,
            \\UPDATE workspace_runtimes
            \\SET state = 'error',
            \\    status_message = 'Falha ao criar ou iniciar o container do runtime.',
            \\    updated_at = NOW()
            \\WHERE workspace_id = $1
            ,
            .{ workspace_id },
        );


        try insertRuntimeEvent(
            c,
            workspace_id,
            "error",
            "Falha ao iniciar container",
            "O Docker não conseguiu criar ou iniciar o container associado a este workspace.",
        );

        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{ workspace_id });
        return c.redirect(redirect_url);
    }

    const healthy = waitForOpenCodeHealth(c, server_url);

    if (!healthy) {
        try insertRuntimeCommandLog(
            c,
            workspace_id,
            "healthcheck",
            "curl -fsS <server-url>/global/health",
            .{
                .ok = false,
                .exit_code = -1,
                .stdout = "",
                .stderr = "O OpenCode Server não respondeu ao healthcheck dentro da janela esperada.",
            },
        );

        try db.query(
            void,
            c.arena,
            \\UPDATE workspace_runtimes
            \\SET state = 'error',
            \\    opencode_port = $1,
            \\    server_url = $2,
            \\    status_message = 'Container iniciou, mas o healthcheck do OpenCode não respondeu.',
            \\    updated_at = NOW()
            \\WHERE workspace_id = $3
            ,
            .{ host_port, server_url, workspace_id },
        );


        try insertRuntimeEvent(
            c,
            workspace_id,
            "error",
            "Healthcheck indisponível",
            "O container iniciou, porém o endpoint de saúde do OpenCode não respondeu dentro da janela esperada.",
        );

        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{ workspace_id });
        return c.redirect(redirect_url);
    }

    try db.query(
        void,
        c.arena,
        \\UPDATE workspace_runtimes
        \\SET state = 'running',
        \\    opencode_port = $1,
        \\    server_url = $2,
        \\    status_message = 'OpenCode Server em execução e validado com sucesso.',
        \\    updated_at = NOW()
        \\WHERE workspace_id = $3
        ,
        .{ host_port, server_url, workspace_id },
    );


    try insertRuntimeEvent(
        c,
        workspace_id,
        "running",
        "Runtime em execução",
        "O container foi iniciado e o OpenCode Server respondeu ao healthcheck com sucesso.",
    );

    _ = host_port_text;
    _ = internal_port_text;

    const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{ workspace_id });
    return c.redirect(redirect_url);
}

fn workspaceRuntimeStop(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const runtime_rows = try db.query(
        WorkspaceRuntimeControlRow,
        c.arena,
        \\SELECT
        \\    w.id AS workspace_id,
        \\    w.local_path,
        \\    r.container_name,
        \\    r.state
        \\FROM workspaces w
        \\INNER JOIN workspace_runtimes r ON r.workspace_id = w.id
        \\WHERE w.id = $1
        \\LIMIT 1
        ,
        .{ workspace_id },
    );

    if (runtime_rows.len == 0) {
        return c.text("Runtime não encontrado.", .{ .status = .not_found });
    }

    const runtime = runtime_rows[0];

    const stop_result = runRuntimeCommand(c, &.{
        "docker",
        "stop",
        runtime.container_name,
    });

    try insertRuntimeCommandLog(
        c,
        workspace_id,
        "stop-container",
        "docker stop <workspace-container>",
        stop_result,
    );

    if (!stop_result.ok) {
        try db.query(
            void,
            c.arena,
            \\UPDATE workspace_runtimes
            \\SET state = 'error',
            \\    status_message = 'Falha ao parar o container do runtime.',
            \\    updated_at = NOW()
            \\WHERE workspace_id = $1
            ,
            .{ workspace_id },
        );


        try insertRuntimeEvent(
            c,
            workspace_id,
            "error",
            "Falha ao parar runtime",
            "O Docker não confirmou a parada do container deste workspace.",
        );
    } else {
        try db.query(
            void,
            c.arena,
            \\UPDATE workspace_runtimes
            \\SET state = 'stopped',
            \\    status_message = 'Runtime parado pelo usuário.',
            \\    updated_at = NOW()
            \\WHERE workspace_id = $1
            ,
            .{ workspace_id },
        );


        try insertRuntimeEvent(
            c,
            workspace_id,
            "stopped",
            "Runtime parado",
            "O usuário interrompeu o OpenCode Server deste workspace.",
        );
    }

    const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{ workspace_id });
    return c.redirect(redirect_url);
}

fn workspaceRuntimePrepare(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const workspace_rows = try db.query(
        WorkspaceIdRow,
        c.arena,
        \\SELECT id
        \\FROM workspaces
        \\WHERE id = $1
        \\LIMIT 1
        ,
        .{ workspace_id },
    );

    if (workspace_rows.len == 0) {
        return c.text("Workspace não encontrado.", .{ .status = .not_found });
    }

    const container_name = try std.fmt.allocPrint(
        c.arena,
        "zivyar_workspace_{d}",
        .{ workspace_id },
    );

    try db.query(
        void,
        c.arena,
        \\INSERT INTO workspace_runtimes (
        \\    workspace_id,
        \\    state,
        \\    container_name,
        \\    opencode_port,
        \\    server_url,
        \\    status_message
        \\)
        \\VALUES ($1, 'stopped', $2, 0, '', 'Runtime preparado, aguardando inicialização.')
        \\ON CONFLICT (workspace_id)
        \\DO UPDATE SET
        \\    state = 'stopped',
        \\    container_name = EXCLUDED.container_name,
        \\    status_message = 'Runtime preparado, aguardando inicialização.',
        \\    updated_at = NOW()
        ,
        .{ workspace_id, container_name },
    );

    try insertRuntimeEvent(
        c,
        workspace_id,
        "prepared",
        "Runtime preparado",
        "O workspace foi registrado no Runtime Manager e está pronto para iniciar o OpenCode Server.",
    );

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/workspaces/{d}",
        .{ workspace_id },
    );

    return c.redirect(redirect_url);
}


fn workspaceConfirmLocalPathChange(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const form = try c.parseForm(WorkspaceLocalPathConfirmForm);
    const squads_rows = try loadWorkspaceSquads(c);
    const default_squad_id = std.fmt.parseInt(i32, form.default_squad_id, 10) catch 0;

    if (!std.mem.eql(u8, form.confirm_local_path_change, "yes")) {
        return c.text(
            "Confirmação explícita obrigatória para alterar o caminho local do workspace.",
            .{ .status = .bad_request },
        );
    }

    const current_rows = try db.query(
        WorkspaceRow,
        c.arena,
        \\SELECT
        \\    w.id,
        \\    w.name,
        \\    w.local_path,
        \\    w.stack_name,
        \\    w.default_squad_id,
        \\    COALESCE(s.name, 'Sem squad vinculada') AS squad_name,
        \\    w.status
        \\FROM workspaces w
        \\LEFT JOIN squads s ON s.id = w.default_squad_id
        \\WHERE w.id = $1
        \\LIMIT 1
        ,
        .{ workspace_id },
    );

    if (current_rows.len == 0) {
        return c.text("Workspace não encontrado.", .{ .status = .not_found });
    }

    const current_workspace = current_rows[0];

    const duplicated = try db.query(
        WorkspaceIdRow,
        c.arena,
        \\SELECT id
        \\FROM workspaces
        \\WHERE local_path = $1
        \\AND id <> $2
        \\LIMIT 1
        ,
        .{ form.local_path, workspace_id },
    );

    if (duplicated.len > 0) {
        return c.view("workspaces/edit", .{
            .title = "Editar Workspace",
            .workspace = current_workspace,
            .squads = squads_rows,
            .squad_count = squads_rows.len,
            .error_message = "Outro workspace já utiliza este caminho local.",
            .path_change_confirmation_required = true,
            .pending_name = form.name,
            .pending_local_path = form.local_path,
            .pending_stack_name = form.stack_name,
            .pending_default_squad_id = form.default_squad_id,
        }, .{ .status = .bad_request });
    }

    if (default_squad_id <= 0) {
        return c.view("workspaces/edit", .{
            .title = "Editar Workspace",
            .workspace = current_workspace,
            .squads = squads_rows,
            .squad_count = squads_rows.len,
            .error_message = "Selecione uma squad padrão válida.",
            .path_change_confirmation_required = true,
            .pending_name = form.name,
            .pending_local_path = form.local_path,
            .pending_stack_name = form.stack_name,
            .pending_default_squad_id = form.default_squad_id,
        }, .{ .status = .bad_request });
    }

    const selected_squad_rows = try db.query(
        WorkspaceSquadOptionRow,
        c.arena,
        \\SELECT id, name, slug
        \\FROM squads
        \\WHERE id = $1
        \\AND is_active = TRUE
        \\LIMIT 1
        ,
        .{ default_squad_id },
    );

    if (selected_squad_rows.len == 0) {
        return c.view("workspaces/edit", .{
            .title = "Editar Workspace",
            .workspace = current_workspace,
            .squads = squads_rows,
            .squad_count = squads_rows.len,
            .error_message = "A squad selecionada não está disponível.",
            .path_change_confirmation_required = true,
            .pending_name = form.name,
            .pending_local_path = form.local_path,
            .pending_stack_name = form.stack_name,
            .pending_default_squad_id = form.default_squad_id,
        }, .{ .status = .bad_request });
    }

    if (!ensureWorkspaceLocalPath(c, form.local_path)) {
        return c.view("workspaces/edit", .{
            .title = "Editar Workspace",
            .workspace = current_workspace,
            .squads = squads_rows,
            .squad_count = squads_rows.len,
            .error_message = "Não foi possível criar ou acessar o caminho local confirmado para o workspace.",
            .path_change_confirmation_required = true,
            .pending_name = form.name,
            .pending_local_path = form.local_path,
            .pending_stack_name = form.stack_name,
            .pending_default_squad_id = form.default_squad_id,
        }, .{ .status = .bad_request });
    }

    const runtime_rows = try db.query(
        WorkspaceRuntimeControlRow,
        c.arena,
        \\SELECT
        \\    w.id AS workspace_id,
        \\    w.local_path,
        \\    r.container_name,
        \\    r.state
        \\FROM workspaces w
        \\INNER JOIN workspace_runtimes r ON r.workspace_id = w.id
        \\WHERE w.id = $1
        \\LIMIT 1
        ,
        .{ workspace_id },
    );

    if (runtime_rows.len > 0) {
        const runtime = runtime_rows[0];

        const container_exists = commandSucceeded(c, &.{
            "docker",
            "container",
            "inspect",
            runtime.container_name,
        });

        if (container_exists) {
            const remove_result = runRuntimeCommand(c, &.{
                "docker",
                "rm",
                "-f",
                runtime.container_name,
            });

            try insertRuntimeCommandLog(
                c,
                workspace_id,
                "remove-container-after-local-path-change",
                "docker rm -f <workspace-container>",
                remove_result,
            );

            if (!remove_result.ok) {
                return c.view("workspaces/edit", .{
                    .title = "Editar Workspace",
                    .workspace = current_workspace,
                    .squads = squads_rows,
                    .squad_count = squads_rows.len,
                    .error_message = "Não foi possível remover com segurança o container atual. A alteração do caminho foi cancelada.",
                    .path_change_confirmation_required = true,
                    .pending_name = form.name,
                    .pending_local_path = form.local_path,
                    .pending_stack_name = form.stack_name,
                    .pending_default_squad_id = form.default_squad_id,
                }, .{ .status = .bad_request });
            }
        }
    }

    try db.query(
        void,
        c.arena,
        \\UPDATE workspaces
        \\SET name = $1,
        \\    local_path = $2,
        \\    stack_name = $3,
        \\    default_squad = $4,
        \\    default_squad_id = $5
        \\WHERE id = $6
        ,
        .{
            form.name,
            form.local_path,
            form.stack_name,
            selected_squad_rows[0].name,
            default_squad_id,
            workspace_id,
        },
    );

    if (runtime_rows.len > 0) {
        try db.query(
            void,
            c.arena,
            \\UPDATE workspace_runtimes
            \\SET state = 'stopped',
            \\    opencode_port = 0,
            \\    server_url = '',
            \\    status_message = 'Caminho local alterado. O runtime precisa ser iniciado novamente para montar a nova pasta.',
            \\    updated_at = NOW()
            \\WHERE workspace_id = $1
            ,
            .{ workspace_id },
        );

        try db.query(
            void,
            c.arena,
            \\UPDATE workspace_panes
            \\SET pane_state = CASE
            \\        WHEN session_external_id <> '' THEN 'stale'
            \\        ELSE pane_state
            \\    END,
            \\    stale_reason = CASE
            \\        WHEN session_external_id <> '' THEN 'workspace_local_path_changed'
            \\        ELSE stale_reason
            \\    END,
            \\    updated_at = NOW()
            \\WHERE workspace_id = $1
            ,
            .{ workspace_id },
        );
    }

    const path_change_message = try std.fmt.allocPrint(
        c.arena,
        "O caminho local do workspace foi alterado de {s} para {s}. O runtime anterior foi invalidado para evitar montagem incorreta.",
        .{ current_workspace.local_path, form.local_path },
    );

    try insertRuntimeEvent(
        c,
        workspace_id,
        "workspace-local-path-changed",
        "Caminho local alterado",
        path_change_message,
    );

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/workspaces/{d}",
        .{ workspace_id },
    );

    return c.redirect(redirect_url);
}

fn workspaceDelete(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    try db.query(
        void,
        c.arena,
        \\DELETE FROM workspaces
        \\WHERE id = $1
        ,
        .{ workspace_id },
    );

    return c.redirect("/workspaces?deleted=1");
}

fn workspacePaneCloseSession(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const pane_id_raw = c.params.get("pane_id") orelse
        return c.text("Pane não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const pane_id = std.fmt.parseInt(i32, pane_id_raw, 10) catch
        return c.text("Pane inválido.", .{ .status = .bad_request });

    const pane_rows = try db.query(
        WorkspacePaneControlRow,
        c.arena,
        \\SELECT id, workspace_id, role_name, agent_id, pane_state, session_external_id, session_agent_id, session_agent_handle, context_state
        \\FROM workspace_panes
        \\WHERE id = $1
        \\AND workspace_id = $2
        \\LIMIT 1
        ,
        .{ pane_id, workspace_id },
    );

    if (pane_rows.len == 0) {
        return c.text("Pane não encontrado.", .{ .status = .not_found });
    }

    const pane = pane_rows[0];

    if (!std.mem.eql(u8, pane.pane_state, "active")) {
        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{ workspace_id });
        return c.redirect(redirect_url);
    }

    try db.query(
        void,
        c.arena,
        \\UPDATE workspace_panes
        \\SET pane_state = 'closed',
        \\    updated_at = NOW()
        \\WHERE id = $1
        \\AND workspace_id = $2
        ,
        .{ pane_id, workspace_id },
    );

    const close_message = try std.fmt.allocPrint(
        c.arena,
        "O pane {s} foi encerrado no Cockpit. A sessão {s} permanece vinculada e pode ser retomada.",
        .{ pane.role_name, pane.session_external_id },
    );

    try insertRuntimeEvent(
        c,
        workspace_id,
        "pane-session-closed",
        "Pane encerrado",
        close_message,
    );

    const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{ workspace_id });
    return c.redirect(redirect_url);
}

fn workspacePaneResumeSession(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const pane_id_raw = c.params.get("pane_id") orelse
        return c.text("Pane não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const pane_id = std.fmt.parseInt(i32, pane_id_raw, 10) catch
        return c.text("Pane inválido.", .{ .status = .bad_request });

    const pane_rows = try db.query(
        WorkspacePaneControlRow,
        c.arena,
        \\SELECT id, workspace_id, role_name, agent_id, pane_state, session_external_id, session_agent_id, session_agent_handle, context_state
        \\FROM workspace_panes
        \\WHERE id = $1
        \\AND workspace_id = $2
        \\LIMIT 1
        ,
        .{ pane_id, workspace_id },
    );

    if (pane_rows.len == 0) {
        return c.text("Pane não encontrado.", .{ .status = .not_found });
    }

    const pane = pane_rows[0];

    if (!std.mem.eql(u8, pane.pane_state, "closed") or pane.session_external_id.len == 0) {
        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{ workspace_id });
        return c.redirect(redirect_url);
    }

    const runtime_rows = try loadWorkspaceRuntime(c, workspace_id);

    if (runtime_rows.len == 0) {
        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{ workspace_id });
        return c.redirect(redirect_url);
    }

    try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try loadWorkspaceRuntime(c, workspace_id);

    if (refreshed_runtime_rows.len == 0) {
        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{ workspace_id });
        return c.redirect(redirect_url);
    }

    const runtime = refreshed_runtime_rows[0];

    if (!std.mem.eql(u8, runtime.state, "running")) {
        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{ workspace_id });
        return c.redirect(redirect_url);
    }

    const validate_result = openCodeSessionExists(
        c,
        runtime.server_url_label,
        pane.session_external_id,
    );

    try insertRuntimeCommandLog(
        c,
        workspace_id,
        "opencode-resume-session",
        "GET <opencode-server>/session/<session-id>",
        validate_result,
    );

    if (!validate_result.ok) {
        try db.query(
            void,
            c.arena,
            \\UPDATE workspace_panes
            \\SET pane_state = 'stale',
            \\    updated_at = NOW()
            \\WHERE id = $1
            \\AND workspace_id = $2
            ,
            .{ pane_id, workspace_id },
        );

        const stale_message = try std.fmt.allocPrint(
            c.arena,
            "A sessão {s} do pane {s} não existe mais no OpenCode Server.",
            .{ pane.session_external_id, pane.role_name },
        );

        try insertRuntimeEvent(
            c,
            workspace_id,
            "pane-session-stale",
            "Sessão não pode ser retomada",
            stale_message,
        );

        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{ workspace_id });
        return c.redirect(redirect_url);
    }

    try db.query(
        void,
        c.arena,
        \\UPDATE workspace_panes
        \\SET pane_state = 'active',
        \\    updated_at = NOW()
        \\WHERE id = $1
        \\AND workspace_id = $2
        ,
        .{ pane_id, workspace_id },
    );

    const resume_message = try std.fmt.allocPrint(
        c.arena,
        "O pane {s} retomou a sessão {s}.",
        .{ pane.role_name, pane.session_external_id },
    );

    try insertRuntimeEvent(
        c,
        workspace_id,
        "pane-session-resumed",
        "Sessão retomada",
        resume_message,
    );

    const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{ workspace_id });
    return c.redirect(redirect_url);
}


fn workspacePaneRecreateSession(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const pane_id_raw = c.params.get("pane_id") orelse
        return c.text("Pane não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const pane_id = std.fmt.parseInt(i32, pane_id_raw, 10) catch
        return c.text("Pane inválido.", .{ .status = .bad_request });

    const pane_rows = try db.query(
        WorkspacePaneControlRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    workspace_id,
        \\    role_name,
        \\    pane_state,
        \\    session_external_id,
        \\    context_state
        \\FROM workspace_panes
        \\WHERE id = $1
        \\AND workspace_id = $2
        \\LIMIT 1
        ,
        .{ pane_id, workspace_id },
    );

    if (pane_rows.len == 0) {
        return c.text("Pane não encontrado.", .{ .status = .not_found });
    }

    const pane = pane_rows[0];

    if (pane.session_external_id.len == 0) {
        return c.text("Este pane ainda não possui sessão para recriar.", .{ .status = .bad_request });
    }

    if (!std.mem.eql(u8, pane.pane_state, "active") and !std.mem.eql(u8, pane.pane_state, "closed")) {
        return c.text("A sessão deste pane não está em estado recriável.", .{ .status = .bad_request });
    }

    try db.query(
        void,
        c.arena,
        \\UPDATE workspace_panes
        \\SET context_state = 'outdated',
        \\    updated_at = NOW()
        \\WHERE id = $1
        \\AND workspace_id = $2
        ,
        .{ pane_id, workspace_id },
    );

    return workspacePaneOpenSession(c);
}

fn workspacePaneOpenSession(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const pane_id_raw = c.params.get("pane_id") orelse
        return c.text("Pane não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const pane_id = std.fmt.parseInt(i32, pane_id_raw, 10) catch
        return c.text("Pane inválido.", .{ .status = .bad_request });

    const pane_rows = try db.query(
        WorkspacePaneControlRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    workspace_id,
        \\    role_name,
        \\    agent_id,
        \\    pane_state,
        \\    session_external_id,
        \\    session_agent_id,
        \\    session_agent_handle,
        \\    context_state,
        \\    stale_reason
        \\FROM workspace_panes
        \\WHERE id = $1
        \\AND workspace_id = $2
        \\LIMIT 1
        ,
        .{ pane_id, workspace_id },
    );

    if (pane_rows.len == 0) {
        return c.text("Pane não encontrado.", .{ .status = .not_found });
    }

    const pane = pane_rows[0];
    const is_recreating_stale_session = std.mem.eql(u8, pane.pane_state, "stale");
    const is_recreating_outdated_context = std.mem.eql(u8, pane.context_state, "outdated");

    if (
        pane.session_external_id.len > 0 and
        !is_recreating_stale_session and
        !is_recreating_outdated_context
    ) {
        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{ workspace_id });
        return c.redirect(redirect_url);
    }

    const runtime_rows = try loadWorkspaceRuntime(c, workspace_id);

    if (runtime_rows.len == 0) {
        try insertRuntimeEvent(
            c,
            workspace_id,
            "pane-session-error",
            "Sessão não criada",
            "O runtime deste workspace ainda não foi preparado.",
        );

        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{ workspace_id });
        return c.redirect(redirect_url);
    }

    try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try loadWorkspaceRuntime(c, workspace_id);

    if (refreshed_runtime_rows.len == 0) {
        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{ workspace_id });
        return c.redirect(redirect_url);
    }

    const runtime = refreshed_runtime_rows[0];

    if (!std.mem.eql(u8, runtime.state, "running")) {
        try insertRuntimeEvent(
            c,
            workspace_id,
            "pane-session-error",
            "Sessão não criada",
            "O Runtime precisa estar em execução para abrir uma sessão de pane.",
        );

        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{ workspace_id });
        return c.redirect(redirect_url);
    }

    const session_title = try std.fmt.allocPrint(
        c.arena,
        "Zivyar Pane · Workspace {d} · {s}",
        .{ workspace_id, pane.role_name },
    );

    const request_body = try std.json.Stringify.valueAlloc(
        c.arena,
        .{ .title = session_title },
        .{},
    );

    const session_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session",
        .{ runtime.server_url_label },
    );

    const create_session_result = runRuntimeCommand(c, &.{
        "curl",
        "-sS",
        "-X",
        "POST",
        session_url,
        "-H",
        "Content-Type: application/json",
        "-d",
        request_body,
    });

    try insertRuntimeCommandLog(
        c,
        workspace_id,
        "opencode-create-session",
        "POST <opencode-server>/session",
        create_session_result,
    );

    if (!create_session_result.ok) {
        try insertRuntimeEvent(
            c,
            workspace_id,
            "pane-session-error",
            "Falha ao criar sessão",
            "A chamada ao OpenCode Server não concluiu com sucesso.",
        );

        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{ workspace_id });
        return c.redirect(redirect_url);
    }

    const session_id = extractOpenCodeSessionId(create_session_result.stdout) orelse {
        try insertRuntimeEvent(
            c,
            workspace_id,
            "pane-session-error",
            "Resposta inválida do OpenCode",
            "O OpenCode respondeu, mas o Zivyar não encontrou o identificador da sessão.",
        );

        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{ workspace_id });
        return c.redirect(redirect_url);
    };

    const bootstrap_rows = try db.query(
        WorkspacePaneBootstrapRow,
        c.arena,
        \\SELECT
        \\    wp.id AS pane_id,
        \\    wp.workspace_id,
        \\    wp.role_name,
        \\    w.name AS workspace_name,
        \\    w.local_path,
        \\    a.name AS agent_name,
        \\    a.handle AS agent_handle,
        \\    a.agent_role,
        \\    a.summary AS agent_summary,
        \\    a.system_prompt,
        \\    a.operating_rules,
        \\    s.name AS stack_name,
        \\    s.runtime_tool,
        \\    pm.model_name
        \\FROM workspace_panes wp
        \\INNER JOIN workspaces w ON w.id = wp.workspace_id
        \\INNER JOIN agents a ON a.id = wp.agent_id
        \\INNER JOIN stacks s ON s.id = a.default_stack_id
        \\INNER JOIN provider_models pm ON pm.id = s.provider_model_id
        \\WHERE wp.id = $1
        \\AND wp.workspace_id = $2
        \\LIMIT 1
        ,
        .{ pane_id, workspace_id },
    );

    if (bootstrap_rows.len > 0) {
        const bootstrap = bootstrap_rows[0];

        const bootstrap_prompt = try std.fmt.allocPrint(
            c.arena,
            "Zivyar Cockpit — Contexto inicial do pane\n\n" ++
                "Workspace: {s}\n" ++
                "Caminho local: {s}\n" ++
                "Papel do pane: {s}\n\n" ++
                "Agente: {s}\n" ++
                "Handle: {s}\n" ++
                "Função: {s}\n\n" ++
                "Stack: {s}\n" ++
                "Runtime Tool: {s}\n" ++
                "Modelo associado: {s}\n\n" ++
                "Resumo do agente:\n{s}\n\n" ++
                "System prompt cadastrado no Zivyar:\n{s}\n\n" ++
                "Regras operacionais:\n{s}\n\n" ++
                "Diretriz de bootstrap:\n" ++
                "Considere este contexto como a configuração inicial deste pane dentro do Zivyar Cockpit. " ++
                "Aguarde a primeira missão ou instrução direta do usuário antes de executar ações.",
            .{
                bootstrap.workspace_name,
                bootstrap.local_path,
                bootstrap.role_name,
                bootstrap.agent_name,
                bootstrap.agent_handle,
                bootstrap.agent_role,
                bootstrap.stack_name,
                bootstrap.runtime_tool,
                bootstrap.model_name,
                bootstrap.agent_summary,
                bootstrap.system_prompt,
                bootstrap.operating_rules,
            },
        );

        const bootstrap_parts = [_]OpenCodeTextPart{
            .{
                .type = "text",
                .text = bootstrap_prompt,
            },
        };

        const bootstrap_body = try std.json.Stringify.valueAlloc(
            c.arena,
            OpenCodeBootstrapMessageRequest{
                .noReply = true,
                .parts = bootstrap_parts[0..],
            },
            .{},
        );

        const bootstrap_url = try std.fmt.allocPrint(
            c.arena,
            "{s}/session/{s}/message",
            .{ runtime.server_url_label, session_id },
        );

        const bootstrap_result = runRuntimeCommand(c, &.{
            "curl",
            "-fsS",
            "-X",
            "POST",
            bootstrap_url,
            "-H",
            "Content-Type: application/json",
            "-d",
            bootstrap_body,
        });

        try insertRuntimeCommandLog(
            c,
            workspace_id,
            "opencode-bootstrap-session",
            "POST <opencode-server>/session/<session-id>/message",
            bootstrap_result,
        );

        if (bootstrap_result.ok) {
            const bootstrap_event_message = try std.fmt.allocPrint(
                c.arena,
                "O contexto inicial do agente {s} foi injetado na sessão {s}.",
                .{ bootstrap.agent_name, session_id },
            );

            try insertRuntimeEvent(
                c,
                workspace_id,
                "pane-session-bootstrapped",
                "Contexto inicial do pane injetado",
                bootstrap_event_message,
            );
        } else {
            const bootstrap_warning_message = try std.fmt.allocPrint(
                c.arena,
                "A sessão {s} foi criada, mas o contexto inicial do pane {s} não pôde ser injetado automaticamente.",
                .{ session_id, bootstrap.role_name },
            );

            try insertRuntimeEvent(
                c,
                workspace_id,
                "pane-session-bootstrap-warning",
                "Sessão criada sem contexto inicial",
                bootstrap_warning_message,
            );
        }
    }

    const session_agent_handle =
        if (bootstrap_rows.len > 0)
            bootstrap_rows[0].agent_handle
        else
            "";

    if (
        pane.session_external_id.len > 0 and
        (is_recreating_stale_session or is_recreating_outdated_context)
    ) {
        const replacement_reason =
            if (is_recreating_stale_session)
                "stale_recovery"
            else
                "context_outdated";

        try db.query(
            void,
            c.arena,
            \\INSERT INTO workspace_pane_session_history (
            \\    workspace_id,
            \\    pane_id,
            \\    role_name,
            \\    previous_session_external_id,
            \\    previous_session_agent_id,
            \\    previous_session_agent_handle,
            \\    previous_context_state,
            \\    replacement_session_external_id,
            \\    replacement_session_agent_id,
            \\    replacement_session_agent_handle,
            \\    replacement_reason
            \\)
            \\VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            ,
            .{
                workspace_id,
                pane_id,
                pane.role_name,
                pane.session_external_id,
                pane.session_agent_id,
                pane.session_agent_handle,
                pane.context_state,
                session_id,
                pane.agent_id,
                session_agent_handle,
                replacement_reason,
            },
        );
    }

    try db.query(
        void,
        c.arena,
        \\UPDATE workspace_panes
        \\SET pane_state = 'active',
        \\    session_external_id = $1,
        \\    session_agent_id = $2,
        \\    session_agent_handle = $3,
        \\    context_state = 'current',
        \\    stale_reason = '',
        \\    updated_at = NOW()
        \\WHERE id = $4
        \\AND workspace_id = $5
        ,
        .{ session_id, pane.agent_id, session_agent_handle, pane_id, workspace_id },
    );

    const event_message =
        if (is_recreating_stale_session)
            try std.fmt.allocPrint(
                c.arena,
                "A sessão antiga do pane {s} estava indisponível. O Zivyar criou a nova sessão {s} no OpenCode Server.",
                .{ pane.role_name, session_id },
            )
        else if (is_recreating_outdated_context)
            try std.fmt.allocPrint(
                c.arena,
                "A sessão do pane {s} foi recriada com o contexto atual do agente vinculado. Nova sessão: {s}.",
                .{ pane.role_name, session_id },
            )
        else
            try std.fmt.allocPrint(
                c.arena,
                "A sessão {s} foi criada no OpenCode Server para o pane {s}.",
                .{ session_id, pane.role_name },
            );

    try insertRuntimeEvent(
        c,
        workspace_id,
        if (is_recreating_stale_session)
            "pane-session-recreated"
        else if (is_recreating_outdated_context)
            "pane-session-context-refreshed"
        else
            "pane-session-opened",
        if (is_recreating_stale_session)
            "Sessão de pane recriada"
        else if (is_recreating_outdated_context)
            "Sessão recriada com contexto atual"
        else
            "Sessão de pane criada",
        event_message,
    );

    const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{ workspace_id });
    return c.redirect(redirect_url);
}


fn workspaceMissionActivate(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const mission_id_raw = c.params.get("mission_id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, mission_id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const mission_rows = try db.query(
        MissionActivationTargetRow,
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

    if (mission_rows.len == 0) {
        return c.text("Missão não encontrada neste workspace.", .{ .status = .not_found });
    }

    if (std.mem.eql(u8, mission_rows[0].mission_operational_closure_status, "closed")) {
        return c.text(
            "Missões encerradas operacionalmente não podem ser reativadas no Cockpit.",
            .{ .status = .bad_request },
        );
    }

    try db.query(
        void,
        c.arena,
        \\UPDATE workspaces
        \\SET active_mission_id = $1
        \\WHERE id = $2
        ,
        .{ mission_id, workspace_id },
    );

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
        \\    'mission-activated-in-cockpit',
        \\    'Missão ativada no Cockpit',
        \\    'Esta missão foi definida como foco operacional ativo do workspace.'
        \\)
        ,
        .{ mission_id, workspace_id },
    );

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/workspaces/{d}",
        .{ workspace_id },
    );

    return c.redirect(redirect_url);
}


fn workspaceMissionDispatchToPilot(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const mission_id_raw = c.params.get("mission_id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, mission_id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const active_mission_rows = try db.query(
        MissionRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.workspace_id,
        \\    w.name AS workspace_name,
        \\    m.squad_id,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name,
        \\    m.title,
        \\    m.objective,
        \\    m.status,
        \\    m.priority,
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
        \\    ) AS mission_operational_closed_at_label
        \\FROM workspaces w
        \\INNER JOIN missions m ON m.id = w.active_mission_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\WHERE w.id = $1
        \\AND m.id = $2
        \\LIMIT 1
        ,
        .{ workspace_id, mission_id },
    );

    if (active_mission_rows.len == 0) {
        return c.text(
            "Esta missão não é a missão ativa deste workspace.",
            .{ .status = .bad_request },
        );
    }

    const mission = active_mission_rows[0];

    if (std.mem.eql(u8, mission.mission_operational_closure_status, "closed")) {
        return c.text(
            "Missões encerradas operacionalmente não podem executar novas ações do ciclo operacional.",
            .{ .status = .bad_request },
        );
    }

    const pilot_rows = try db.query(
        WorkspaceMissionPaneDispatchRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    role_name,
        \\    pane_state,
        \\    session_external_id,
        \\    context_state
        \\FROM workspace_panes
        \\WHERE workspace_id = $1
        \\AND role_name = 'Piloto'
        \\LIMIT 1
        ,
        .{ workspace_id },
    );

    if (pilot_rows.len == 0) {
        return c.text(
            "O pane Piloto ainda não foi materializado neste workspace.",
            .{ .status = .bad_request },
        );
    }

    const pilot = pilot_rows[0];

    if (!std.mem.eql(u8, pilot.pane_state, "active")) {
        return c.text(
            "O pane Piloto precisa estar ativo para receber a missão.",
            .{ .status = .bad_request },
        );
    }

    if (!std.mem.eql(u8, pilot.context_state, "current")) {
        return c.text(
            "O contexto do pane Piloto está desatualizado. Recrie a sessão antes de enviar a missão.",
            .{ .status = .bad_request },
        );
    }

    if (pilot.session_external_id.len == 0) {
        return c.text(
            "O pane Piloto não possui sessão OpenCode vinculada.",
            .{ .status = .bad_request },
        );
    }

    const runtime_rows = try loadWorkspaceRuntime(c, workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "O runtime deste workspace ainda não foi preparado.",
            .{ .status = .bad_request },
        );
    }

    try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try loadWorkspaceRuntime(c, workspace_id);

    if (refreshed_runtime_rows.len == 0) {
        return c.text(
            "Runtime não encontrado após reconciliação.",
            .{ .status = .bad_request },
        );
    }

    const runtime = refreshed_runtime_rows[0];

    if (!std.mem.eql(u8, runtime.state, "running")) {
        return c.text(
            "O runtime precisa estar em execução para enviar a missão ao Piloto.",
            .{ .status = .bad_request },
        );
    }

    const mission_prompt = try std.fmt.allocPrint(
        c.arena,
        "Zivyar Cockpit — Missão ativa enviada ao Piloto\n\n" ++
            "Workspace: {s}\n" ++
            "Squad: {s}\n\n" ++
            "Título da missão:\n{s}\n\n" ++
            "Objetivo:\n{s}\n\n" ++
            "Status atual: {s}\n" ++
            "Prioridade: {s}\n\n" ++
            "Diretriz operacional:\n" ++
            "Interprete esta missão como o foco ativo do Cockpit. " ++
            "Inicie pela leitura crítica do objetivo e produza um Briefing Operacional inicial: " ++
            "1) entendimento da missão, 2) escopo inicial, 3) dúvidas ou riscos percebidos, " ++
            "4) sugestão da próxima delegação para Planner e/ou Scout. " ++
            "Não implemente código diretamente neste primeiro retorno.",
        .{
            mission.workspace_name,
            mission.squad_name,
            mission.title,
            mission.objective,
            mission.status,
            mission.priority,
        },
    );

    const prompt_parts = [_]OpenCodeTextPart{
        .{
            .type = "text",
            .text = mission_prompt,
        },
    };

    const prompt_body = try std.json.Stringify.valueAlloc(
        c.arena,
        OpenCodePromptAsyncRequest{
            .parts = prompt_parts[0..],
        },
        .{},
    );

    const prompt_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/prompt_async",
        .{ runtime.server_url_label, pilot.session_external_id },
    );

    const dispatch_result = runRuntimeCommand(c, &.{
        "curl",
        "-fsS",
        "-X",
        "POST",
        prompt_url,
        "-H",
        "Content-Type: application/json",
        "-d",
        prompt_body,
    });

    try insertRuntimeCommandLog(
        c,
        workspace_id,
        "opencode-dispatch-active-mission-to-pilot",
        "POST <opencode-server>/session/<session-id>/prompt_async",
        dispatch_result,
    );

    if (!dispatch_result.ok) {
        try db.query(
            void,
            c.arena,
            \\UPDATE missions
            \\SET pilot_dispatch_status = 'error'
            \\WHERE id = $1
            ,
            .{ mission_id },
        );

        try insertRuntimeEvent(
            c,
            workspace_id,
            "mission-dispatch-error",
            "Falha ao enviar missão ao Piloto",
            "O OpenCode Server não confirmou o envio assíncrono da missão ativa.",
        );

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
            \\    'mission-dispatch-to-pilot-error',
            \\    'Falha ao enviar missão ao Piloto',
            \\    'O despacho assíncrono ao pane Piloto não foi confirmado pelo OpenCode Server.'
            \\)
            ,
            .{ mission_id, workspace_id },
        );

        return c.text(
            "Falha ao enviar a missão ativa ao Piloto.",
            .{ .status = .bad_request },
        );
    }

    const dispatch_messages_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/message",
        .{ runtime.server_url_label, pilot.session_external_id },
    );

    var dispatch_user_message_id: []const u8 = "";
    var dispatch_trace_attempt: usize = 0;

    while (dispatch_trace_attempt < 6 and dispatch_user_message_id.len == 0) : (dispatch_trace_attempt += 1) {
        const dispatch_messages_result = runRuntimeCommand(c, &.{
            "curl",
            "-fsS",
            dispatch_messages_url,
        });

        if (dispatch_messages_result.ok) {
            if (try extractLatestUserMessageIdMatchingText(
                c.arena,
                dispatch_messages_result.stdout,
                mission_prompt,
            )) |message_id| {
                dispatch_user_message_id = message_id;
                break;
            }
        }

        std.Io.sleep(c._io, std.Io.Duration.fromMilliseconds(200), .real) catch {};
    }

    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET pilot_dispatch_status = 'sent',
        \\    pilot_session_external_id = $1,
        \\    pilot_dispatch_user_message_id = $2,
        \\    dispatched_to_pilot_at = NOW(),
        \\    pilot_operational_brief = '',
        \\    pilot_operational_brief_status = 'pending_capture',
        \\    pilot_operational_brief_captured_at = NULL
        \\WHERE id = $3
        ,
        .{ pilot.session_external_id, dispatch_user_message_id, mission_id },
    );

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "A missão ativa \"{s}\" foi enviada ao pane Piloto na sessão {s}.",
        .{ mission.title, pilot.session_external_id },
    );

    try insertRuntimeEvent(
        c,
        workspace_id,
        "mission-dispatched-to-pilot",
        "Missão enviada ao Piloto",
        event_message,
    );

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
        \\    'mission-dispatched-to-pilot',
        \\    'Missão enviada ao Piloto',
        \\    $3
        \\)
        ,
        .{ mission_id, workspace_id, event_message },
    );

    const pilot_session_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/Lw/session/{s}",
        .{ runtime.server_url_label, pilot.session_external_id },
    );

    return c.redirect(pilot_session_url);
}


fn workspaceMissionDispatchPilotBriefToPlanner(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const mission_id_raw = c.params.get("mission_id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, mission_id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const active_mission_rows = try db.query(
        MissionRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.workspace_id,
        \\    w.name AS workspace_name,
        \\    m.squad_id,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name,
        \\    m.title,
        \\    m.objective,
        \\    m.status,
        \\    m.priority,
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
        \\    ) AS mission_operational_closed_at_label
        \\FROM workspaces w
        \\INNER JOIN missions m ON m.id = w.active_mission_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\WHERE w.id = $1
        \\AND m.id = $2
        \\LIMIT 1
        ,
        .{ workspace_id, mission_id },
    );

    if (active_mission_rows.len == 0) {
        return c.text(
            "Esta missão não é a missão ativa deste workspace.",
            .{ .status = .bad_request },
        );
    }

    const mission = active_mission_rows[0];

    if (std.mem.eql(u8, mission.mission_operational_closure_status, "closed")) {
        return c.text(
            "Missões encerradas operacionalmente não podem executar novas ações do ciclo operacional.",
            .{ .status = .bad_request },
        );
    }

    if (
        mission.pilot_operational_brief.len == 0 or
        !std.mem.eql(u8, mission.pilot_operational_brief_status, "captured")
    ) {
        return c.text(
            "Capture o Briefing Operacional do Piloto antes de enviá-lo ao Planner.",
            .{ .status = .bad_request },
        );
    }

    const planner_rows = try db.query(
        WorkspaceMissionPaneDispatchRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    role_name,
        \\    pane_state,
        \\    session_external_id,
        \\    context_state
        \\FROM workspace_panes
        \\WHERE workspace_id = $1
        \\AND role_name = 'Planner'
        \\LIMIT 1
        ,
        .{ workspace_id },
    );

    if (planner_rows.len == 0) {
        return c.text(
            "O pane Planner ainda não foi materializado neste workspace.",
            .{ .status = .bad_request },
        );
    }

    const planner = planner_rows[0];

    if (!std.mem.eql(u8, planner.pane_state, "active")) {
        return c.text(
            "O pane Planner precisa estar ativo para receber o briefing.",
            .{ .status = .bad_request },
        );
    }

    if (!std.mem.eql(u8, planner.context_state, "current")) {
        return c.text(
            "O contexto do pane Planner está desatualizado. Recrie a sessão antes de enviar o briefing.",
            .{ .status = .bad_request },
        );
    }

    if (planner.session_external_id.len == 0) {
        return c.text(
            "O pane Planner não possui sessão OpenCode vinculada.",
            .{ .status = .bad_request },
        );
    }

    const runtime_rows = try loadWorkspaceRuntime(c, workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "O runtime deste workspace ainda não foi preparado.",
            .{ .status = .bad_request },
        );
    }

    try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try loadWorkspaceRuntime(c, workspace_id);

    if (refreshed_runtime_rows.len == 0) {
        return c.text(
            "Runtime não encontrado após reconciliação.",
            .{ .status = .bad_request },
        );
    }

    const runtime = refreshed_runtime_rows[0];

    if (!std.mem.eql(u8, runtime.state, "running")) {
        return c.text(
            "O runtime precisa estar em execução para enviar o briefing ao Planner.",
            .{ .status = .bad_request },
        );
    }

    const planner_prompt = try std.fmt.allocPrint(
        c.arena,
        "Zivyar Cockpit — Briefing do Piloto enviado ao Planner\n\n" ++
            "Workspace: {s}\n" ++
            "Squad: {s}\n\n" ++
            "Missão ativa:\n{s}\n\n" ++
            "Objetivo da missão:\n{s}\n\n" ++
            "Status atual: {s}\n" ++
            "Prioridade: {s}\n\n" ++
            "Briefing Operacional do Piloto:\n{s}\n\n" ++
            "Diretriz operacional:\n" ++
            "Transforme este briefing em um Plano Operacional da missão. " ++
            "Produza: 1) leitura consolidada do problema, 2) plano de execução em fases, " ++
            "3) tarefas recomendadas, 4) dependências e riscos, 5) indicação clara do que deve seguir para Scout e/ou Builder. " ++
            "Não implemente código neste retorno.",
        .{
            mission.workspace_name,
            mission.squad_name,
            mission.title,
            mission.objective,
            mission.status,
            mission.priority,
            mission.pilot_operational_brief,
        },
    );

    const prompt_parts = [_]OpenCodeTextPart{
        .{
            .type = "text",
            .text = planner_prompt,
        },
    };

    const prompt_body = try std.json.Stringify.valueAlloc(
        c.arena,
        OpenCodePromptAsyncRequest{
            .parts = prompt_parts[0..],
        },
        .{},
    );

    const prompt_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/prompt_async",
        .{ runtime.server_url_label, planner.session_external_id },
    );

    const dispatch_result = runRuntimeCommand(c, &.{
        "curl",
        "-fsS",
        "-X",
        "POST",
        prompt_url,
        "-H",
        "Content-Type: application/json",
        "-d",
        prompt_body,
    });

    try insertRuntimeCommandLog(
        c,
        workspace_id,
        "opencode-dispatch-pilot-brief-to-planner",
        "POST <opencode-server>/session/<session-id>/prompt_async",
        dispatch_result,
    );

    if (!dispatch_result.ok) {
        try db.query(
            void,
            c.arena,
            \\UPDATE missions
            \\SET planner_dispatch_status = 'error'
            \\WHERE id = $1
            ,
            .{ mission_id },
        );

        try insertRuntimeEvent(
            c,
            workspace_id,
            "planner-dispatch-error",
            "Falha ao enviar briefing ao Planner",
            "O OpenCode Server não confirmou o envio assíncrono do briefing ao pane Planner.",
        );

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
            \\    'pilot-brief-dispatch-to-planner-error',
            \\    'Falha ao enviar briefing ao Planner',
            \\    'O despacho assíncrono do briefing ao pane Planner não foi confirmado pelo OpenCode Server.'
            \\)
            ,
            .{ mission_id, workspace_id },
        );

        return c.text(
            "Falha ao enviar o briefing do Piloto ao Planner.",
            .{ .status = .bad_request },
        );
    }

    const dispatch_messages_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/message",
        .{ runtime.server_url_label, planner.session_external_id },
    );

    var planner_dispatch_user_message_id: []const u8 = "";
    var dispatch_trace_attempt: usize = 0;

    while (dispatch_trace_attempt < 6 and planner_dispatch_user_message_id.len == 0) : (dispatch_trace_attempt += 1) {
        const dispatch_messages_result = runRuntimeCommand(c, &.{
            "curl",
            "-fsS",
            dispatch_messages_url,
        });

        if (dispatch_messages_result.ok) {
            if (try extractLatestUserMessageIdMatchingText(
                c.arena,
                dispatch_messages_result.stdout,
                planner_prompt,
            )) |message_id| {
                planner_dispatch_user_message_id = message_id;
                break;
            }
        }

        std.Io.sleep(c._io, std.Io.Duration.fromMilliseconds(200), .real) catch {};
    }

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
        .{ planner.session_external_id, planner_dispatch_user_message_id, mission_id },
    );

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Briefing Operacional do Piloto da missão \"{s}\" foi enviado ao pane Planner na sessão {s}.",
        .{ mission.title, planner.session_external_id },
    );

    try insertRuntimeEvent(
        c,
        workspace_id,
        "pilot-brief-dispatched-to-planner",
        "Briefing enviado ao Planner",
        event_message,
    );

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
        \\    'pilot-brief-dispatched-to-planner',
        \\    'Briefing enviado ao Planner',
        \\    $3
        \\)
        ,
        .{ mission_id, workspace_id, event_message },
    );

    const planner_session_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/Lw/session/{s}",
        .{ runtime.server_url_label, planner.session_external_id },
    );

    return c.redirect(planner_session_url);
}


fn workspaceMissionDispatchPlannerPlanToScout(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const mission_id_raw = c.params.get("mission_id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, mission_id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const active_mission_rows = try db.query(
        MissionRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.workspace_id,
        \\    w.name AS workspace_name,
        \\    m.squad_id,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name,
        \\    m.title,
        \\    m.objective,
        \\    m.status,
        \\    m.priority,
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
        \\    ) AS mission_operational_closed_at_label
        \\FROM workspaces w
        \\INNER JOIN missions m ON m.id = w.active_mission_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\WHERE w.id = $1
        \\AND m.id = $2
        \\LIMIT 1
        ,
        .{ workspace_id, mission_id },
    );

    if (active_mission_rows.len == 0) {
        return c.text(
            "Esta missão não é a missão ativa deste workspace.",
            .{ .status = .bad_request },
        );
    }

    const mission = active_mission_rows[0];

    if (std.mem.eql(u8, mission.mission_operational_closure_status, "closed")) {
        return c.text(
            "Missões encerradas operacionalmente não podem executar novas ações do ciclo operacional.",
            .{ .status = .bad_request },
        );
    }

    if (
        mission.planner_operational_plan.len == 0 or
        !std.mem.eql(u8, mission.planner_operational_plan_status, "captured")
    ) {
        return c.text(
            "Capture o Plano Operacional do Planner antes de enviá-lo ao Scout.",
            .{ .status = .bad_request },
        );
    }

    const scout_rows = try db.query(
        WorkspaceMissionPaneDispatchRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    role_name,
        \\    pane_state,
        \\    session_external_id,
        \\    context_state
        \\FROM workspace_panes
        \\WHERE workspace_id = $1
        \\AND role_name = 'Scout'
        \\LIMIT 1
        ,
        .{ workspace_id },
    );

    if (scout_rows.len == 0) {
        return c.text(
            "O pane Scout ainda não foi materializado neste workspace.",
            .{ .status = .bad_request },
        );
    }

    const scout = scout_rows[0];

    if (!std.mem.eql(u8, scout.pane_state, "active")) {
        return c.text(
            "O pane Scout precisa estar ativo para receber o plano.",
            .{ .status = .bad_request },
        );
    }

    if (!std.mem.eql(u8, scout.context_state, "current")) {
        return c.text(
            "O contexto do pane Scout está desatualizado. Recrie a sessão antes de enviar o plano.",
            .{ .status = .bad_request },
        );
    }

    if (scout.session_external_id.len == 0) {
        return c.text(
            "O pane Scout não possui sessão OpenCode vinculada.",
            .{ .status = .bad_request },
        );
    }

    const runtime_rows = try loadWorkspaceRuntime(c, workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "O runtime deste workspace ainda não foi preparado.",
            .{ .status = .bad_request },
        );
    }

    try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try loadWorkspaceRuntime(c, workspace_id);

    if (refreshed_runtime_rows.len == 0) {
        return c.text(
            "Runtime não encontrado após reconciliação.",
            .{ .status = .bad_request },
        );
    }

    const runtime = refreshed_runtime_rows[0];

    if (!std.mem.eql(u8, runtime.state, "running")) {
        return c.text(
            "O runtime precisa estar em execução para enviar o plano ao Scout.",
            .{ .status = .bad_request },
        );
    }

    const scout_prompt = try std.fmt.allocPrint(
        c.arena,
        "Zivyar Cockpit — Plano Operacional enviado ao Scout\n\n" ++
            "Workspace: {s}\n" ++
            "Squad: {s}\n\n" ++
            "Missão ativa:\n{s}\n\n" ++
            "Objetivo da missão:\n{s}\n\n" ++
            "Status atual: {s}\n" ++
            "Prioridade: {s}\n\n" ++
            "Briefing Operacional do Piloto:\n{s}\n\n" ++
            "Plano Operacional do Planner:\n{s}\n\n" ++
            "Diretriz operacional:\n" ++
            "Mapeie o workspace conectado ao runtime. " ++
            "Produza um Scout Report técnico contendo: " ++
            "1) leitura da estrutura atual do projeto, " ++
            "2) arquivos, módulos ou diretórios relevantes para a missão, " ++
            "3) pontos de entrada prováveis, " ++
            "4) riscos, inconsistências ou lacunas observadas, " ++
            "5) recomendações objetivas para o Builder executar com segurança. " ++
            "Não implemente código neste retorno.",
        .{
            mission.workspace_name,
            mission.squad_name,
            mission.title,
            mission.objective,
            mission.status,
            mission.priority,
            mission.pilot_operational_brief,
            mission.planner_operational_plan,
        },
    );

    const prompt_parts = [_]OpenCodeTextPart{
        .{
            .type = "text",
            .text = scout_prompt,
        },
    };

    const prompt_body = try std.json.Stringify.valueAlloc(
        c.arena,
        OpenCodePromptAsyncRequest{
            .parts = prompt_parts[0..],
        },
        .{},
    );

    const prompt_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/prompt_async",
        .{ runtime.server_url_label, scout.session_external_id },
    );

    const dispatch_result = runRuntimeCommand(c, &.{
        "curl",
        "-fsS",
        "-X",
        "POST",
        prompt_url,
        "-H",
        "Content-Type: application/json",
        "-d",
        prompt_body,
    });

    try insertRuntimeCommandLog(
        c,
        workspace_id,
        "opencode-dispatch-planner-plan-to-scout",
        "POST <opencode-server>/session/<session-id>/prompt_async",
        dispatch_result,
    );

    if (!dispatch_result.ok) {
        try db.query(
            void,
            c.arena,
            \\UPDATE missions
            \\SET scout_dispatch_status = 'error'
            \\WHERE id = $1
            ,
            .{ mission_id },
        );

        try insertRuntimeEvent(
            c,
            workspace_id,
            "scout-dispatch-error",
            "Falha ao enviar plano ao Scout",
            "O OpenCode Server não confirmou o envio assíncrono do plano ao pane Scout.",
        );

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
            \\    'planner-plan-dispatch-to-scout-error',
            \\    'Falha ao enviar plano ao Scout',
            \\    'O despacho assíncrono do plano ao pane Scout não foi confirmado pelo OpenCode Server.'
            \\)
            ,
            .{ mission_id, workspace_id },
        );

        return c.text(
            "Falha ao enviar o Plano Operacional do Planner ao Scout.",
            .{ .status = .bad_request },
        );
    }

    const dispatch_messages_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/message",
        .{ runtime.server_url_label, scout.session_external_id },
    );

    var scout_dispatch_user_message_id: []const u8 = "";
    var dispatch_trace_attempt: usize = 0;

    while (dispatch_trace_attempt < 6 and scout_dispatch_user_message_id.len == 0) : (dispatch_trace_attempt += 1) {
        const dispatch_messages_result = runRuntimeCommand(c, &.{
            "curl",
            "-fsS",
            dispatch_messages_url,
        });

        if (dispatch_messages_result.ok) {
            if (try extractLatestUserMessageIdMatchingText(
                c.arena,
                dispatch_messages_result.stdout,
                scout_prompt,
            )) |message_id| {
                scout_dispatch_user_message_id = message_id;
                break;
            }
        }

        std.Io.sleep(c._io, std.Io.Duration.fromMilliseconds(200), .real) catch {};
    }

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
        .{ scout.session_external_id, scout_dispatch_user_message_id, mission_id },
    );

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Plano Operacional do Planner da missão \"{s}\" foi enviado ao pane Scout na sessão {s}.",
        .{ mission.title, scout.session_external_id },
    );

    try insertRuntimeEvent(
        c,
        workspace_id,
        "planner-plan-dispatched-to-scout",
        "Plano enviado ao Scout",
        event_message,
    );

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
        \\    'planner-plan-dispatched-to-scout',
        \\    'Plano enviado ao Scout',
        \\    $3
        \\)
        ,
        .{ mission_id, workspace_id, event_message },
    );

    const scout_session_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/Lw/session/{s}",
        .{ runtime.server_url_label, scout.session_external_id },
    );

    return c.redirect(scout_session_url);
}


fn workspaceMissionDispatchScoutReportToBuilder(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const mission_id_raw = c.params.get("mission_id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, mission_id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const active_mission_rows = try db.query(
        MissionRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.workspace_id,
        \\    w.name AS workspace_name,
        \\    m.squad_id,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name,
        \\    m.title,
        \\    m.objective,
        \\    m.status,
        \\    m.priority,
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
        \\    ) AS mission_operational_closed_at_label
        \\FROM workspaces w
        \\INNER JOIN missions m ON m.id = w.active_mission_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\WHERE w.id = $1
        \\AND m.id = $2
        \\LIMIT 1
        ,
        .{ workspace_id, mission_id },
    );

    if (active_mission_rows.len == 0) {
        return c.text(
            "Esta missão não é a missão ativa deste workspace.",
            .{ .status = .bad_request },
        );
    }

    const mission = active_mission_rows[0];

    if (std.mem.eql(u8, mission.mission_operational_closure_status, "closed")) {
        return c.text(
            "Missões encerradas operacionalmente não podem executar novas ações do ciclo operacional.",
            .{ .status = .bad_request },
        );
    }

    if (
        mission.scout_report.len == 0 or
        !std.mem.eql(u8, mission.scout_report_status, "captured")
    ) {
        return c.text(
            "Capture o Scout Report antes de enviá-lo ao Builder.",
            .{ .status = .bad_request },
        );
    }

    const builder_rows = try db.query(
        WorkspaceMissionPaneDispatchRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    role_name,
        \\    pane_state,
        \\    session_external_id,
        \\    context_state
        \\FROM workspace_panes
        \\WHERE workspace_id = $1
        \\AND role_name = 'Builder'
        \\LIMIT 1
        ,
        .{ workspace_id },
    );

    if (builder_rows.len == 0) {
        return c.text(
            "O pane Builder ainda não foi materializado neste workspace.",
            .{ .status = .bad_request },
        );
    }

    const builder = builder_rows[0];

    if (!std.mem.eql(u8, builder.pane_state, "active")) {
        return c.text(
            "O pane Builder precisa estar ativo para receber o pacote de execução.",
            .{ .status = .bad_request },
        );
    }

    if (!std.mem.eql(u8, builder.context_state, "current")) {
        return c.text(
            "O contexto do pane Builder está desatualizado. Recrie a sessão antes de enviar o pacote.",
            .{ .status = .bad_request },
        );
    }

    if (builder.session_external_id.len == 0) {
        return c.text(
            "O pane Builder não possui sessão OpenCode vinculada.",
            .{ .status = .bad_request },
        );
    }

    const runtime_rows = try loadWorkspaceRuntime(c, workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "O runtime deste workspace ainda não foi preparado.",
            .{ .status = .bad_request },
        );
    }

    try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try loadWorkspaceRuntime(c, workspace_id);

    if (refreshed_runtime_rows.len == 0) {
        return c.text(
            "Runtime não encontrado após reconciliação.",
            .{ .status = .bad_request },
        );
    }

    const runtime = refreshed_runtime_rows[0];

    if (!std.mem.eql(u8, runtime.state, "running")) {
        return c.text(
            "O runtime precisa estar em execução para enviar o pacote ao Builder.",
            .{ .status = .bad_request },
        );
    }

    const builder_prompt = try std.fmt.allocPrint(
        c.arena,
        "Zivyar Cockpit — Pacote de execução enviado ao Builder\n\n" ++
            "Workspace: {s}\n" ++
            "Squad: {s}\n\n" ++
            "Missão ativa:\n{s}\n\n" ++
            "Objetivo da missão:\n{s}\n\n" ++
            "Status atual: {s}\n" ++
            "Prioridade: {s}\n\n" ++
            "Briefing Operacional do Piloto:\n{s}\n\n" ++
            "Plano Operacional do Planner:\n{s}\n\n" ++
            "Scout Report:\n{s}\n\n" ++
            "Diretriz operacional:\n" ++
            "Use este pacote consolidado como base para iniciar a execução técnica da missão. " ++
            "Implemente somente o que for necessário para atender ao objetivo, respeitando o plano do Planner " ++
            "e os riscos apontados pelo Scout. " ++
            "Ao concluir, produza um Implementation Report com: " ++
            "1) o que foi alterado, 2) arquivos impactados, 3) decisões técnicas tomadas, " ++
            "4) riscos remanescentes, 5) comandos ou validações recomendadas para o Executor.",
        .{
            mission.workspace_name,
            mission.squad_name,
            mission.title,
            mission.objective,
            mission.status,
            mission.priority,
            mission.pilot_operational_brief,
            mission.planner_operational_plan,
            mission.scout_report,
        },
    );

    const prompt_parts = [_]OpenCodeTextPart{
        .{
            .type = "text",
            .text = builder_prompt,
        },
    };

    const prompt_body = try std.json.Stringify.valueAlloc(
        c.arena,
        OpenCodePromptAsyncRequest{
            .parts = prompt_parts[0..],
        },
        .{},
    );

    const prompt_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/prompt_async",
        .{ runtime.server_url_label, builder.session_external_id },
    );

    const dispatch_result = runRuntimeCommand(c, &.{
        "curl",
        "-fsS",
        "-X",
        "POST",
        prompt_url,
        "-H",
        "Content-Type: application/json",
        "-d",
        prompt_body,
    });

    try insertRuntimeCommandLog(
        c,
        workspace_id,
        "opencode-dispatch-scout-report-to-builder",
        "POST <opencode-server>/session/<session-id>/prompt_async",
        dispatch_result,
    );

    if (!dispatch_result.ok) {
        try db.query(
            void,
            c.arena,
            \\UPDATE missions
            \\SET builder_dispatch_status = 'error'
            \\WHERE id = $1
            ,
            .{ mission_id },
        );

        try insertRuntimeEvent(
            c,
            workspace_id,
            "builder-dispatch-error",
            "Falha ao enviar pacote ao Builder",
            "O OpenCode Server não confirmou o envio assíncrono do pacote de execução ao pane Builder.",
        );

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
            \\    'scout-report-dispatch-to-builder-error',
            \\    'Falha ao enviar pacote ao Builder',
            \\    'O despacho assíncrono do pacote de execução ao pane Builder não foi confirmado pelo OpenCode Server.'
            \\)
            ,
            .{ mission_id, workspace_id },
        );

        return c.text(
            "Falha ao enviar o pacote de execução ao Builder.",
            .{ .status = .bad_request },
        );
    }

    const dispatch_messages_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/message",
        .{ runtime.server_url_label, builder.session_external_id },
    );

    var builder_dispatch_user_message_id: []const u8 = "";
    var dispatch_trace_attempt: usize = 0;

    while (dispatch_trace_attempt < 6 and builder_dispatch_user_message_id.len == 0) : (dispatch_trace_attempt += 1) {
        const dispatch_messages_result = runRuntimeCommand(c, &.{
            "curl",
            "-fsS",
            dispatch_messages_url,
        });

        if (dispatch_messages_result.ok) {
            if (try extractLatestUserMessageIdMatchingText(
                c.arena,
                dispatch_messages_result.stdout,
                builder_prompt,
            )) |message_id| {
                builder_dispatch_user_message_id = message_id;
                break;
            }
        }

        std.Io.sleep(c._io, std.Io.Duration.fromMilliseconds(200), .real) catch {};
    }

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
        .{ builder.session_external_id, builder_dispatch_user_message_id, mission_id },
    );

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O pacote de execução da missão \"{s}\" foi enviado ao pane Builder na sessão {s}.",
        .{ mission.title, builder.session_external_id },
    );

    try insertRuntimeEvent(
        c,
        workspace_id,
        "execution-package-dispatched-to-builder",
        "Pacote enviado ao Builder",
        event_message,
    );

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
        \\    'execution-package-dispatched-to-builder',
        \\    'Pacote enviado ao Builder',
        \\    $3
        \\)
        ,
        .{ mission_id, workspace_id, event_message },
    );

    const builder_session_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/Lw/session/{s}",
        .{ runtime.server_url_label, builder.session_external_id },
    );

    return c.redirect(builder_session_url);
}


fn workspaceMissionDispatchBuilderReportToReviewer(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const mission_id_raw = c.params.get("mission_id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, mission_id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const active_mission_rows = try db.query(
        MissionRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.workspace_id,
        \\    w.name AS workspace_name,
        \\    m.squad_id,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name,
        \\    m.title,
        \\    m.objective,
        \\    m.status,
        \\    m.priority,
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
        \\    ) AS mission_operational_closed_at_label
        \\FROM workspaces w
        \\INNER JOIN missions m ON m.id = w.active_mission_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\WHERE w.id = $1
        \\AND m.id = $2
        \\LIMIT 1
        ,
        .{ workspace_id, mission_id },
    );

    if (active_mission_rows.len == 0) {
        return c.text(
            "Esta missão não é a missão ativa deste workspace.",
            .{ .status = .bad_request },
        );
    }

    const mission = active_mission_rows[0];

    if (std.mem.eql(u8, mission.mission_operational_closure_status, "closed")) {
        return c.text(
            "Missões encerradas operacionalmente não podem executar novas ações do ciclo operacional.",
            .{ .status = .bad_request },
        );
    }

    if (
        mission.builder_implementation_report.len == 0 or
        !std.mem.eql(u8, mission.builder_implementation_report_status, "captured")
    ) {
        return c.text(
            "Capture o Implementation Report do Builder antes de enviá-lo ao Reviewer.",
            .{ .status = .bad_request },
        );
    }

    const reviewer_rows = try db.query(
        WorkspaceMissionPaneDispatchRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    role_name,
        \\    pane_state,
        \\    session_external_id,
        \\    context_state
        \\FROM workspace_panes
        \\WHERE workspace_id = $1
        \\AND role_name = 'Reviewer'
        \\LIMIT 1
        ,
        .{ workspace_id },
    );

    if (reviewer_rows.len == 0) {
        return c.text(
            "O pane Reviewer ainda não foi materializado neste workspace.",
            .{ .status = .bad_request },
        );
    }

    const reviewer = reviewer_rows[0];

    if (!std.mem.eql(u8, reviewer.pane_state, "active")) {
        return c.text(
            "O pane Reviewer precisa estar ativo para receber o relatório de implementação.",
            .{ .status = .bad_request },
        );
    }

    if (!std.mem.eql(u8, reviewer.context_state, "current")) {
        return c.text(
            "O contexto do pane Reviewer está desatualizado. Recrie a sessão antes de enviar o relatório.",
            .{ .status = .bad_request },
        );
    }

    if (reviewer.session_external_id.len == 0) {
        return c.text(
            "O pane Reviewer não possui sessão OpenCode vinculada.",
            .{ .status = .bad_request },
        );
    }

    const runtime_rows = try loadWorkspaceRuntime(c, workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "O runtime deste workspace ainda não foi preparado.",
            .{ .status = .bad_request },
        );
    }

    try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try loadWorkspaceRuntime(c, workspace_id);

    if (refreshed_runtime_rows.len == 0) {
        return c.text(
            "Runtime não encontrado após reconciliação.",
            .{ .status = .bad_request },
        );
    }

    const runtime = refreshed_runtime_rows[0];

    if (!std.mem.eql(u8, runtime.state, "running")) {
        return c.text(
            "O runtime precisa estar em execução para enviar o relatório ao Reviewer.",
            .{ .status = .bad_request },
        );
    }

    const reviewer_prompt = try std.fmt.allocPrint(
        c.arena,
        "Zivyar Cockpit — Implementation Report enviado ao Reviewer\n\n" ++
            "Workspace: {s}\n" ++
            "Squad: {s}\n\n" ++
            "Missão ativa:\n{s}\n\n" ++
            "Objetivo da missão:\n{s}\n\n" ++
            "Status atual: {s}\n" ++
            "Prioridade: {s}\n\n" ++
            "Briefing Operacional do Piloto:\n{s}\n\n" ++
            "Plano Operacional do Planner:\n{s}\n\n" ++
            "Scout Report:\n{s}\n\n" ++
            "Implementation Report do Builder:\n{s}\n\n" ++
            "Diretriz operacional:\n" ++
            "Revise tecnicamente a execução descrita pelo Builder. " ++
            "Produza um Review Report contendo: " ++
            "1) avaliação de aderência ao plano, " ++
            "2) riscos de arquitetura, regressão ou qualidade, " ++
            "3) inconsistências, omissões ou pontos frágeis, " ++
            "4) recomendações objetivas de correção ou validação, " ++
            "5) veredito final: approved, needs_adjustments ou blocked. " ++
            "Não implemente código neste retorno.",
        .{
            mission.workspace_name,
            mission.squad_name,
            mission.title,
            mission.objective,
            mission.status,
            mission.priority,
            mission.pilot_operational_brief,
            mission.planner_operational_plan,
            mission.scout_report,
            mission.builder_implementation_report,
        },
    );

    const prompt_parts = [_]OpenCodeTextPart{
        .{
            .type = "text",
            .text = reviewer_prompt,
        },
    };

    const prompt_body = try std.json.Stringify.valueAlloc(
        c.arena,
        OpenCodePromptAsyncRequest{
            .parts = prompt_parts[0..],
        },
        .{},
    );

    const prompt_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/prompt_async",
        .{ runtime.server_url_label, reviewer.session_external_id },
    );

    const dispatch_result = runRuntimeCommand(c, &.{
        "curl",
        "-fsS",
        "-X",
        "POST",
        prompt_url,
        "-H",
        "Content-Type: application/json",
        "-d",
        prompt_body,
    });

    try insertRuntimeCommandLog(
        c,
        workspace_id,
        "opencode-dispatch-builder-report-to-reviewer",
        "POST <opencode-server>/session/<session-id>/prompt_async",
        dispatch_result,
    );

    if (!dispatch_result.ok) {
        try db.query(
            void,
            c.arena,
            \\UPDATE missions
            \\SET reviewer_dispatch_status = 'error'
            \\WHERE id = $1
            ,
            .{ mission_id },
        );

        try insertRuntimeEvent(
            c,
            workspace_id,
            "reviewer-dispatch-error",
            "Falha ao enviar relatório ao Reviewer",
            "O OpenCode Server não confirmou o envio assíncrono do Implementation Report ao pane Reviewer.",
        );

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
            \\    'builder-report-dispatch-to-reviewer-error',
            \\    'Falha ao enviar relatório ao Reviewer',
            \\    'O despacho assíncrono do Implementation Report ao pane Reviewer não foi confirmado pelo OpenCode Server.'
            \\)
            ,
            .{ mission_id, workspace_id },
        );

        return c.text(
            "Falha ao enviar o Implementation Report do Builder ao Reviewer.",
            .{ .status = .bad_request },
        );
    }

    const dispatch_messages_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/message",
        .{ runtime.server_url_label, reviewer.session_external_id },
    );

    var reviewer_dispatch_user_message_id: []const u8 = "";
    var dispatch_trace_attempt: usize = 0;

    while (dispatch_trace_attempt < 6 and reviewer_dispatch_user_message_id.len == 0) : (dispatch_trace_attempt += 1) {
        const dispatch_messages_result = runRuntimeCommand(c, &.{
            "curl",
            "-fsS",
            dispatch_messages_url,
        });

        if (dispatch_messages_result.ok) {
            if (try extractLatestUserMessageIdMatchingText(
                c.arena,
                dispatch_messages_result.stdout,
                reviewer_prompt,
            )) |message_id| {
                reviewer_dispatch_user_message_id = message_id;
                break;
            }
        }

        std.Io.sleep(c._io, std.Io.Duration.fromMilliseconds(200), .real) catch {};
    }

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
        .{ reviewer.session_external_id, reviewer_dispatch_user_message_id, mission_id },
    );

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Implementation Report do Builder da missão \"{s}\" foi enviado ao pane Reviewer na sessão {s}.",
        .{ mission.title, reviewer.session_external_id },
    );

    try insertRuntimeEvent(
        c,
        workspace_id,
        "builder-report-dispatched-to-reviewer",
        "Implementation Report enviado ao Reviewer",
        event_message,
    );

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
        \\    'builder-report-dispatched-to-reviewer',
        \\    'Implementation Report enviado ao Reviewer',
        \\    $3
        \\)
        ,
        .{ mission_id, workspace_id, event_message },
    );

    const reviewer_session_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/Lw/session/{s}",
        .{ runtime.server_url_label, reviewer.session_external_id },
    );

    return c.redirect(reviewer_session_url);
}


fn workspaceMissionDispatchReviewerReportToExecutor(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const mission_id_raw = c.params.get("mission_id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, mission_id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const active_mission_rows = try db.query(
        MissionRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.workspace_id,
        \\    w.name AS workspace_name,
        \\    m.squad_id,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name,
        \\    m.title,
        \\    m.objective,
        \\    m.status,
        \\    m.priority,
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
        \\    ) AS mission_operational_closed_at_label
        \\FROM workspaces w
        \\INNER JOIN missions m ON m.id = w.active_mission_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\WHERE w.id = $1
        \\AND m.id = $2
        \\LIMIT 1
        ,
        .{ workspace_id, mission_id },
    );

    if (active_mission_rows.len == 0) {
        return c.text(
            "Esta missão não é a missão ativa deste workspace.",
            .{ .status = .bad_request },
        );
    }

    const mission = active_mission_rows[0];

    if (std.mem.eql(u8, mission.mission_operational_closure_status, "closed")) {
        return c.text(
            "Missões encerradas operacionalmente não podem executar novas ações do ciclo operacional.",
            .{ .status = .bad_request },
        );
    }

    if (
        mission.reviewer_review_report.len == 0 or
        !std.mem.eql(u8, mission.reviewer_review_report_status, "captured")
    ) {
        return c.text(
            "Capture o Review Report do Reviewer antes de enviá-lo ao Executor.",
            .{ .status = .bad_request },
        );
    }

    const executor_rows = try db.query(
        WorkspaceMissionPaneDispatchRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    role_name,
        \\    pane_state,
        \\    session_external_id,
        \\    context_state
        \\FROM workspace_panes
        \\WHERE workspace_id = $1
        \\AND role_name = 'Executor'
        \\LIMIT 1
        ,
        .{ workspace_id },
    );

    if (executor_rows.len == 0) {
        return c.text(
            "O pane Executor ainda não foi materializado neste workspace.",
            .{ .status = .bad_request },
        );
    }

    const executor = executor_rows[0];

    if (!std.mem.eql(u8, executor.pane_state, "active")) {
        return c.text(
            "O pane Executor precisa estar ativo para receber o pacote de verificação.",
            .{ .status = .bad_request },
        );
    }

    if (!std.mem.eql(u8, executor.context_state, "current")) {
        return c.text(
            "O contexto do pane Executor está desatualizado. Recrie a sessão antes de enviar o pacote.",
            .{ .status = .bad_request },
        );
    }

    if (executor.session_external_id.len == 0) {
        return c.text(
            "O pane Executor não possui sessão OpenCode vinculada.",
            .{ .status = .bad_request },
        );
    }

    const runtime_rows = try loadWorkspaceRuntime(c, workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "O runtime deste workspace ainda não foi preparado.",
            .{ .status = .bad_request },
        );
    }

    try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try loadWorkspaceRuntime(c, workspace_id);

    if (refreshed_runtime_rows.len == 0) {
        return c.text(
            "Runtime não encontrado após reconciliação.",
            .{ .status = .bad_request },
        );
    }

    const runtime = refreshed_runtime_rows[0];

    if (!std.mem.eql(u8, runtime.state, "running")) {
        return c.text(
            "O runtime precisa estar em execução para enviar o pacote ao Executor.",
            .{ .status = .bad_request },
        );
    }

    const executor_prompt = try std.fmt.allocPrint(
        c.arena,
        "Zivyar Cockpit — Pacote de verificação enviado ao Executor\n\n" ++
            "Workspace: {s}\n" ++
            "Squad: {s}\n\n" ++
            "Missão ativa:\n{s}\n\n" ++
            "Objetivo da missão:\n{s}\n\n" ++
            "Status atual: {s}\n" ++
            "Prioridade: {s}\n\n" ++
            "Briefing Operacional do Piloto:\n{s}\n\n" ++
            "Plano Operacional do Planner:\n{s}\n\n" ++
            "Scout Report:\n{s}\n\n" ++
            "Implementation Report do Builder:\n{s}\n\n" ++
            "Review Report do Reviewer:\n{s}\n\n" ++
            "Diretriz operacional:\n" ++
            "Execute a verificação técnica possível no workspace atual. " ++
            "Rode comandos, builds, checks ou testes quando existirem e forem apropriados. " ++
            "Produza um Verification Report contendo: " ++
            "1) comandos executados, " ++
            "2) resultados observados, " ++
            "3) validações concluídas, " ++
            "4) bloqueios, riscos ou ausências de material para testar, " ++
            "5) veredito final: verified, failed ou blocked. " ++
            "Não implemente código neste retorno.",
        .{
            mission.workspace_name,
            mission.squad_name,
            mission.title,
            mission.objective,
            mission.status,
            mission.priority,
            mission.pilot_operational_brief,
            mission.planner_operational_plan,
            mission.scout_report,
            mission.builder_implementation_report,
            mission.reviewer_review_report,
        },
    );

    const prompt_parts = [_]OpenCodeTextPart{
        .{
            .type = "text",
            .text = executor_prompt,
        },
    };

    const prompt_body = try std.json.Stringify.valueAlloc(
        c.arena,
        OpenCodePromptAsyncRequest{
            .parts = prompt_parts[0..],
        },
        .{},
    );

    const prompt_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/prompt_async",
        .{ runtime.server_url_label, executor.session_external_id },
    );

    const dispatch_result = runRuntimeCommand(c, &.{
        "curl",
        "-fsS",
        "-X",
        "POST",
        prompt_url,
        "-H",
        "Content-Type: application/json",
        "-d",
        prompt_body,
    });

    try insertRuntimeCommandLog(
        c,
        workspace_id,
        "opencode-dispatch-reviewer-report-to-executor",
        "POST <opencode-server>/session/<session-id>/prompt_async",
        dispatch_result,
    );

    if (!dispatch_result.ok) {
        try db.query(
            void,
            c.arena,
            \\UPDATE missions
            \\SET executor_dispatch_status = 'error'
            \\WHERE id = $1
            ,
            .{ mission_id },
        );

        try insertRuntimeEvent(
            c,
            workspace_id,
            "executor-dispatch-error",
            "Falha ao enviar pacote ao Executor",
            "O OpenCode Server não confirmou o envio assíncrono do pacote de verificação ao pane Executor.",
        );

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
            \\    'reviewer-report-dispatch-to-executor-error',
            \\    'Falha ao enviar pacote ao Executor',
            \\    'O despacho assíncrono do Review Report ao pane Executor não foi confirmado pelo OpenCode Server.'
            \\)
            ,
            .{ mission_id, workspace_id },
        );

        return c.text(
            "Falha ao enviar o pacote de verificação ao Executor.",
            .{ .status = .bad_request },
        );
    }

    const dispatch_messages_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/message",
        .{ runtime.server_url_label, executor.session_external_id },
    );

    var executor_dispatch_user_message_id: []const u8 = "";
    var dispatch_trace_attempt: usize = 0;

    while (dispatch_trace_attempt < 6 and executor_dispatch_user_message_id.len == 0) : (dispatch_trace_attempt += 1) {
        const dispatch_messages_result = runRuntimeCommand(c, &.{
            "curl",
            "-fsS",
            dispatch_messages_url,
        });

        if (dispatch_messages_result.ok) {
            if (try extractLatestUserMessageIdMatchingText(
                c.arena,
                dispatch_messages_result.stdout,
                executor_prompt,
            )) |message_id| {
                executor_dispatch_user_message_id = message_id;
                break;
            }
        }

        std.Io.sleep(c._io, std.Io.Duration.fromMilliseconds(200), .real) catch {};
    }

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
        .{ executor.session_external_id, executor_dispatch_user_message_id, mission_id },
    );

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Review Report da missão \"{s}\" foi enviado ao pane Executor na sessão {s}.",
        .{ mission.title, executor.session_external_id },
    );

    try insertRuntimeEvent(
        c,
        workspace_id,
        "reviewer-report-dispatched-to-executor",
        "Review Report enviado ao Executor",
        event_message,
    );

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
        \\    'reviewer-report-dispatched-to-executor',
        \\    'Review Report enviado ao Executor',
        \\    $3
        \\)
        ,
        .{ mission_id, workspace_id, event_message },
    );

    const executor_session_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/Lw/session/{s}",
        .{ runtime.server_url_label, executor.session_external_id },
    );

    return c.redirect(executor_session_url);
}



fn workspaceMissionDispatchExecutorReportToPilot(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const mission_id_raw = c.params.get("mission_id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, mission_id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const active_mission_rows = try db.query(
        MissionRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.workspace_id,
        \\    w.name AS workspace_name,
        \\    m.squad_id,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name,
        \\    m.title,
        \\    m.objective,
        \\    m.status,
        \\    m.priority,
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
        \\    ) AS mission_operational_closed_at_label
        \\FROM workspaces w
        \\INNER JOIN missions m ON m.id = w.active_mission_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\WHERE w.id = $1
        \\AND m.id = $2
        \\LIMIT 1
        ,
        .{ workspace_id, mission_id },
    );

    if (active_mission_rows.len == 0) {
        return c.text(
            "Esta missão não é a missão ativa deste workspace.",
            .{ .status = .bad_request },
        );
    }

    const mission = active_mission_rows[0];

    if (std.mem.eql(u8, mission.mission_operational_closure_status, "closed")) {
        return c.text(
            "Missões encerradas operacionalmente não podem executar novas ações do ciclo operacional.",
            .{ .status = .bad_request },
        );
    }

    if (
        mission.executor_verification_report.len == 0 or
        !std.mem.eql(u8, mission.executor_verification_report_status, "captured")
    ) {
        return c.text(
            "Capture o Verification Report do Executor antes de enviá-lo ao Piloto.",
            .{ .status = .bad_request },
        );
    }

    const pilot_rows = try db.query(
        WorkspaceMissionPaneDispatchRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    role_name,
        \\    pane_state,
        \\    session_external_id,
        \\    context_state
        \\FROM workspace_panes
        \\WHERE workspace_id = $1
        \\AND role_name = 'Piloto'
        \\LIMIT 1
        ,
        .{ workspace_id },
    );

    if (pilot_rows.len == 0) {
        return c.text(
            "O pane Piloto ainda não foi materializado neste workspace.",
            .{ .status = .bad_request },
        );
    }

    const pilot = pilot_rows[0];

    if (!std.mem.eql(u8, pilot.pane_state, "active")) {
        return c.text(
            "O pane Piloto precisa estar ativo para receber o relatório de verificação.",
            .{ .status = .bad_request },
        );
    }

    if (!std.mem.eql(u8, pilot.context_state, "current")) {
        return c.text(
            "O contexto do pane Piloto está desatualizado. Recrie a sessão antes de enviar o relatório.",
            .{ .status = .bad_request },
        );
    }

    if (pilot.session_external_id.len == 0) {
        return c.text(
            "O pane Piloto não possui sessão OpenCode vinculada.",
            .{ .status = .bad_request },
        );
    }

    const runtime_rows = try loadWorkspaceRuntime(c, workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "O runtime deste workspace ainda não foi preparado.",
            .{ .status = .bad_request },
        );
    }

    try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try loadWorkspaceRuntime(c, workspace_id);

    if (refreshed_runtime_rows.len == 0) {
        return c.text(
            "Runtime não encontrado após reconciliação.",
            .{ .status = .bad_request },
        );
    }

    const runtime = refreshed_runtime_rows[0];

    if (!std.mem.eql(u8, runtime.state, "running")) {
        return c.text(
            "O runtime precisa estar em execução para enviar o relatório ao Piloto.",
            .{ .status = .bad_request },
        );
    }

    const pilot_delivery_prompt = try std.fmt.allocPrint(
        c.arena,
        "Zivyar Cockpit — Verification Report enviado ao Piloto para entrega final\n\n" ++
            "Workspace: {s}\n" ++
            "Squad: {s}\n\n" ++
            "Missão ativa:\n{s}\n\n" ++
            "Objetivo da missão:\n{s}\n\n" ++
            "Status atual: {s}\n" ++
            "Prioridade: {s}\n\n" ++
            "Briefing Operacional do Piloto:\n{s}\n\n" ++
            "Plano Operacional do Planner:\n{s}\n\n" ++
            "Scout Report:\n{s}\n\n" ++
            "Implementation Report do Builder:\n{s}\n\n" ++
            "Review Report do Reviewer:\n{s}\n\n" ++
            "Verification Report do Executor:\n{s}\n\n" ++
            "Diretriz operacional:\n" ++
            "Consolide o ciclo completo da missão e produza um Final Delivery Report. " ++
            "O relatório deve conter: " ++
            "1) síntese executiva da missão, " ++
            "2) leitura consolidada da entrega realizada ou do bloqueio encontrado, " ++
            "3) evidências e relatórios considerados, " ++
            "4) conclusão operacional com status final: completed, needs_follow_up ou blocked, " ++
            "5) próximos passos recomendados ao usuário. " ++
            "Não implemente código neste retorno.",
        .{
            mission.workspace_name,
            mission.squad_name,
            mission.title,
            mission.objective,
            mission.status,
            mission.priority,
            mission.pilot_operational_brief,
            mission.planner_operational_plan,
            mission.scout_report,
            mission.builder_implementation_report,
            mission.reviewer_review_report,
            mission.executor_verification_report,
        },
    );

    const prompt_parts = [_]OpenCodeTextPart{
        .{
            .type = "text",
            .text = pilot_delivery_prompt,
        },
    };

    const prompt_body = try std.json.Stringify.valueAlloc(
        c.arena,
        OpenCodePromptAsyncRequest{
            .parts = prompt_parts[0..],
        },
        .{},
    );

    const prompt_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/prompt_async",
        .{ runtime.server_url_label, pilot.session_external_id },
    );

    const dispatch_result = runRuntimeCommand(c, &.{
        "curl",
        "-fsS",
        "-X",
        "POST",
        prompt_url,
        "-H",
        "Content-Type: application/json",
        "-d",
        prompt_body,
    });

    try insertRuntimeCommandLog(
        c,
        workspace_id,
        "opencode-dispatch-executor-report-to-pilot-delivery",
        "POST <opencode-server>/session/<session-id>/prompt_async",
        dispatch_result,
    );

    if (!dispatch_result.ok) {
        try db.query(
            void,
            c.arena,
            \\UPDATE missions
            \\SET pilot_delivery_dispatch_status = 'error'
            \\WHERE id = $1
            ,
            .{ mission_id },
        );

        try insertRuntimeEvent(
            c,
            workspace_id,
            "pilot-delivery-dispatch-error",
            "Falha ao enviar relatório final ao Piloto",
            "O OpenCode Server não confirmou o envio assíncrono do Verification Report ao pane Piloto.",
        );

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
            \\    'executor-report-dispatch-to-pilot-error',
            \\    'Falha ao enviar Verification Report ao Piloto',
            \\    'O despacho assíncrono do Verification Report ao pane Piloto não foi confirmado pelo OpenCode Server.'
            \\)
            ,
            .{ mission_id, workspace_id },
        );

        return c.text(
            "Falha ao enviar o Verification Report do Executor ao Piloto.",
            .{ .status = .bad_request },
        );
    }

    const dispatch_messages_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/message",
        .{ runtime.server_url_label, pilot.session_external_id },
    );

    var pilot_delivery_dispatch_user_message_id: []const u8 = "";
    var dispatch_trace_attempt: usize = 0;

    while (dispatch_trace_attempt < 6 and pilot_delivery_dispatch_user_message_id.len == 0) : (dispatch_trace_attempt += 1) {
        const dispatch_messages_result = runRuntimeCommand(c, &.{
            "curl",
            "-fsS",
            dispatch_messages_url,
        });

        if (dispatch_messages_result.ok) {
            if (try extractLatestUserMessageIdMatchingText(
                c.arena,
                dispatch_messages_result.stdout,
                pilot_delivery_prompt,
            )) |message_id| {
                pilot_delivery_dispatch_user_message_id = message_id;
                break;
            }
        }

        std.Io.sleep(c._io, std.Io.Duration.fromMilliseconds(200), .real) catch {};
    }

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
        .{ pilot.session_external_id, pilot_delivery_dispatch_user_message_id, mission_id },
    );

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Verification Report do Executor da missão \"{s}\" foi enviado ao pane Piloto na sessão {s} para consolidação da entrega final.",
        .{ mission.title, pilot.session_external_id },
    );

    try insertRuntimeEvent(
        c,
        workspace_id,
        "executor-report-dispatched-to-pilot-delivery",
        "Verification Report enviado ao Piloto",
        event_message,
    );

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
        \\    'executor-report-dispatched-to-pilot-delivery',
        \\    'Verification Report enviado ao Piloto',
        \\    $3
        \\)
        ,
        .{ mission_id, workspace_id, event_message },
    );

    const pilot_session_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/Lw/session/{s}",
        .{ runtime.server_url_label, pilot.session_external_id },
    );

    return c.redirect(pilot_session_url);
}

fn workspaceShow(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const rows = try db.query(
        WorkspaceRow,
        c.arena,
        \\SELECT
        \\    w.id,
        \\    w.name,
        \\    w.local_path,
        \\    w.stack_name,
        \\    w.default_squad_id,
        \\    COALESCE(s.name, 'Sem squad vinculada') AS squad_name,
        \\    w.status
        \\FROM workspaces w
        \\LEFT JOIN squads s ON s.id = w.default_squad_id
        \\WHERE w.id = $1
        \\LIMIT 1
        ,
        .{ workspace_id },
    );

    if (rows.len == 0) {
        return c.text("Workspace não encontrado.", .{ .status = .not_found });
    }

    const workspace = rows[0];
    const linked_squad_id = workspace.default_squad_id orelse 0;
    const runtime_rows = try loadWorkspaceRuntime(c, workspace.id);

    try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try loadWorkspaceRuntime(c, workspace.id);

    try reconcileWorkspacePaneSessions(c, workspace.id, refreshed_runtime_rows[0]);

    const runtime_events = try db.query(
        WorkspaceRuntimeEventRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    event_type,
        \\    title,
        \\    message
        \\FROM workspace_runtime_events
        \\WHERE workspace_id = $1
        \\ORDER BY id DESC
        \\LIMIT 8
        ,
        .{ workspace.id },
    );

    const runtime_logs = try db.query(
        WorkspaceRuntimeLogRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    action,
        \\    command_label,
        \\    exit_code,
        \\    succeeded,
        \\    stdout_excerpt,
        \\    stderr_excerpt
        \\FROM workspace_runtime_logs
        \\WHERE workspace_id = $1
        \\ORDER BY id DESC
        \\LIMIT 8
        ,
        .{ workspace.id },
    );

    const pane_session_history = try db.query(
        WorkspacePaneSessionHistoryRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    role_name,
        \\    previous_session_external_id,
        \\    replacement_session_external_id,
        \\    replacement_reason,
        \\    previous_session_agent_handle,
        \\    replacement_session_agent_handle,
        \\    TO_CHAR(created_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS') AS created_at_label
        \\FROM workspace_pane_session_history
        \\WHERE workspace_id = $1
        \\ORDER BY id DESC
        \\LIMIT 8
        ,
        .{ workspace.id },
    );

    const workspace_missions = try db.query(
        WorkspaceMissionPreviewRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.workspace_id,
        \\    w.name AS workspace_name,
        \\    m.squad_id,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name,
        \\    m.title,
        \\    m.objective,
        \\    m.status,
        \\    m.priority,
        \\    m.mission_operational_closure_status,
        \\    CASE
        \\        WHEN w.active_mission_id = m.id THEN TRUE
        \\        ELSE FALSE
        \\    END AS is_active_in_cockpit,
        \\    m.mission_final_verdict,
        \\    COALESCE(
        \\        TO_CHAR(m.mission_operational_closed_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS'),
        \\        'Ainda não encerrada'
        \\    ) AS mission_operational_closed_at_label
        \\FROM missions m
        \\INNER JOIN workspaces w ON w.id = m.workspace_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\WHERE m.workspace_id = $1
        \\ORDER BY
        \\    CASE WHEN w.active_mission_id = m.id THEN 0 ELSE 1 END,
        \\    m.id DESC
        ,
        .{ workspace.id },
    );

    const active_missions = try db.query(
        ActiveMissionPanelRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.workspace_id,
        \\    w.name AS workspace_name,
        \\    m.squad_id,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name,
        \\    m.title,
        \\    m.objective,
        \\    m.status,
        \\    m.priority,
        \\    m.pilot_dispatch_status,
        \\    m.pilot_session_external_id,
        \\    COALESCE(
        \\        TO_CHAR(m.dispatched_to_pilot_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS'),
        \\        'Ainda não enviado'
        \\    ) AS dispatched_to_pilot_at_label,
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
        \\FROM workspaces w
        \\INNER JOIN missions m ON m.id = w.active_mission_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\WHERE w.id = $1
        \\LIMIT 1
        ,
        .{ workspace.id },
    );

    const members = try db.query(
        SquadMemberRow,
        c.arena,
        \\SELECT
        \\    sm.id,
        \\    sm.squad_id,
        \\    sm.role_name,
        \\    sm.agent_id,
        \\    sm.display_order,
        \\    a.name AS agent_name,
        \\    a.handle AS agent_handle,
        \\    a.agent_role,
        \\    s.name AS stack_name
        \\FROM squad_members sm
        \\INNER JOIN agents a ON a.id = sm.agent_id
        \\INNER JOIN stacks s ON s.id = a.default_stack_id
        \\WHERE sm.squad_id = $1
        \\ORDER BY sm.display_order ASC
        ,
        .{ linked_squad_id },
    );

    if (linked_squad_id <= 0) {
        try db.query(
            void,
            c.arena,
            \\DELETE FROM workspace_panes
            \\WHERE workspace_id = $1
            ,
            .{ workspace.id },
        );
    } else {
        try db.query(
            void,
            c.arena,
            \\DELETE FROM workspace_panes wp
            \\WHERE wp.workspace_id = $1
            \\AND NOT EXISTS (
            \\    SELECT 1
            \\    FROM squad_members sm
            \\    WHERE sm.squad_id = $2
            \\    AND sm.role_name = wp.role_name
            \\)
            ,
            .{ workspace.id, linked_squad_id },
        );

        for (members) |member| {
            try db.query(
                void,
                c.arena,
                \\INSERT INTO workspace_panes (
                \\    workspace_id,
                \\    role_name,
                \\    squad_member_id,
                \\    agent_id,
                \\    pane_state,
                \\    session_external_id,
                \\    display_order
                \\)
                \\VALUES ($1, $2, $3, $4, 'idle', '', $5)
                \\ON CONFLICT (workspace_id, role_name)
                \\DO UPDATE SET
                \\    squad_member_id = EXCLUDED.squad_member_id,
                \\    agent_id = EXCLUDED.agent_id,
                \\    context_state = CASE
                \\        WHEN workspace_panes.session_external_id = '' THEN 'unbound'
                \\        WHEN workspace_panes.session_agent_id IS NULL THEN 'outdated'
                \\        WHEN workspace_panes.session_agent_id = EXCLUDED.agent_id THEN 'current'
                \\        ELSE 'outdated'
                \\    END,
                \\    display_order = EXCLUDED.display_order,
                \\    updated_at = NOW()
                ,
                .{
                    workspace.id,
                    member.role_name,
                    member.id,
                    member.agent_id,
                    member.display_order,
                },
            );
        }
    }

    const panes = try db.query(
        WorkspacePaneRow,
        c.arena,
        \\SELECT
        \\    wp.id,
        \\    wp.workspace_id,
        \\    wp.role_name,
        \\    wp.squad_member_id,
        \\    wp.agent_id,
        \\    wp.pane_state,
        \\    wp.session_external_id,
        \\    wp.session_agent_id,
        \\    wp.session_agent_handle,
        \\    wp.context_state,
        \\    wp.stale_reason,
        \\    wp.display_order,
        \\    a.name AS agent_name,
        \\    a.handle AS agent_handle,
        \\    a.agent_role,
        \\    s.name AS stack_name
        \\FROM workspace_panes wp
        \\INNER JOIN agents a ON a.id = wp.agent_id
        \\INNER JOIN stacks s ON s.id = a.default_stack_id
        \\WHERE wp.workspace_id = $1
        \\ORDER BY wp.display_order ASC
        ,
        .{ workspace.id },
    );

    return c.view("workspaces/show", .{
        .title = workspace.name,
        .workspace = workspace,
        .members = members,
        .member_count = members.len,
        .panes = panes,
        .pane_count = panes.len,
        .missions = workspace_missions,
        .mission_count = workspace_missions.len,
        .open_mission_count = countOpenWorkspaceMissions(workspace_missions),
        .closed_mission_count = countClosedWorkspaceMissions(workspace_missions),
        .active_missions = active_missions,
        .active_mission_count = active_missions.len,
        .runtime = refreshed_runtime_rows[0],
        .runtime_events = runtime_events,
        .runtime_event_count = runtime_events.len,
        .runtime_logs = runtime_logs,
        .runtime_log_count = runtime_logs.len,
        .pane_session_history = pane_session_history,
        .pane_session_history_count = pane_session_history.len,
        .notice =
            if (c.query("mission_created") != null)
                "Missão criada com sucesso e vinculada a este workspace."
            else
                "",
    }, .{});
}


fn workspaceCreate(c: *spider.Ctx) !spider.Response {
    const form = try c.parseForm(WorkspaceForm);
    const squads_rows = try loadWorkspaceSquads(c);
    const default_squad_id = std.fmt.parseInt(i32, form.default_squad_id, 10) catch 0;

    const duplicated = try db.query(
        WorkspaceIdRow,
        c.arena,
        \\SELECT id
        \\FROM workspaces
        \\WHERE local_path = $1
        \\LIMIT 1
        ,
        .{ form.local_path },
    );

    if (duplicated.len > 0) {
        return c.view("workspaces/new", .{
            .title = "Novo Workspace",
            .squads = squads_rows,
            .squad_count = squads_rows.len,
            .error_message = "Já existe um workspace cadastrado com este caminho local.",
            .form = form,
        }, .{ .status = .bad_request });
    }

    if (default_squad_id <= 0) {
        return c.view("workspaces/new", .{
            .title = "Novo Workspace",
            .squads = squads_rows,
            .squad_count = squads_rows.len,
            .error_message = "Selecione uma squad padrão válida para este workspace.",
            .form = form,
        }, .{ .status = .bad_request });
    }

    const squad_rows = try db.query(
        WorkspaceSquadOptionRow,
        c.arena,
        \\SELECT id, name, slug
        \\FROM squads
        \\WHERE id = $1
        \\AND is_active = TRUE
        \\LIMIT 1
        ,
        .{ default_squad_id },
    );

    if (squad_rows.len == 0) {
        return c.view("workspaces/new", .{
            .title = "Novo Workspace",
            .squads = squads_rows,
            .squad_count = squads_rows.len,
            .error_message = "A squad selecionada não está disponível.",
            .form = form,
        }, .{ .status = .bad_request });
    }

    if (!ensureWorkspaceLocalPath(c, form.local_path)) {
        return c.view("workspaces/new", .{
            .title = "Novo Workspace",
            .squads = squads_rows,
            .squad_count = squads_rows.len,
            .error_message = "Não foi possível criar ou acessar o caminho local informado para o workspace.",
            .form = form,
        }, .{ .status = .bad_request });
    }

    try db.query(
        void,
        c.arena,
        \\INSERT INTO workspaces (
        \\    name,
        \\    local_path,
        \\    stack_name,
        \\    default_squad,
        \\    default_squad_id
        \\)
        \\VALUES ($1, $2, $3, $4, $5)
        ,
        .{
            form.name,
            form.local_path,
            form.stack_name,
            squad_rows[0].name,
            default_squad_id,
        },
    );

    return c.redirect("/workspaces?created=1");
}

fn missions(c: *spider.Ctx) !spider.Response {
    const rows = try db.query(
        MissionRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.workspace_id,
        \\    w.name AS workspace_name,
        \\    m.squad_id,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name,
        \\    m.title,
        \\    m.objective,
        \\    m.status,
        \\    m.priority,
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
        \\    ) AS mission_operational_closed_at_label
        \\FROM missions m
        \\INNER JOIN workspaces w ON w.id = m.workspace_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\ORDER BY m.id DESC
        ,
        .{},
    );

    const notice =
        if (c.query("created") != null)
            "Missão cadastrada com sucesso."
        else if (c.query("updated") != null)
            "Missão atualizada com sucesso."
        else if (c.query("deleted") != null)
            "Missão removida com sucesso."
        else
            "";

    return c.view("missions/index", .{
        .title = "Missions",
        .missions = rows,
        .mission_count = rows.len,
        .open_count = countOpenMissions(rows),
        .notice = notice,
    }, .{});
}

fn countOpenMissions(rows: []const MissionRow) usize {
    var total: usize = 0;
    for (rows) |row| {
        if (!std.mem.eql(u8, row.mission_operational_closure_status, "closed")) {
            total += 1;
        }
    }
    return total;
}


fn countOpenWorkspaceMissions(rows: []const WorkspaceMissionPreviewRow) usize {
    var total: usize = 0;

    for (rows) |row| {
        if (!std.mem.eql(u8, row.mission_operational_closure_status, "closed")) {
            total += 1;
        }
    }

    return total;
}

fn countClosedWorkspaceMissions(rows: []const WorkspaceMissionPreviewRow) usize {
    var total: usize = 0;

    for (rows) |row| {
        if (std.mem.eql(u8, row.mission_operational_closure_status, "closed")) {
            total += 1;
        }
    }

    return total;
}

fn loadMissionWorkspaces(c: *spider.Ctx) ![]MissionWorkspaceOptionRow {
    return db.query(
        MissionWorkspaceOptionRow,
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

fn missionNew(c: *spider.Ctx) !spider.Response {
    const workspaces_rows = try loadMissionWorkspaces(c);

    return c.view("missions/new", .{
        .title = "Nova Missão",
        .workspaces = workspaces_rows,
        .workspace_count = workspaces_rows.len,
        .error_message = "",
        .form = .{
            .workspace_id = c.query("workspace_id") orelse "",
            .context_workspace_id = c.query("workspace_id") orelse "",
            .cancel_url =
                if (c.query("workspace_id")) |workspace_id|
                    try std.fmt.allocPrint(c.arena, "/workspaces/{s}", .{ workspace_id })
                else
                    "/missions",
            .title = "",
            .objective = "",
            .status = "briefing",
            .priority = "normal",
        },
    }, .{});
}

fn missionCreate(c: *spider.Ctx) !spider.Response {
    const form = try c.parseForm(MissionForm);
    const workspaces_rows = try loadMissionWorkspaces(c);
    const workspace_id = std.fmt.parseInt(i32, form.workspace_id, 10) catch 0;

    if (workspace_id <= 0) {
        return c.view("missions/new", .{
            .title = "Nova Missão",
            .workspaces = workspaces_rows,
            .workspace_count = workspaces_rows.len,
            .error_message = "Selecione um workspace válido.",
            .form = form,
        }, .{ .status = .bad_request });
    }

    const selected_workspace = try db.query(
        MissionWorkspaceOptionRow,
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
        .{ workspace_id },
    );

    if (selected_workspace.len == 0) {
        return c.view("missions/new", .{
            .title = "Nova Missão",
            .workspaces = workspaces_rows,
            .workspace_count = workspaces_rows.len,
            .error_message = "O workspace selecionado não possui uma squad válida vinculada.",
            .form = form,
        }, .{ .status = .bad_request });
    }

    const created_mission_rows = try db.query(
        MissionIdRow,
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
            selected_workspace[0].default_squad_id,
            form.title,
            form.objective,
            "briefing",
            form.priority,
        },
    );

    if (created_mission_rows.len == 0) {
        return c.text("Não foi possível confirmar a criação da missão.", .{ .status = .bad_request });
    }

    const created_mission_id = created_mission_rows[0].id;
    const context_workspace_id = std.fmt.parseInt(i32, form.context_workspace_id, 10) catch 0;

    if (context_workspace_id == workspace_id) {
        const active_rows = try db.query(
            MissionActivationTargetRow,
            c.arena,
            \\SELECT
            \\    m.id,
            \\    m.mission_operational_closure_status
            \\FROM workspaces w
            \\INNER JOIN missions m ON m.id = w.active_mission_id
            \\WHERE w.id = $1
            \\LIMIT 1
            ,
            .{ workspace_id },
        );

        const should_activate =
            active_rows.len == 0 or
            std.mem.eql(u8, active_rows[0].mission_operational_closure_status, "closed");

        if (should_activate) {
            try db.query(
                void,
                c.arena,
                \\UPDATE workspaces
                \\SET active_mission_id = $1
                \\WHERE id = $2
                ,
                .{ created_mission_id, workspace_id },
            );

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
                \\    'mission-activated-in-cockpit',
                \\    'Missão ativada no Cockpit',
                \\    'Esta missão foi criada a partir do workspace e definida automaticamente como foco operacional ativo.'
                \\)
                ,
                .{ created_mission_id, workspace_id },
            );
        }

        const redirect_url = try std.fmt.allocPrint(
            c.arena,
            "/workspaces/{d}?mission_created=1",
            .{ workspace_id },
        );

        return c.redirect(redirect_url);
    }

    return c.redirect("/missions?created=1");
}


fn missionCapturePilotOperationalBrief(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const mission_rows = try db.query(
        MissionRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.workspace_id,
        \\    w.name AS workspace_name,
        \\    m.squad_id,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name,
        \\    m.title,
        \\    m.objective,
        \\    m.status,
        \\    m.priority,
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
        \\    ) AS mission_operational_closed_at_label
        \\FROM missions m
        \\INNER JOIN workspaces w ON w.id = m.workspace_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\WHERE m.id = $1
        \\LIMIT 1
        ,
        .{ mission_id },
    );

    if (mission_rows.len == 0) {
        return c.text("Missão não encontrada.", .{ .status = .not_found });
    }

    const mission = mission_rows[0];

    if (std.mem.eql(u8, mission.mission_operational_closure_status, "closed")) {
        return c.text(
            "Missões encerradas operacionalmente não podem executar novas ações do ciclo operacional.",
            .{ .status = .bad_request },
        );
    }

    const pilot_rows = try db.query(
        WorkspaceMissionPaneDispatchRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    role_name,
        \\    pane_state,
        \\    session_external_id,
        \\    context_state
        \\FROM workspace_panes
        \\WHERE workspace_id = $1
        \\AND role_name = 'Piloto'
        \\LIMIT 1
        ,
        .{ mission.workspace_id },
    );

    if (pilot_rows.len == 0 or pilot_rows[0].session_external_id.len == 0) {
        return c.text("O pane Piloto não possui sessão disponível.", .{ .status = .bad_request });
    }

    const pilot = pilot_rows[0];

    const dispatch_trace_rows = try db.query(
        MissionPilotDispatchTraceRow,
        c.arena,
        \\SELECT pilot_dispatch_user_message_id
        \\FROM missions
        \\WHERE id = $1
        \\LIMIT 1
        ,
        .{ mission_id },
    );

    if (dispatch_trace_rows.len == 0 or dispatch_trace_rows[0].pilot_dispatch_user_message_id.len == 0) {
        return c.text(
            "Esta missão ainda não possui rastreio do despacho ao Piloto. Reenvie a missão ao Piloto antes de capturar o briefing.",
            .{ .status = .bad_request },
        );
    }

    const dispatch_trace = dispatch_trace_rows[0];
    const runtime_rows = try loadWorkspaceRuntime(c, mission.workspace_id);

    if (runtime_rows.len == 0) {
        return c.text("Runtime do workspace não encontrado.", .{ .status = .bad_request });
    }

    try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try loadWorkspaceRuntime(c, mission.workspace_id);
    if (refreshed_runtime_rows.len == 0) {
        return c.text("Runtime indisponível após reconciliação.", .{ .status = .bad_request });
    }

    const runtime = refreshed_runtime_rows[0];

    if (!std.mem.eql(u8, runtime.state, "running")) {
        return c.text("O runtime precisa estar em execução para capturar o briefing.", .{ .status = .bad_request });
    }

    const messages_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/message",
        .{ runtime.server_url_label, pilot.session_external_id },
    );

    const messages_result = runRuntimeCommand(c, &.{
        "curl",
        "-fsS",
        messages_url,
    });

    try insertRuntimeCommandLog(
        c,
        mission.workspace_id,
        "opencode-fetch-pilot-session-messages",
        "GET <opencode-server>/session/<session-id>/message",
        messages_result,
    );

    if (!messages_result.ok) {
        return c.text("Falha ao consultar mensagens da sessão do Piloto.", .{ .status = .bad_request });
    }

    const brief_text = try extractAssistantTextForParentMessage(
        c.arena,
        messages_result.stdout,
        dispatch_trace.pilot_dispatch_user_message_id,
    ) orelse {
        return c.text(
            "Nenhuma resposta textual vinculada ao último despacho rastreado foi encontrada. Aguarde o Piloto concluir a resposta e tente novamente.",
            .{ .status = .bad_request },
        );
    };

    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET pilot_operational_brief = $1,
        \\    pilot_operational_brief_status = 'captured',
        \\    pilot_operational_brief_captured_at = NOW()
        \\WHERE id = $2
        ,
        .{ brief_text, mission_id },
    );

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Briefing Operacional do Piloto foi capturado a partir da sessão {s}.",
        .{ pilot.session_external_id },
    );

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
        \\    'pilot-operational-brief-captured',
        \\    'Briefing do Piloto capturado',
        \\    $3
        \\)
        ,
        .{ mission_id, mission.workspace_id, event_message },
    );

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}",
        .{ mission_id },
    );

    return c.redirect(redirect_url);
}


fn missionCapturePlannerOperationalPlan(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const mission_rows = try db.query(
        MissionRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.workspace_id,
        \\    w.name AS workspace_name,
        \\    m.squad_id,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name,
        \\    m.title,
        \\    m.objective,
        \\    m.status,
        \\    m.priority,
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
        \\    ) AS mission_operational_closed_at_label
        \\FROM missions m
        \\INNER JOIN workspaces w ON w.id = m.workspace_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\WHERE m.id = $1
        \\LIMIT 1
        ,
        .{ mission_id },
    );

    if (mission_rows.len == 0) {
        return c.text("Missão não encontrada.", .{ .status = .not_found });
    }

    const mission = mission_rows[0];

    if (std.mem.eql(u8, mission.mission_operational_closure_status, "closed")) {
        return c.text(
            "Missões encerradas operacionalmente não podem executar novas ações do ciclo operacional.",
            .{ .status = .bad_request },
        );
    }

    const planner_rows = try db.query(
        WorkspaceMissionPaneDispatchRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    role_name,
        \\    pane_state,
        \\    session_external_id,
        \\    context_state
        \\FROM workspace_panes
        \\WHERE workspace_id = $1
        \\AND role_name = 'Planner'
        \\LIMIT 1
        ,
        .{ mission.workspace_id },
    );

    if (planner_rows.len == 0 or planner_rows[0].session_external_id.len == 0) {
        return c.text(
            "O pane Planner não possui sessão disponível.",
            .{ .status = .bad_request },
        );
    }

    const planner = planner_rows[0];

    const dispatch_trace_rows = try db.query(
        MissionPlannerDispatchTraceRow,
        c.arena,
        \\SELECT planner_dispatch_user_message_id
        \\FROM missions
        \\WHERE id = $1
        \\LIMIT 1
        ,
        .{ mission_id },
    );

    if (
        dispatch_trace_rows.len == 0 or
        dispatch_trace_rows[0].planner_dispatch_user_message_id.len == 0
    ) {
        return c.text(
            "Esta missão ainda não possui rastreio do despacho ao Planner. Reenvie o briefing antes de capturar o plano.",
            .{ .status = .bad_request },
        );
    }

    const dispatch_trace = dispatch_trace_rows[0];
    const runtime_rows = try loadWorkspaceRuntime(c, mission.workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "Runtime do workspace não encontrado.",
            .{ .status = .bad_request },
        );
    }

    try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try loadWorkspaceRuntime(c, mission.workspace_id);
    if (refreshed_runtime_rows.len == 0) {
        return c.text(
            "Runtime indisponível após reconciliação.",
            .{ .status = .bad_request },
        );
    }

    const runtime = refreshed_runtime_rows[0];

    if (!std.mem.eql(u8, runtime.state, "running")) {
        return c.text(
            "O runtime precisa estar em execução para capturar o plano do Planner.",
            .{ .status = .bad_request },
        );
    }

    const messages_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/message",
        .{ runtime.server_url_label, planner.session_external_id },
    );

    const messages_result = runRuntimeCommand(c, &.{
        "curl",
        "-fsS",
        messages_url,
    });

    try insertRuntimeCommandLog(
        c,
        mission.workspace_id,
        "opencode-fetch-planner-session-messages",
        "GET <opencode-server>/session/<session-id>/message",
        messages_result,
    );

    if (!messages_result.ok) {
        return c.text(
            "Falha ao consultar mensagens da sessão do Planner.",
            .{ .status = .bad_request },
        );
    }

    const plan_text = try extractAssistantTextForParentMessage(
        c.arena,
        messages_result.stdout,
        dispatch_trace.planner_dispatch_user_message_id,
    ) orelse {
        return c.text(
            "Nenhuma resposta textual vinculada ao último despacho rastreado foi encontrada. Aguarde o Planner concluir a resposta e tente novamente.",
            .{ .status = .bad_request },
        );
    };

    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET planner_operational_plan = $1,
        \\    planner_operational_plan_status = 'captured',
        \\    planner_operational_plan_captured_at = NOW(),
        \\    status = 'planned'
        \\WHERE id = $2
        ,
        .{ plan_text, mission_id },
    );

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Plano Operacional do Planner foi capturado a partir da sessão {s}.",
        .{ planner.session_external_id },
    );

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
        \\    'planner-operational-plan-captured',
        \\    'Plano do Planner capturado',
        \\    $3
        \\)
        ,
        .{ mission_id, mission.workspace_id, event_message },
    );

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}",
        .{ mission_id },
    );

    return c.redirect(redirect_url);
}


fn missionCaptureScoutReport(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const mission_rows = try db.query(
        MissionRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.workspace_id,
        \\    w.name AS workspace_name,
        \\    m.squad_id,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name,
        \\    m.title,
        \\    m.objective,
        \\    m.status,
        \\    m.priority,
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
        \\    ) AS mission_operational_closed_at_label
        \\FROM missions m
        \\INNER JOIN workspaces w ON w.id = m.workspace_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\WHERE m.id = $1
        \\LIMIT 1
        ,
        .{ mission_id },
    );

    if (mission_rows.len == 0) {
        return c.text("Missão não encontrada.", .{ .status = .not_found });
    }

    const mission = mission_rows[0];

    if (std.mem.eql(u8, mission.mission_operational_closure_status, "closed")) {
        return c.text(
            "Missões encerradas operacionalmente não podem executar novas ações do ciclo operacional.",
            .{ .status = .bad_request },
        );
    }

    const scout_rows = try db.query(
        WorkspaceMissionPaneDispatchRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    role_name,
        \\    pane_state,
        \\    session_external_id,
        \\    context_state
        \\FROM workspace_panes
        \\WHERE workspace_id = $1
        \\AND role_name = 'Scout'
        \\LIMIT 1
        ,
        .{ mission.workspace_id },
    );

    if (scout_rows.len == 0 or scout_rows[0].session_external_id.len == 0) {
        return c.text(
            "O pane Scout não possui sessão disponível.",
            .{ .status = .bad_request },
        );
    }

    const scout = scout_rows[0];

    const dispatch_trace_rows = try db.query(
        MissionScoutDispatchTraceRow,
        c.arena,
        \\SELECT scout_dispatch_user_message_id
        \\FROM missions
        \\WHERE id = $1
        \\LIMIT 1
        ,
        .{ mission_id },
    );

    if (
        dispatch_trace_rows.len == 0 or
        dispatch_trace_rows[0].scout_dispatch_user_message_id.len == 0
    ) {
        return c.text(
            "Esta missão ainda não possui rastreio do despacho ao Scout. Reenvie o plano ao Scout antes de capturar o relatório.",
            .{ .status = .bad_request },
        );
    }

    const dispatch_trace = dispatch_trace_rows[0];
    const runtime_rows = try loadWorkspaceRuntime(c, mission.workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "Runtime do workspace não encontrado.",
            .{ .status = .bad_request },
        );
    }

    try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try loadWorkspaceRuntime(c, mission.workspace_id);
    if (refreshed_runtime_rows.len == 0) {
        return c.text(
            "Runtime indisponível após reconciliação.",
            .{ .status = .bad_request },
        );
    }

    const runtime = refreshed_runtime_rows[0];

    if (!std.mem.eql(u8, runtime.state, "running")) {
        return c.text(
            "O runtime precisa estar em execução para capturar o Scout Report.",
            .{ .status = .bad_request },
        );
    }

    const messages_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/message",
        .{ runtime.server_url_label, scout.session_external_id },
    );

    const messages_result = runRuntimeCommand(c, &.{
        "curl",
        "-fsS",
        messages_url,
    });

    try insertRuntimeCommandLog(
        c,
        mission.workspace_id,
        "opencode-fetch-scout-session-messages",
        "GET <opencode-server>/session/<session-id>/message",
        messages_result,
    );

    if (!messages_result.ok) {
        return c.text(
            "Falha ao consultar mensagens da sessão do Scout.",
            .{ .status = .bad_request },
        );
    }

    const scout_report_text = try extractAssistantTextForParentMessage(
        c.arena,
        messages_result.stdout,
        dispatch_trace.scout_dispatch_user_message_id,
    ) orelse {
        return c.text(
            "Nenhuma resposta textual vinculada ao último despacho rastreado foi encontrada. Aguarde o Scout concluir a resposta e tente novamente.",
            .{ .status = .bad_request },
        );
    };

    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET scout_report = $1,
        \\    scout_report_status = 'captured',
        \\    scout_report_captured_at = NOW()
        \\WHERE id = $2
        ,
        .{ scout_report_text, mission_id },
    );

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Scout Report foi capturado a partir da sessão {s}.",
        .{ scout.session_external_id },
    );

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
        \\    'scout-report-captured',
        \\    'Scout Report capturado',
        \\    $3
        \\)
        ,
        .{ mission_id, mission.workspace_id, event_message },
    );

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}",
        .{ mission_id },
    );

    return c.redirect(redirect_url);
}


fn missionCaptureBuilderImplementationReport(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const mission_rows = try db.query(
        MissionRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.workspace_id,
        \\    w.name AS workspace_name,
        \\    m.squad_id,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name,
        \\    m.title,
        \\    m.objective,
        \\    m.status,
        \\    m.priority,
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
        \\    ) AS mission_operational_closed_at_label
        \\FROM missions m
        \\INNER JOIN workspaces w ON w.id = m.workspace_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\WHERE m.id = $1
        \\LIMIT 1
        ,
        .{ mission_id },
    );

    if (mission_rows.len == 0) {
        return c.text("Missão não encontrada.", .{ .status = .not_found });
    }

    const mission = mission_rows[0];

    if (std.mem.eql(u8, mission.mission_operational_closure_status, "closed")) {
        return c.text(
            "Missões encerradas operacionalmente não podem executar novas ações do ciclo operacional.",
            .{ .status = .bad_request },
        );
    }

    const builder_rows = try db.query(
        WorkspaceMissionPaneDispatchRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    role_name,
        \\    pane_state,
        \\    session_external_id,
        \\    context_state
        \\FROM workspace_panes
        \\WHERE workspace_id = $1
        \\AND role_name = 'Builder'
        \\LIMIT 1
        ,
        .{ mission.workspace_id },
    );

    if (builder_rows.len == 0 or builder_rows[0].session_external_id.len == 0) {
        return c.text(
            "O pane Builder não possui sessão disponível.",
            .{ .status = .bad_request },
        );
    }

    const builder = builder_rows[0];

    const dispatch_trace_rows = try db.query(
        MissionBuilderDispatchTraceRow,
        c.arena,
        \\SELECT builder_dispatch_user_message_id
        \\FROM missions
        \\WHERE id = $1
        \\LIMIT 1
        ,
        .{ mission_id },
    );

    if (
        dispatch_trace_rows.len == 0 or
        dispatch_trace_rows[0].builder_dispatch_user_message_id.len == 0
    ) {
        return c.text(
            "Esta missão ainda não possui rastreio do despacho ao Builder. Reenvie o pacote antes de capturar o Implementation Report.",
            .{ .status = .bad_request },
        );
    }

    const dispatch_trace = dispatch_trace_rows[0];
    const runtime_rows = try loadWorkspaceRuntime(c, mission.workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "Runtime do workspace não encontrado.",
            .{ .status = .bad_request },
        );
    }

    try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try loadWorkspaceRuntime(c, mission.workspace_id);
    if (refreshed_runtime_rows.len == 0) {
        return c.text(
            "Runtime indisponível após reconciliação.",
            .{ .status = .bad_request },
        );
    }

    const runtime = refreshed_runtime_rows[0];

    if (!std.mem.eql(u8, runtime.state, "running")) {
        return c.text(
            "O runtime precisa estar em execução para capturar o Implementation Report.",
            .{ .status = .bad_request },
        );
    }

    const messages_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/message",
        .{ runtime.server_url_label, builder.session_external_id },
    );

    const messages_result = runRuntimeCommand(c, &.{
        "curl",
        "-fsS",
        messages_url,
    });

    try insertRuntimeCommandLog(
        c,
        mission.workspace_id,
        "opencode-fetch-builder-session-messages",
        "GET <opencode-server>/session/<session-id>/message",
        messages_result,
    );

    if (!messages_result.ok) {
        return c.text(
            "Falha ao consultar mensagens da sessão do Builder.",
            .{ .status = .bad_request },
        );
    }

    const implementation_report_text = try extractAssistantTextForParentMessage(
        c.arena,
        messages_result.stdout,
        dispatch_trace.builder_dispatch_user_message_id,
    ) orelse {
        return c.text(
            "Nenhuma resposta textual vinculada ao último despacho rastreado foi encontrada. Aguarde o Builder concluir a resposta e tente novamente.",
            .{ .status = .bad_request },
        );
    };

    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET builder_implementation_report = $1,
        \\    builder_implementation_report_status = 'captured',
        \\    builder_implementation_report_captured_at = NOW()
        \\WHERE id = $2
        ,
        .{ implementation_report_text, mission_id },
    );

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Implementation Report do Builder foi capturado a partir da sessão {s}.",
        .{ builder.session_external_id },
    );

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
        \\    'builder-implementation-report-captured',
        \\    'Implementation Report capturado',
        \\    $3
        \\)
        ,
        .{ mission_id, mission.workspace_id, event_message },
    );

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}",
        .{ mission_id },
    );

    return c.redirect(redirect_url);
}


fn missionCaptureReviewerReviewReport(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const mission_rows = try db.query(
        MissionRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.workspace_id,
        \\    w.name AS workspace_name,
        \\    m.squad_id,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name,
        \\    m.title,
        \\    m.objective,
        \\    m.status,
        \\    m.priority,
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
        \\    ) AS mission_operational_closed_at_label
        \\FROM missions m
        \\INNER JOIN workspaces w ON w.id = m.workspace_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\WHERE m.id = $1
        \\LIMIT 1
        ,
        .{ mission_id },
    );

    if (mission_rows.len == 0) {
        return c.text("Missão não encontrada.", .{ .status = .not_found });
    }

    const mission = mission_rows[0];

    if (std.mem.eql(u8, mission.mission_operational_closure_status, "closed")) {
        return c.text(
            "Missões encerradas operacionalmente não podem executar novas ações do ciclo operacional.",
            .{ .status = .bad_request },
        );
    }

    const reviewer_rows = try db.query(
        WorkspaceMissionPaneDispatchRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    role_name,
        \\    pane_state,
        \\    session_external_id,
        \\    context_state
        \\FROM workspace_panes
        \\WHERE workspace_id = $1
        \\AND role_name = 'Reviewer'
        \\LIMIT 1
        ,
        .{ mission.workspace_id },
    );

    if (reviewer_rows.len == 0 or reviewer_rows[0].session_external_id.len == 0) {
        return c.text(
            "O pane Reviewer não possui sessão disponível.",
            .{ .status = .bad_request },
        );
    }

    const reviewer = reviewer_rows[0];

    const dispatch_trace_rows = try db.query(
        MissionReviewerDispatchTraceRow,
        c.arena,
        \\SELECT reviewer_dispatch_user_message_id
        \\FROM missions
        \\WHERE id = $1
        \\LIMIT 1
        ,
        .{ mission_id },
    );

    if (
        dispatch_trace_rows.len == 0 or
        dispatch_trace_rows[0].reviewer_dispatch_user_message_id.len == 0
    ) {
        return c.text(
            "Esta missão ainda não possui rastreio do despacho ao Reviewer. Reenvie o relatório antes de capturar o review.",
            .{ .status = .bad_request },
        );
    }

    const dispatch_trace = dispatch_trace_rows[0];
    const runtime_rows = try loadWorkspaceRuntime(c, mission.workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "Runtime do workspace não encontrado.",
            .{ .status = .bad_request },
        );
    }

    try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try loadWorkspaceRuntime(c, mission.workspace_id);

    if (refreshed_runtime_rows.len == 0) {
        return c.text(
            "Runtime indisponível após reconciliação.",
            .{ .status = .bad_request },
        );
    }

    const runtime = refreshed_runtime_rows[0];

    if (!std.mem.eql(u8, runtime.state, "running")) {
        return c.text(
            "O runtime precisa estar em execução para capturar o Review Report.",
            .{ .status = .bad_request },
        );
    }

    const messages_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/message",
        .{ runtime.server_url_label, reviewer.session_external_id },
    );

    const messages_result = runRuntimeCommand(c, &.{
        "curl",
        "-fsS",
        messages_url,
    });

    try insertRuntimeCommandLog(
        c,
        mission.workspace_id,
        "opencode-fetch-reviewer-session-messages",
        "GET <opencode-server>/session/<session-id>/message",
        messages_result,
    );

    if (!messages_result.ok) {
        return c.text(
            "Falha ao consultar mensagens da sessão do Reviewer.",
            .{ .status = .bad_request },
        );
    }

    const review_text = try extractAssistantTextForParentMessage(
        c.arena,
        messages_result.stdout,
        dispatch_trace.reviewer_dispatch_user_message_id,
    ) orelse {
        return c.text(
            "Nenhuma resposta textual vinculada ao último despacho rastreado foi encontrada. Aguarde o Reviewer concluir a resposta e tente novamente.",
            .{ .status = .bad_request },
        );
    };

    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET reviewer_review_report = $1,
        \\    reviewer_review_report_status = 'captured',
        \\    reviewer_review_report_captured_at = NOW()
        \\WHERE id = $2
        ,
        .{ review_text, mission_id },
    );

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Review Report do Reviewer foi capturado a partir da sessão {s}.",
        .{ reviewer.session_external_id },
    );

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
        \\    'reviewer-review-report-captured',
        \\    'Review Report do Reviewer capturado',
        \\    $3
        \\)
        ,
        .{ mission_id, mission.workspace_id, event_message },
    );

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}",
        .{ mission_id },
    );

    return c.redirect(redirect_url);
}


fn missionCaptureExecutorVerificationReport(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const mission_rows = try db.query(
        MissionRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.workspace_id,
        \\    w.name AS workspace_name,
        \\    m.squad_id,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name,
        \\    m.title,
        \\    m.objective,
        \\    m.status,
        \\    m.priority,
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
        \\    ) AS mission_operational_closed_at_label
        \\FROM missions m
        \\INNER JOIN workspaces w ON w.id = m.workspace_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\WHERE m.id = $1
        \\LIMIT 1
        ,
        .{ mission_id },
    );

    if (mission_rows.len == 0) {
        return c.text("Missão não encontrada.", .{ .status = .not_found });
    }

    const mission = mission_rows[0];

    if (std.mem.eql(u8, mission.mission_operational_closure_status, "closed")) {
        return c.text(
            "Missões encerradas operacionalmente não podem executar novas ações do ciclo operacional.",
            .{ .status = .bad_request },
        );
    }

    const executor_rows = try db.query(
        WorkspaceMissionPaneDispatchRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    role_name,
        \\    pane_state,
        \\    session_external_id,
        \\    context_state
        \\FROM workspace_panes
        \\WHERE workspace_id = $1
        \\AND role_name = 'Executor'
        \\LIMIT 1
        ,
        .{ mission.workspace_id },
    );

    if (executor_rows.len == 0 or executor_rows[0].session_external_id.len == 0) {
        return c.text(
            "O pane Executor não possui sessão disponível.",
            .{ .status = .bad_request },
        );
    }

    const executor = executor_rows[0];

    const dispatch_trace_rows = try db.query(
        MissionExecutorDispatchTraceRow,
        c.arena,
        \\SELECT executor_dispatch_user_message_id
        \\FROM missions
        \\WHERE id = $1
        \\LIMIT 1
        ,
        .{ mission_id },
    );

    if (
        dispatch_trace_rows.len == 0 or
        dispatch_trace_rows[0].executor_dispatch_user_message_id.len == 0
    ) {
        return c.text(
            "Esta missão ainda não possui rastreio do despacho ao Executor. Reenvie o Review Report antes de capturar a verificação.",
            .{ .status = .bad_request },
        );
    }

    const dispatch_trace = dispatch_trace_rows[0];
    const runtime_rows = try loadWorkspaceRuntime(c, mission.workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "Runtime do workspace não encontrado.",
            .{ .status = .bad_request },
        );
    }

    try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try loadWorkspaceRuntime(c, mission.workspace_id);

    if (refreshed_runtime_rows.len == 0) {
        return c.text(
            "Runtime indisponível após reconciliação.",
            .{ .status = .bad_request },
        );
    }

    const runtime = refreshed_runtime_rows[0];

    if (!std.mem.eql(u8, runtime.state, "running")) {
        return c.text(
            "O runtime precisa estar em execução para capturar o Verification Report do Executor.",
            .{ .status = .bad_request },
        );
    }

    const messages_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/message",
        .{ runtime.server_url_label, executor.session_external_id },
    );

    const messages_result = runRuntimeCommand(c, &.{
        "curl",
        "-fsS",
        messages_url,
    });

    try insertRuntimeCommandLog(
        c,
        mission.workspace_id,
        "opencode-fetch-executor-session-messages",
        "GET <opencode-server>/session/<session-id>/message",
        messages_result,
    );

    if (!messages_result.ok) {
        return c.text(
            "Falha ao consultar mensagens da sessão do Executor.",
            .{ .status = .bad_request },
        );
    }

    const verification_report_text = try extractAssistantTextForParentMessage(
        c.arena,
        messages_result.stdout,
        dispatch_trace.executor_dispatch_user_message_id,
    ) orelse {
        return c.text(
            "Nenhuma resposta textual vinculada ao último despacho rastreado foi encontrada. Aguarde o Executor concluir a resposta e tente novamente.",
            .{ .status = .bad_request },
        );
    };

    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET executor_verification_report = $1,
        \\    executor_verification_report_status = 'captured',
        \\    executor_verification_report_captured_at = NOW()
        \\WHERE id = $2
        ,
        .{ verification_report_text, mission_id },
    );

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Verification Report do Executor foi capturado a partir da sessão {s}.",
        .{ executor.session_external_id },
    );

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
        \\    'executor-verification-report-captured',
        \\    'Verification Report do Executor capturado',
        \\    $3
        \\)
        ,
        .{ mission_id, mission.workspace_id, event_message },
    );

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}",
        .{ mission_id },
    );

    return c.redirect(redirect_url);
}



fn missionCapturePilotDeliveryReport(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const mission_rows = try db.query(
        MissionRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.workspace_id,
        \\    w.name AS workspace_name,
        \\    m.squad_id,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name,
        \\    m.title,
        \\    m.objective,
        \\    m.status,
        \\    m.priority,
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
        \\    ) AS mission_operational_closed_at_label
        \\FROM missions m
        \\INNER JOIN workspaces w ON w.id = m.workspace_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\WHERE m.id = $1
        \\LIMIT 1
        ,
        .{ mission_id },
    );

    if (mission_rows.len == 0) {
        return c.text("Missão não encontrada.", .{ .status = .not_found });
    }

    const mission = mission_rows[0];

    if (std.mem.eql(u8, mission.mission_operational_closure_status, "closed")) {
        return c.text(
            "Missões encerradas operacionalmente não podem executar novas ações do ciclo operacional.",
            .{ .status = .bad_request },
        );
    }

    const pilot_rows = try db.query(
        WorkspaceMissionPaneDispatchRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    role_name,
        \\    pane_state,
        \\    session_external_id,
        \\    context_state
        \\FROM workspace_panes
        \\WHERE workspace_id = $1
        \\AND role_name = 'Piloto'
        \\LIMIT 1
        ,
        .{ mission.workspace_id },
    );

    if (pilot_rows.len == 0 or pilot_rows[0].session_external_id.len == 0) {
        return c.text(
            "O pane Piloto não possui sessão disponível.",
            .{ .status = .bad_request },
        );
    }

    const pilot = pilot_rows[0];

    const dispatch_trace_rows = try db.query(
        MissionPilotDeliveryDispatchTraceRow,
        c.arena,
        \\SELECT pilot_delivery_dispatch_user_message_id
        \\FROM missions
        \\WHERE id = $1
        \\LIMIT 1
        ,
        .{ mission_id },
    );

    if (
        dispatch_trace_rows.len == 0 or
        dispatch_trace_rows[0].pilot_delivery_dispatch_user_message_id.len == 0
    ) {
        return c.text(
            "Esta missão ainda não possui rastreio do despacho final ao Piloto. Reenvie o Verification Report antes de capturar a entrega.",
            .{ .status = .bad_request },
        );
    }

    const dispatch_trace = dispatch_trace_rows[0];
    const runtime_rows = try loadWorkspaceRuntime(c, mission.workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "Runtime do workspace não encontrado.",
            .{ .status = .bad_request },
        );
    }

    try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try loadWorkspaceRuntime(c, mission.workspace_id);

    if (refreshed_runtime_rows.len == 0) {
        return c.text(
            "Runtime indisponível após reconciliação.",
            .{ .status = .bad_request },
        );
    }

    const runtime = refreshed_runtime_rows[0];

    if (!std.mem.eql(u8, runtime.state, "running")) {
        return c.text(
            "O runtime precisa estar em execução para capturar o Final Delivery Report.",
            .{ .status = .bad_request },
        );
    }

    const messages_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/message",
        .{ runtime.server_url_label, pilot.session_external_id },
    );

    const messages_result = runRuntimeCommand(c, &.{
        "curl",
        "-fsS",
        messages_url,
    });

    try insertRuntimeCommandLog(
        c,
        mission.workspace_id,
        "opencode-fetch-pilot-delivery-session-messages",
        "GET <opencode-server>/session/<session-id>/message",
        messages_result,
    );

    if (!messages_result.ok) {
        return c.text(
            "Falha ao consultar mensagens da sessão do Piloto.",
            .{ .status = .bad_request },
        );
    }

    const delivery_text = try extractAssistantTextForParentMessage(
        c.arena,
        messages_result.stdout,
        dispatch_trace.pilot_delivery_dispatch_user_message_id,
    ) orelse {
        return c.text(
            "Nenhuma resposta textual vinculada ao último despacho final foi encontrada. Aguarde o Piloto concluir a entrega e tente novamente.",
            .{ .status = .bad_request },
        );
    };

    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET pilot_delivery_report = $1,
        \\    pilot_delivery_report_status = 'captured',
        \\    pilot_delivery_report_captured_at = NOW()
        \\WHERE id = $2
        ,
        .{ delivery_text, mission_id },
    );

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Final Delivery Report do Piloto foi capturado a partir da sessão {s}.",
        .{ pilot.session_external_id },
    );

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
        \\    'pilot-delivery-report-captured',
        \\    'Final Delivery Report do Piloto capturado',
        \\    $3
        \\)
        ,
        .{ mission_id, mission.workspace_id, event_message },
    );

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}",
        .{ mission_id },
    );

    return c.redirect(redirect_url);
}


fn missionFinalizeFromPilotDeliveryReport(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const rows = try db.query(
        MissionClosureFinalizeRow,
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
        .{ mission_id },
    );

    if (rows.len == 0) {
        return c.text("Missão não encontrada.", .{ .status = .not_found });
    }

    const mission = rows[0];

    if (
        mission.pilot_delivery_report.len == 0 or
        !std.mem.eql(u8, mission.pilot_delivery_report_status, "captured")
    ) {
        return c.text(
            "Capture o Final Delivery Report do Piloto antes de encerrar a missão.",
            .{ .status = .bad_request },
        );
    }

    if (std.mem.eql(u8, mission.mission_operational_closure_status, "closed")) {
        const redirect_url = try std.fmt.allocPrint(
            c.arena,
            "/missions/{d}",
            .{ mission_id },
        );

        return c.redirect(redirect_url);
    }

    const final_verdict = extractMissionFinalVerdictFromPilotDeliveryReport(
        mission.pilot_delivery_report,
    );

    if (final_verdict.len == 0) {
        return c.text(
            "Não foi possível identificar automaticamente o status final da missão no Final Delivery Report. O relatório precisa declarar explicitamente: completed, needs_follow_up ou blocked.",
            .{ .status = .bad_request },
        );
    }

    const formal_mission_status =
        if (std.mem.eql(u8, final_verdict, "completed"))
            "completed"
        else if (std.mem.eql(u8, final_verdict, "needs_follow_up"))
            "needs_follow_up"
        else
            "blocked";

    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET mission_final_verdict = $1,
        \\    mission_operational_closure_status = 'closed',
        \\    mission_operational_closed_at = NOW(),
        \\    status = $2
        \\WHERE id = $3
        ,
        .{ final_verdict, formal_mission_status, mission_id },
    );

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "A missão \"{s}\" foi encerrada operacionalmente pelo Cockpit com veredito final: {s}.",
        .{ mission.title, final_verdict },
    );

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
        \\    'mission-operationally-closed',
        \\    'Missão encerrada pelo Cockpit',
        \\    $3
        \\)
        ,
        .{ mission_id, mission.workspace_id, event_message },
    );

    try db.query(
        void,
        c.arena,
        \\UPDATE workspaces
        \\SET active_mission_id = NULL
        \\WHERE id = $1
        \\AND active_mission_id = $2
        ,
        .{ mission.workspace_id, mission_id },
    );

    const release_event_message = try std.fmt.allocPrint(
        c.arena,
        "A missão \"{s}\" foi removida do foco ativo do workspace após o encerramento operacional.",
        .{ mission.title },
    );

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
        \\    'mission-released-from-workspace-focus',
        \\    'Missão removida do foco ativo',
        \\    $3
        \\)
        ,
        .{ mission_id, mission.workspace_id, release_event_message },
    );

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}",
        .{ mission_id },
    );

    return c.redirect(redirect_url);
}


fn missionShow(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const rows = try db.query(
        MissionRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.workspace_id,
        \\    w.name AS workspace_name,
        \\    m.squad_id,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name,
        \\    m.title,
        \\    m.objective,
        \\    m.status,
        \\    m.priority,
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
        \\    ) AS mission_operational_closed_at_label
        \\FROM missions m
        \\INNER JOIN workspaces w ON w.id = m.workspace_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\WHERE m.id = $1
        \\LIMIT 1
        ,
        .{ mission_id },
    );

    if (rows.len == 0) {
        return c.text("Missão não encontrada.", .{ .status = .not_found });
    }

    const mission_events = try db.query(
        MissionEventRow,
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
        .{ mission_id },
    );

    return c.view("missions/show", .{
        .title = rows[0].title,
        .mission = rows[0],
        .mission_events = mission_events,
        .mission_event_count = mission_events.len,
    }, .{});
}

fn missionEdit(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const rows = try db.query(
        MissionRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.workspace_id,
        \\    w.name AS workspace_name,
        \\    m.squad_id,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name,
        \\    m.title,
        \\    m.objective,
        \\    m.status,
        \\    m.priority,
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
        \\    ) AS mission_operational_closed_at_label
        \\FROM missions m
        \\INNER JOIN workspaces w ON w.id = m.workspace_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\WHERE m.id = $1
        \\LIMIT 1
        ,
        .{ mission_id },
    );

    if (rows.len == 0) {
        return c.text("Missão não encontrada.", .{ .status = .not_found });
    }

    return c.view("missions/edit", .{
        .title = "Editar Missão",
        .mission = rows[0],
        .error_message = "",
    }, .{});
}

fn missionUpdate(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const form = try c.parseForm(MissionUpdateForm);

    const current_rows = try db.query(
        MissionRow,
        c.arena,
        \\SELECT
        \\    m.id,
        \\    m.workspace_id,
        \\    w.name AS workspace_name,
        \\    m.squad_id,
        \\    COALESCE(s.name, 'Squad não localizada') AS squad_name,
        \\    m.title,
        \\    m.objective,
        \\    m.status,
        \\    m.priority,
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
        \\    ) AS mission_operational_closed_at_label
        \\FROM missions m
        \\INNER JOIN workspaces w ON w.id = m.workspace_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\WHERE m.id = $1
        \\LIMIT 1
        ,
        .{ mission_id },
    );

    if (current_rows.len == 0) {
        return c.text("Missão não encontrada.", .{ .status = .not_found });
    }

    if (std.mem.eql(u8, current_rows[0].mission_operational_closure_status, "closed")) {
        return c.text(
            "Missões encerradas operacionalmente não podem ser editadas.",
            .{ .status = .bad_request },
        );
    }

    try db.query(
        void,
        c.arena,
        \\UPDATE missions
        \\SET title = $1,
        \\    objective = $2,
        \\    status = $3,
        \\    priority = $4
        \\WHERE id = $5
        ,
        .{
            form.title,
            form.objective,
            current_rows[0].status,
            form.priority,
            mission_id,
        },
    );

    return c.redirect("/missions?updated=1");
}

fn missionDelete(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const mission_rows = try db.query(
        MissionClosureFinalizeRow,
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
        .{ mission_id },
    );

    if (mission_rows.len == 0) {
        return c.text("Missão não encontrada.", .{ .status = .not_found });
    }

    if (std.mem.eql(u8, mission_rows[0].mission_operational_closure_status, "closed")) {
        return c.text(
            "Missões encerradas operacionalmente não podem ser excluídas.",
            .{ .status = .bad_request },
        );
    }

    try db.query(
        void,
        c.arena,
        \\DELETE FROM missions
        \\WHERE id = $1
        ,
        .{ mission_id },
    );

    return c.redirect("/missions?deleted=1");
}

fn agents(c: *spider.Ctx) !spider.Response {
    const rows = try db.query(
        AgentRow,
        c.arena,
        \\SELECT
        \\    a.id,
        \\    a.name,
        \\    a.handle,
        \\    a.agent_role,
        \\    a.summary,
        \\    a.system_prompt,
        \\    a.operating_rules,
        \\    a.default_stack_id,
        \\    s.name AS stack_name,
        \\    s.runtime_tool,
        \\    pm.model_name,
        \\    a.is_active
        \\FROM agents a
        \\INNER JOIN stacks s ON s.id = a.default_stack_id
        \\INNER JOIN provider_models pm ON pm.id = s.provider_model_id
        \\ORDER BY a.id DESC
        ,
        .{},
    );

    const notice =
        if (c.query("created") != null)
            "Agente cadastrado com sucesso."
        else if (c.query("updated") != null)
            "Agente atualizado com sucesso."
        else if (c.query("deleted") != null)
            "Agente removido com sucesso."
        else
            "";

    return c.view("agents/index", .{
        .title = "Agents",
        .agents = rows,
        .agent_count = rows.len,
        .active_count = countActiveAgents(rows),
        .notice = notice,
    }, .{});
}

fn countActiveAgents(rows: []const AgentRow) usize {
    var total: usize = 0;
    for (rows) |row| {
        if (row.is_active) total += 1;
    }
    return total;
}

fn agentNew(c: *spider.Ctx) !spider.Response {
    const stacks_rows = try db.query(
        AgentStackOptionRow,
        c.arena,
        \\SELECT
        \\    s.id,
        \\    s.name,
        \\    s.runtime_tool,
        \\    pm.model_name
        \\FROM stacks s
        \\INNER JOIN provider_models pm ON pm.id = s.provider_model_id
        \\WHERE s.is_active = TRUE
        \\ORDER BY s.name ASC
        ,
        .{},
    );

    return c.view("agents/new", .{
        .title = "Novo Agente",
        .stacks = stacks_rows,
        .stack_count = stacks_rows.len,
        .error_message = "",
        .form = .{
            .name = "",
            .handle = "",
            .agent_role = "Piloto",
            .summary = "",
            .system_prompt = "",
            .operating_rules = "",
            .default_stack_id = "",
            .is_active = "true",
        },
    }, .{});
}

fn agentCreate(c: *spider.Ctx) !spider.Response {
    const form = try c.parseForm(AgentForm);
    const stack_id = std.fmt.parseInt(i32, form.default_stack_id, 10) catch 0;
    const active = std.mem.eql(u8, form.is_active, "true");

    const duplicated = try db.query(
        AgentIdRow,
        c.arena,
        \\SELECT id
        \\FROM agents
        \\WHERE handle = $1
        \\LIMIT 1
        ,
        .{ form.handle },
    );

    const stacks_rows = try db.query(
        AgentStackOptionRow,
        c.arena,
        \\SELECT
        \\    s.id,
        \\    s.name,
        \\    s.runtime_tool,
        \\    pm.model_name
        \\FROM stacks s
        \\INNER JOIN provider_models pm ON pm.id = s.provider_model_id
        \\WHERE s.is_active = TRUE
        \\ORDER BY s.name ASC
        ,
        .{},
    );

    if (duplicated.len > 0) {
        return c.view("agents/new", .{
            .title = "Novo Agente",
            .stacks = stacks_rows,
            .stack_count = stacks_rows.len,
            .error_message = "Já existe um agente cadastrado com este handle.",
            .form = form,
        }, .{ .status = .bad_request });
    }

    if (stack_id <= 0) {
        return c.view("agents/new", .{
            .title = "Novo Agente",
            .stacks = stacks_rows,
            .stack_count = stacks_rows.len,
            .error_message = "Selecione uma stack padrão válida.",
            .form = form,
        }, .{ .status = .bad_request });
    }

    try db.query(
        void,
        c.arena,
        \\INSERT INTO agents (
        \\    name,
        \\    handle,
        \\    agent_role,
        \\    summary,
        \\    system_prompt,
        \\    operating_rules,
        \\    default_stack_id,
        \\    is_active
        \\)
        \\VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ,
        .{
            form.name,
            form.handle,
            form.agent_role,
            form.summary,
            form.system_prompt,
            form.operating_rules,
            stack_id,
            active,
        },
    );

    return c.redirect("/agents?created=1");
}

fn agentShow(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Agente não informado.", .{ .status = .bad_request });

    const agent_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Agente inválido.", .{ .status = .bad_request });

    const rows = try db.query(
        AgentRow,
        c.arena,
        \\SELECT
        \\    a.id,
        \\    a.name,
        \\    a.handle,
        \\    a.agent_role,
        \\    a.summary,
        \\    a.system_prompt,
        \\    a.operating_rules,
        \\    a.default_stack_id,
        \\    s.name AS stack_name,
        \\    s.runtime_tool,
        \\    pm.model_name,
        \\    a.is_active
        \\FROM agents a
        \\INNER JOIN stacks s ON s.id = a.default_stack_id
        \\INNER JOIN provider_models pm ON pm.id = s.provider_model_id
        \\WHERE a.id = $1
        \\LIMIT 1
        ,
        .{ agent_id },
    );

    if (rows.len == 0) {
        return c.text("Agente não encontrado.", .{ .status = .not_found });
    }

    return c.view("agents/show", .{
        .title = rows[0].name,
        .agent = rows[0],
    }, .{});
}

fn agentEdit(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Agente não informado.", .{ .status = .bad_request });

    const agent_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Agente inválido.", .{ .status = .bad_request });

    const rows = try db.query(
        AgentRow,
        c.arena,
        \\SELECT
        \\    a.id,
        \\    a.name,
        \\    a.handle,
        \\    a.agent_role,
        \\    a.summary,
        \\    a.system_prompt,
        \\    a.operating_rules,
        \\    a.default_stack_id,
        \\    s.name AS stack_name,
        \\    s.runtime_tool,
        \\    pm.model_name,
        \\    a.is_active
        \\FROM agents a
        \\INNER JOIN stacks s ON s.id = a.default_stack_id
        \\INNER JOIN provider_models pm ON pm.id = s.provider_model_id
        \\WHERE a.id = $1
        \\LIMIT 1
        ,
        .{ agent_id },
    );

    if (rows.len == 0) {
        return c.text("Agente não encontrado.", .{ .status = .not_found });
    }

    const stacks_rows = try db.query(
        AgentStackOptionRow,
        c.arena,
        \\SELECT
        \\    s.id,
        \\    s.name,
        \\    s.runtime_tool,
        \\    pm.model_name
        \\FROM stacks s
        \\INNER JOIN provider_models pm ON pm.id = s.provider_model_id
        \\WHERE s.is_active = TRUE
        \\ORDER BY CASE WHEN s.id = $1 THEN 0 ELSE 1 END,
        \\         s.name ASC
        ,
        .{ rows[0].default_stack_id },
    );

    return c.view("agents/edit", .{
        .title = "Editar Agente",
        .agent = rows[0],
        .stacks = stacks_rows,
        .stack_count = stacks_rows.len,
        .error_message = "",
    }, .{});
}

fn agentUpdate(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Agente não informado.", .{ .status = .bad_request });

    const agent_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Agente inválido.", .{ .status = .bad_request });

    const form = try c.parseForm(AgentForm);
    const stack_id = std.fmt.parseInt(i32, form.default_stack_id, 10) catch 0;
    const active = std.mem.eql(u8, form.is_active, "true");

    const duplicated = try db.query(
        AgentIdRow,
        c.arena,
        \\SELECT id
        \\FROM agents
        \\WHERE handle = $1
        \\AND id <> $2
        \\LIMIT 1
        ,
        .{ form.handle, agent_id },
    );

    const current_rows = try db.query(
        AgentRow,
        c.arena,
        \\SELECT
        \\    a.id,
        \\    a.name,
        \\    a.handle,
        \\    a.agent_role,
        \\    a.summary,
        \\    a.system_prompt,
        \\    a.operating_rules,
        \\    a.default_stack_id,
        \\    s.name AS stack_name,
        \\    s.runtime_tool,
        \\    pm.model_name,
        \\    a.is_active
        \\FROM agents a
        \\INNER JOIN stacks s ON s.id = a.default_stack_id
        \\INNER JOIN provider_models pm ON pm.id = s.provider_model_id
        \\WHERE a.id = $1
        \\LIMIT 1
        ,
        .{ agent_id },
    );

    if (current_rows.len == 0) {
        return c.text("Agente não encontrado.", .{ .status = .not_found });
    }

    const stacks_rows = try db.query(
        AgentStackOptionRow,
        c.arena,
        \\SELECT
        \\    s.id,
        \\    s.name,
        \\    s.runtime_tool,
        \\    pm.model_name
        \\FROM stacks s
        \\INNER JOIN provider_models pm ON pm.id = s.provider_model_id
        \\WHERE s.is_active = TRUE
        \\ORDER BY CASE WHEN s.id = $1 THEN 0 ELSE 1 END,
        \\         s.name ASC
        ,
        .{ stack_id },
    );

    if (duplicated.len > 0) {
        const agent = AgentRow{
            .id = agent_id,
            .name = form.name,
            .handle = form.handle,
            .agent_role = form.agent_role,
            .summary = form.summary,
            .system_prompt = form.system_prompt,
            .operating_rules = form.operating_rules,
            .default_stack_id = stack_id,
            .stack_name = current_rows[0].stack_name,
            .runtime_tool = current_rows[0].runtime_tool,
            .model_name = current_rows[0].model_name,
            .is_active = active,
        };

        return c.view("agents/edit", .{
            .title = "Editar Agente",
            .agent = agent,
            .stacks = stacks_rows,
            .stack_count = stacks_rows.len,
            .error_message = "Outro agente já utiliza este handle.",
        }, .{ .status = .bad_request });
    }

    if (stack_id <= 0) {
        return c.view("agents/edit", .{
            .title = "Editar Agente",
            .agent = current_rows[0],
            .stacks = stacks_rows,
            .stack_count = stacks_rows.len,
            .error_message = "Selecione uma stack padrão válida.",
        }, .{ .status = .bad_request });
    }

    try db.query(
        void,
        c.arena,
        \\UPDATE agents
        \\SET name = $1,
        \\    handle = $2,
        \\    agent_role = $3,
        \\    summary = $4,
        \\    system_prompt = $5,
        \\    operating_rules = $6,
        \\    default_stack_id = $7,
        \\    is_active = $8
        \\WHERE id = $9
        ,
        .{
            form.name,
            form.handle,
            form.agent_role,
            form.summary,
            form.system_prompt,
            form.operating_rules,
            stack_id,
            active,
            agent_id,
        },
    );

    return c.redirect("/agents?updated=1");
}

fn agentDelete(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Agente não informado.", .{ .status = .bad_request });

    const agent_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Agente inválido.", .{ .status = .bad_request });

    try db.query(
        void,
        c.arena,
        \\DELETE FROM agents
        \\WHERE id = $1
        ,
        .{ agent_id },
    );

    return c.redirect("/agents?deleted=1");
}

fn squads(c: *spider.Ctx) !spider.Response {
    const rows = try db.query(
        SquadRow,
        c.arena,
        \\SELECT id, name, slug, summary, is_default, is_active
        \\FROM squads
        \\ORDER BY is_default DESC, id DESC
        ,
        .{},
    );

    const notice =
        if (c.query("created") != null)
            "Squad cadastrada com sucesso."
        else if (c.query("updated") != null)
            "Squad atualizada com sucesso."
        else if (c.query("deleted") != null)
            "Squad removida com sucesso."
        else
            "";

    return c.view("squads/index", .{
        .title = "Squads",
        .squads = rows,
        .squad_count = rows.len,
        .active_count = countActiveSquads(rows),
        .notice = notice,
    }, .{});
}

fn countActiveSquads(rows: []const SquadRow) usize {
    var total: usize = 0;
    for (rows) |row| {
        if (row.is_active) total += 1;
    }
    return total;
}

fn providers(c: *spider.Ctx) !spider.Response {
    const rows = try db.query(
        ProviderRow,
        c.arena,
        \\SELECT id, name, provider_type, base_url, api_key, is_active
        \\FROM providers
        \\ORDER BY id DESC
        ,
        .{},
    );

    const notice =
        if (c.query("created") != null)
            "Provider cadastrado com sucesso."
        else if (c.query("updated") != null)
            "Provider atualizado com sucesso."
        else if (c.query("deleted") != null)
            "Provider removido com sucesso."
        else
            "";

    const model_counts = try db.query(
        ProviderModelIdRow,
        c.arena,
        \\SELECT id
        \\FROM provider_models
        ,
        .{},
    );

    return c.view("providers/index", .{
        .title = "Providers",
        .providers = rows,
        .provider_count = rows.len,
        .active_count = countActiveProviders(rows),
        .model_count = model_counts.len,
        .notice = notice,
    }, .{});
}

fn countActiveProviders(rows: []const ProviderRow) usize {
    var total: usize = 0;
    for (rows) |row| {
        if (row.is_active) total += 1;
    }
    return total;
}

fn providerNew(c: *spider.Ctx) !spider.Response {
    return c.view("providers/new", .{
        .title = "Novo Provider",
        .error_message = "",
        .form = .{
            .name = "",
            .provider_type = "OpenAI Compatible",
            .base_url = "",
            .api_key = "",
            .is_active = "true",
        },
    }, .{});
}

fn providerCreate(c: *spider.Ctx) !spider.Response {
    const form = try c.parseForm(ProviderForm);

    const duplicated = try db.query(
        ProviderIdRow,
        c.arena,
        \\SELECT id
        \\FROM providers
        \\WHERE name = $1
        \\LIMIT 1
        ,
        .{ form.name },
    );

    if (duplicated.len > 0) {
        return c.view("providers/new", .{
            .title = "Novo Provider",
            .error_message = "Já existe um provider cadastrado com este nome.",
            .form = form,
        }, .{ .status = .bad_request });
    }

    const active = std.mem.eql(u8, form.is_active, "true");

    try db.query(
        void,
        c.arena,
        \\INSERT INTO providers (name, provider_type, base_url, api_key, is_active)
        \\VALUES ($1, $2, $3, $4, $5)
        ,
        .{
            form.name,
            form.provider_type,
            form.base_url,
            form.api_key,
            active,
        },
    );

    return c.redirect("/providers?created=1");
}

fn providerShow(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Provider não informado.", .{ .status = .bad_request });

    const provider_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Provider inválido.", .{ .status = .bad_request });

    const providers_rows = try db.query(
        ProviderRow,
        c.arena,
        \\SELECT id, name, provider_type, base_url, api_key, is_active
        \\FROM providers
        \\WHERE id = $1
        \\LIMIT 1
        ,
        .{ provider_id },
    );

    if (providers_rows.len == 0) {
        return c.text("Provider não encontrado.", .{ .status = .not_found });
    }

    const models = try db.query(
        ProviderModelRow,
        c.arena,
        \\SELECT id, provider_id, model_name, model_id, context_window, is_active
        \\FROM provider_models
        \\WHERE provider_id = $1
        \\ORDER BY id DESC
        ,
        .{ provider_id },
    );

    const notice =
        if (c.query("model_created") != null)
            "Modelo cadastrado com sucesso."
        else if (c.query("model_updated") != null)
            "Modelo atualizado com sucesso."
        else if (c.query("model_deleted") != null)
            "Modelo removido com sucesso."
        else
            "";

    return c.view("providers/show", .{
        .title = providers_rows[0].name,
        .provider = providers_rows[0],
        .models = models,
        .model_count = models.len,
        .notice = notice,
    }, .{});
}

fn providerModelNew(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Provider não informado.", .{ .status = .bad_request });

    const provider_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Provider inválido.", .{ .status = .bad_request });

    const providers_rows = try db.query(
        ProviderRow,
        c.arena,
        \\SELECT id, name, provider_type, base_url, api_key, is_active
        \\FROM providers
        \\WHERE id = $1
        \\LIMIT 1
        ,
        .{ provider_id },
    );

    if (providers_rows.len == 0) {
        return c.text("Provider não encontrado.", .{ .status = .not_found });
    }

    return c.view("providers/models_new", .{
        .title = "Novo Modelo",
        .provider = providers_rows[0],
        .error_message = "",
        .form = .{
            .model_name = "",
            .model_id = "",
            .context_window = "0",
            .is_active = "true",
        },
    }, .{});
}

fn providerModelCreate(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Provider não informado.", .{ .status = .bad_request });

    const provider_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Provider inválido.", .{ .status = .bad_request });

    const form = try c.parseForm(ProviderModelForm);
    const context_window = std.fmt.parseInt(i32, form.context_window, 10) catch 0;
    const active = std.mem.eql(u8, form.is_active, "true");

    const duplicated = try db.query(
        ProviderModelIdRow,
        c.arena,
        \\SELECT id
        \\FROM provider_models
        \\WHERE provider_id = $1
        \\AND model_id = $2
        \\LIMIT 1
        ,
        .{ provider_id, form.model_id },
    );

    if (duplicated.len > 0) {
        const providers_rows = try db.query(
            ProviderRow,
            c.arena,
            \\SELECT id, name, provider_type, base_url, api_key, is_active
            \\FROM providers
            \\WHERE id = $1
            \\LIMIT 1
            ,
            .{ provider_id },
        );

        return c.view("providers/models_new", .{
            .title = "Novo Modelo",
            .provider = providers_rows[0],
            .error_message = "Este model_id já está cadastrado para este provider.",
            .form = form,
        }, .{ .status = .bad_request });
    }

    try db.query(
        void,
        c.arena,
        \\INSERT INTO provider_models (provider_id, model_name, model_id, context_window, is_active)
        \\VALUES ($1, $2, $3, $4, $5)
        ,
        .{
            provider_id,
            form.model_name,
            form.model_id,
            context_window,
            active,
        },
    );

    const redirect_url = try std.fmt.allocPrint(c.arena, "/providers/{d}?model_created=1", .{ provider_id });
    return c.redirect(redirect_url);
}

fn providerModelEdit(c: *spider.Ctx) !spider.Response {
    const provider_id_raw = c.params.get("id") orelse
        return c.text("Provider não informado.", .{ .status = .bad_request });

    const model_id_raw = c.params.get("model_id") orelse
        return c.text("Modelo não informado.", .{ .status = .bad_request });

    const provider_id = std.fmt.parseInt(i32, provider_id_raw, 10) catch
        return c.text("Provider inválido.", .{ .status = .bad_request });

    const model_row_id = std.fmt.parseInt(i32, model_id_raw, 10) catch
        return c.text("Modelo inválido.", .{ .status = .bad_request });

    const providers_rows = try db.query(
        ProviderRow,
        c.arena,
        \\SELECT id, name, provider_type, base_url, api_key, is_active
        \\FROM providers
        \\WHERE id = $1
        \\LIMIT 1
        ,
        .{ provider_id },
    );

    const model_rows = try db.query(
        ProviderModelRow,
        c.arena,
        \\SELECT id, provider_id, model_name, model_id, context_window, is_active
        \\FROM provider_models
        \\WHERE id = $1
        \\AND provider_id = $2
        \\LIMIT 1
        ,
        .{ model_row_id, provider_id },
    );

    if (providers_rows.len == 0 or model_rows.len == 0) {
        return c.text("Modelo não encontrado.", .{ .status = .not_found });
    }

    return c.view("providers/models_edit", .{
        .title = "Editar Modelo",
        .provider = providers_rows[0],
        .model = model_rows[0],
        .error_message = "",
    }, .{});
}

fn providerModelUpdate(c: *spider.Ctx) !spider.Response {
    const provider_id_raw = c.params.get("id") orelse
        return c.text("Provider não informado.", .{ .status = .bad_request });

    const model_id_raw = c.params.get("model_id") orelse
        return c.text("Modelo não informado.", .{ .status = .bad_request });

    const provider_id = std.fmt.parseInt(i32, provider_id_raw, 10) catch
        return c.text("Provider inválido.", .{ .status = .bad_request });

    const model_row_id = std.fmt.parseInt(i32, model_id_raw, 10) catch
        return c.text("Modelo inválido.", .{ .status = .bad_request });

    const form = try c.parseForm(ProviderModelForm);
    const context_window = std.fmt.parseInt(i32, form.context_window, 10) catch 0;
    const active = std.mem.eql(u8, form.is_active, "true");

    const duplicated = try db.query(
        ProviderModelIdRow,
        c.arena,
        \\SELECT id
        \\FROM provider_models
        \\WHERE provider_id = $1
        \\AND model_id = $2
        \\AND id <> $3
        \\LIMIT 1
        ,
        .{ provider_id, form.model_id, model_row_id },
    );

    if (duplicated.len > 0) {
        const providers_rows = try db.query(
            ProviderRow,
            c.arena,
            \\SELECT id, name, provider_type, base_url, api_key, is_active
            \\FROM providers
            \\WHERE id = $1
            \\LIMIT 1
            ,
            .{ provider_id },
        );

        const model = ProviderModelRow{
            .id = model_row_id,
            .provider_id = provider_id,
            .model_name = form.model_name,
            .model_id = form.model_id,
            .context_window = context_window,
            .is_active = active,
        };

        return c.view("providers/models_edit", .{
            .title = "Editar Modelo",
            .provider = providers_rows[0],
            .model = model,
            .error_message = "Outro modelo já utiliza este model_id neste provider.",
        }, .{ .status = .bad_request });
    }

    try db.query(
        void,
        c.arena,
        \\UPDATE provider_models
        \\SET model_name = $1,
        \\    model_id = $2,
        \\    context_window = $3,
        \\    is_active = $4
        \\WHERE id = $5
        \\AND provider_id = $6
        ,
        .{
            form.model_name,
            form.model_id,
            context_window,
            active,
            model_row_id,
            provider_id,
        },
    );

    const redirect_url = try std.fmt.allocPrint(c.arena, "/providers/{d}?model_updated=1", .{ provider_id });
    return c.redirect(redirect_url);
}

fn providerModelDelete(c: *spider.Ctx) !spider.Response {
    const provider_id_raw = c.params.get("id") orelse
        return c.text("Provider não informado.", .{ .status = .bad_request });

    const model_id_raw = c.params.get("model_id") orelse
        return c.text("Modelo não informado.", .{ .status = .bad_request });

    const provider_id = std.fmt.parseInt(i32, provider_id_raw, 10) catch
        return c.text("Provider inválido.", .{ .status = .bad_request });

    const model_row_id = std.fmt.parseInt(i32, model_id_raw, 10) catch
        return c.text("Modelo inválido.", .{ .status = .bad_request });

    try db.query(
        void,
        c.arena,
        \\DELETE FROM provider_models
        \\WHERE id = $1
        \\AND provider_id = $2
        ,
        .{ model_row_id, provider_id },
    );

    const redirect_url = try std.fmt.allocPrint(c.arena, "/providers/{d}?model_deleted=1", .{ provider_id });
    return c.redirect(redirect_url);
}

fn providerEdit(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Provider não informado.", .{ .status = .bad_request });

    const provider_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Provider inválido.", .{ .status = .bad_request });

    const rows = try db.query(
        ProviderRow,
        c.arena,
        \\SELECT id, name, provider_type, base_url, api_key, is_active
        \\FROM providers
        \\WHERE id = $1
        \\LIMIT 1
        ,
        .{ provider_id },
    );

    if (rows.len == 0) {
        return c.text("Provider não encontrado.", .{ .status = .not_found });
    }

    return c.view("providers/edit", .{
        .title = "Editar Provider",
        .provider = rows[0],
        .error_message = "",
    }, .{});
}

fn providerUpdate(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Provider não informado.", .{ .status = .bad_request });

    const provider_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Provider inválido.", .{ .status = .bad_request });

    const form = try c.parseForm(ProviderForm);

    const duplicated = try db.query(
        ProviderIdRow,
        c.arena,
        \\SELECT id
        \\FROM providers
        \\WHERE name = $1
        \\AND id <> $2
        \\LIMIT 1
        ,
        .{ form.name, provider_id },
    );

    if (duplicated.len > 0) {
        const provider = ProviderRow{
            .id = provider_id,
            .name = form.name,
            .provider_type = form.provider_type,
            .base_url = form.base_url,
            .api_key = form.api_key,
            .is_active = std.mem.eql(u8, form.is_active, "true"),
        };

        return c.view("providers/edit", .{
            .title = "Editar Provider",
            .provider = provider,
            .error_message = "Outro provider já utiliza este nome.",
        }, .{ .status = .bad_request });
    }

    const active = std.mem.eql(u8, form.is_active, "true");

    try db.query(
        void,
        c.arena,
        \\UPDATE providers
        \\SET name = $1,
        \\    provider_type = $2,
        \\    base_url = $3,
        \\    api_key = $4,
        \\    is_active = $5
        \\WHERE id = $6
        ,
        .{
            form.name,
            form.provider_type,
            form.base_url,
            form.api_key,
            active,
            provider_id,
        },
    );

    return c.redirect("/providers?updated=1");
}

fn providerDelete(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Provider não informado.", .{ .status = .bad_request });

    const provider_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Provider inválido.", .{ .status = .bad_request });

    try db.query(
        void,
        c.arena,
        \\DELETE FROM providers
        \\WHERE id = $1
        ,
        .{ provider_id },
    );

    return c.redirect("/providers?deleted=1");
}

fn loadSquadAgents(c: *spider.Ctx) ![]SquadAgentOptionRow {
    return db.query(
        SquadAgentOptionRow,
        c.arena,
        \\SELECT id, name, handle, agent_role
        \\FROM agents
        \\WHERE is_active = TRUE
        \\ORDER BY agent_role ASC, name ASC
        ,
        .{},
    );
}


fn loadSquadAgentsExcept(c: *spider.Ctx, excluded_agent_id: i32) ![]SquadAgentOptionRow {
    return db.query(
        SquadAgentOptionRow,
        c.arena,
        \\SELECT id, name, handle, agent_role
        \\FROM agents
        \\WHERE is_active = TRUE
        \\AND id <> $1
        \\ORDER BY agent_role ASC, name ASC
        ,
        .{ excluded_agent_id },
    );
}

fn squadNew(c: *spider.Ctx) !spider.Response {
    const agents_rows = try loadSquadAgents(c);

    return c.view("squads/new", .{
        .title = "Nova Squad",
        .agents = agents_rows,
        .agent_count = agents_rows.len,
        .error_message = "",
        .form = .{
            .name = "",
            .slug = "",
            .summary = "",
            .is_default = "false",
            .is_active = "true",
            .pilot_agent_id = "",
            .planner_agent_id = "",
            .scout_agent_id = "",
            .builder_agent_id = "",
            .reviewer_agent_id = "",
            .executor_agent_id = "",
        },
    }, .{});
}

fn squadCreate(c: *spider.Ctx) !spider.Response {
    const form = try c.parseForm(SquadForm);
    const agents_rows = try loadSquadAgents(c);

    const duplicated = try db.query(
        SquadIdRow,
        c.arena,
        \\SELECT id
        \\FROM squads
        \\WHERE slug = $1
        \\LIMIT 1
        ,
        .{ form.slug },
    );

    if (duplicated.len > 0) {
        return c.view("squads/new", .{
            .title = "Nova Squad",
            .agents = agents_rows,
            .agent_count = agents_rows.len,
            .error_message = "Já existe uma squad cadastrada com este slug.",
            .form = form,
        }, .{ .status = .bad_request });
    }

    const pilot_agent_id = std.fmt.parseInt(i32, form.pilot_agent_id, 10) catch 0;
    const planner_agent_id = std.fmt.parseInt(i32, form.planner_agent_id, 10) catch 0;
    const scout_agent_id = std.fmt.parseInt(i32, form.scout_agent_id, 10) catch 0;
    const builder_agent_id = std.fmt.parseInt(i32, form.builder_agent_id, 10) catch 0;
    const reviewer_agent_id = std.fmt.parseInt(i32, form.reviewer_agent_id, 10) catch 0;
    const executor_agent_id = std.fmt.parseInt(i32, form.executor_agent_id, 10) catch 0;

    if (
        pilot_agent_id <= 0 or
        planner_agent_id <= 0 or
        scout_agent_id <= 0 or
        builder_agent_id <= 0 or
        reviewer_agent_id <= 0 or
        executor_agent_id <= 0
    ) {
        return c.view("squads/new", .{
            .title = "Nova Squad",
            .agents = agents_rows,
            .agent_count = agents_rows.len,
            .error_message = "Selecione um agente para todos os seis papéis da squad.",
            .form = form,
        }, .{ .status = .bad_request });
    }

    const default_flag = std.mem.eql(u8, form.is_default, "true");
    const active_flag = std.mem.eql(u8, form.is_active, "true");

    if (default_flag) {
        try db.query(
            void,
            c.arena,
            \\UPDATE squads SET is_default = FALSE
            ,
            .{},
        );
    }

    const inserted = try db.query(
        SquadIdRow,
        c.arena,
        \\INSERT INTO squads (name, slug, summary, is_default, is_active)
        \\VALUES ($1, $2, $3, $4, $5)
        \\RETURNING id
        ,
        .{
            form.name,
            form.slug,
            form.summary,
            default_flag,
            active_flag,
        },
    );

    const squad_id = inserted[0].id;

    try insertSquadMember(c, squad_id, "Piloto", pilot_agent_id, 1);
    try insertSquadMember(c, squad_id, "Planner", planner_agent_id, 2);
    try insertSquadMember(c, squad_id, "Scout", scout_agent_id, 3);
    try insertSquadMember(c, squad_id, "Builder", builder_agent_id, 4);
    try insertSquadMember(c, squad_id, "Reviewer", reviewer_agent_id, 5);
    try insertSquadMember(c, squad_id, "Executor", executor_agent_id, 6);

    return c.redirect("/squads?created=1");
}

fn insertSquadMember(
    c: *spider.Ctx,
    squad_id: i32,
    role_name: []const u8,
    agent_id: i32,
    display_order: i32,
) !void {
    try db.query(
        void,
        c.arena,
        \\INSERT INTO squad_members (squad_id, role_name, agent_id, display_order)
        \\VALUES ($1, $2, $3, $4)
        ,
        .{ squad_id, role_name, agent_id, display_order },
    );
}

fn squadShow(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Squad não informada.", .{ .status = .bad_request });

    const squad_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Squad inválida.", .{ .status = .bad_request });

    const squads_rows = try db.query(
        SquadRow,
        c.arena,
        \\SELECT id, name, slug, summary, is_default, is_active
        \\FROM squads
        \\WHERE id = $1
        \\LIMIT 1
        ,
        .{ squad_id },
    );

    if (squads_rows.len == 0) {
        return c.text("Squad não encontrada.", .{ .status = .not_found });
    }

    const members = try db.query(
        SquadMemberRow,
        c.arena,
        \\SELECT
        \\    sm.id,
        \\    sm.squad_id,
        \\    sm.role_name,
        \\    sm.agent_id,
        \\    sm.display_order,
        \\    a.name AS agent_name,
        \\    a.handle AS agent_handle,
        \\    a.agent_role,
        \\    s.name AS stack_name
        \\FROM squad_members sm
        \\INNER JOIN agents a ON a.id = sm.agent_id
        \\INNER JOIN stacks s ON s.id = a.default_stack_id
        \\WHERE sm.squad_id = $1
        \\ORDER BY sm.display_order ASC
        ,
        .{ squad_id },
    );

    return c.view("squads/show", .{
        .title = squads_rows[0].name,
        .squad = squads_rows[0],
        .members = members,
        .member_count = members.len,
    }, .{});
}

fn squadEdit(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Squad não informada.", .{ .status = .bad_request });

    const squad_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Squad inválida.", .{ .status = .bad_request });

    const squads_rows = try db.query(
        SquadRow,
        c.arena,
        \\SELECT id, name, slug, summary, is_default, is_active
        \\FROM squads
        \\WHERE id = $1
        \\LIMIT 1
        ,
        .{ squad_id },
    );

    if (squads_rows.len == 0) {
        return c.text("Squad não encontrada.", .{ .status = .not_found });
    }

    const members = try db.query(
        SquadMemberRow,
        c.arena,
        \\SELECT
        \\    sm.id,
        \\    sm.squad_id,
        \\    sm.role_name,
        \\    sm.agent_id,
        \\    sm.display_order,
        \\    a.name AS agent_name,
        \\    a.handle AS agent_handle,
        \\    a.agent_role,
        \\    s.name AS stack_name
        \\FROM squad_members sm
        \\INNER JOIN agents a ON a.id = sm.agent_id
        \\INNER JOIN stacks s ON s.id = a.default_stack_id
        \\WHERE sm.squad_id = $1
        \\ORDER BY sm.display_order ASC
        ,
        .{ squad_id },
    );

    const pilot_agents = try loadSquadAgentsExcept(c, members[0].agent_id);
    const planner_agents = try loadSquadAgentsExcept(c, members[1].agent_id);
    const scout_agents = try loadSquadAgentsExcept(c, members[2].agent_id);
    const builder_agents = try loadSquadAgentsExcept(c, members[3].agent_id);
    const reviewer_agents = try loadSquadAgentsExcept(c, members[4].agent_id);
    const executor_agents = try loadSquadAgentsExcept(c, members[5].agent_id);

    return c.view("squads/edit", .{
        .title = "Editar Squad",
        .squad = squads_rows[0],
        .members = members,
        .pilot_agents = pilot_agents,
        .planner_agents = planner_agents,
        .scout_agents = scout_agents,
        .builder_agents = builder_agents,
        .reviewer_agents = reviewer_agents,
        .executor_agents = executor_agents,
        .agent_count = pilot_agents.len + 1,
        .error_message = "",
    }, .{});
}

fn squadUpdate(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Squad não informada.", .{ .status = .bad_request });

    const squad_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Squad inválida.", .{ .status = .bad_request });

    const form = try c.parseForm(SquadForm);
    const agents_rows = try loadSquadAgents(c);

    const duplicated = try db.query(
        SquadIdRow,
        c.arena,
        \\SELECT id
        \\FROM squads
        \\WHERE slug = $1
        \\AND id <> $2
        \\LIMIT 1
        ,
        .{ form.slug, squad_id },
    );

    const squads_rows = try db.query(
        SquadRow,
        c.arena,
        \\SELECT id, name, slug, summary, is_default, is_active
        \\FROM squads
        \\WHERE id = $1
        \\LIMIT 1
        ,
        .{ squad_id },
    );

    if (squads_rows.len == 0) {
        return c.text("Squad não encontrada.", .{ .status = .not_found });
    }

    const members = try db.query(
        SquadMemberRow,
        c.arena,
        \\SELECT
        \\    sm.id,
        \\    sm.squad_id,
        \\    sm.role_name,
        \\    sm.agent_id,
        \\    sm.display_order,
        \\    a.name AS agent_name,
        \\    a.handle AS agent_handle,
        \\    a.agent_role,
        \\    s.name AS stack_name
        \\FROM squad_members sm
        \\INNER JOIN agents a ON a.id = sm.agent_id
        \\INNER JOIN stacks s ON s.id = a.default_stack_id
        \\WHERE sm.squad_id = $1
        \\ORDER BY sm.display_order ASC
        ,
        .{ squad_id },
    );

    if (duplicated.len > 0) {
        return c.view("squads/edit", .{
            .title = "Editar Squad",
            .squad = squads_rows[0],
            .members = members,
            .agents = agents_rows,
            .agent_count = agents_rows.len,
            .error_message = "Outra squad já utiliza este slug.",
        }, .{ .status = .bad_request });
    }

    const pilot_agent_id = std.fmt.parseInt(i32, form.pilot_agent_id, 10) catch 0;
    const planner_agent_id = std.fmt.parseInt(i32, form.planner_agent_id, 10) catch 0;
    const scout_agent_id = std.fmt.parseInt(i32, form.scout_agent_id, 10) catch 0;
    const builder_agent_id = std.fmt.parseInt(i32, form.builder_agent_id, 10) catch 0;
    const reviewer_agent_id = std.fmt.parseInt(i32, form.reviewer_agent_id, 10) catch 0;
    const executor_agent_id = std.fmt.parseInt(i32, form.executor_agent_id, 10) catch 0;

    if (
        pilot_agent_id <= 0 or
        planner_agent_id <= 0 or
        scout_agent_id <= 0 or
        builder_agent_id <= 0 or
        reviewer_agent_id <= 0 or
        executor_agent_id <= 0
    ) {
        return c.view("squads/edit", .{
            .title = "Editar Squad",
            .squad = squads_rows[0],
            .members = members,
            .agents = agents_rows,
            .agent_count = agents_rows.len,
            .error_message = "Selecione um agente para todos os seis papéis da squad.",
        }, .{ .status = .bad_request });
    }

    const default_flag = std.mem.eql(u8, form.is_default, "true");
    const active_flag = std.mem.eql(u8, form.is_active, "true");

    if (default_flag) {
        try db.query(
            void,
            c.arena,
            \\UPDATE squads SET is_default = FALSE
            ,
            .{},
        );
    }

    try db.query(
        void,
        c.arena,
        \\UPDATE squads
        \\SET name = $1,
        \\    slug = $2,
        \\    summary = $3,
        \\    is_default = $4,
        \\    is_active = $5
        \\WHERE id = $6
        ,
        .{
            form.name,
            form.slug,
            form.summary,
            default_flag,
            active_flag,
            squad_id,
        },
    );

    try db.query(
        void,
        c.arena,
        \\DELETE FROM squad_members
        \\WHERE squad_id = $1
        ,
        .{ squad_id },
    );

    try insertSquadMember(c, squad_id, "Piloto", pilot_agent_id, 1);
    try insertSquadMember(c, squad_id, "Planner", planner_agent_id, 2);
    try insertSquadMember(c, squad_id, "Scout", scout_agent_id, 3);
    try insertSquadMember(c, squad_id, "Builder", builder_agent_id, 4);
    try insertSquadMember(c, squad_id, "Reviewer", reviewer_agent_id, 5);
    try insertSquadMember(c, squad_id, "Executor", executor_agent_id, 6);

    return c.redirect("/squads?updated=1");
}

fn squadDelete(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Squad não informada.", .{ .status = .bad_request });

    const squad_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Squad inválida.", .{ .status = .bad_request });

    try db.query(
        void,
        c.arena,
        \\DELETE FROM squads
        \\WHERE id = $1
        ,
        .{ squad_id },
    );

    return c.redirect("/squads?deleted=1");
}

fn stacks(c: *spider.Ctx) !spider.Response {
    const rows = try db.query(
        StackRow,
        c.arena,
        \\SELECT
        \\    s.id,
        \\    s.name,
        \\    s.runtime_tool,
        \\    s.provider_model_id,
        \\    pm.model_name,
        \\    pm.model_id AS model_identifier,
        \\    p.name AS provider_name,
        \\    s.is_active
        \\FROM stacks s
        \\INNER JOIN provider_models pm ON pm.id = s.provider_model_id
        \\INNER JOIN providers p ON p.id = pm.provider_id
        \\ORDER BY s.id DESC
        ,
        .{},
    );

    const notice =
        if (c.query("created") != null)
            "Stack cadastrada com sucesso."
        else if (c.query("updated") != null)
            "Stack atualizada com sucesso."
        else if (c.query("deleted") != null)
            "Stack removida com sucesso."
        else
            "";

    return c.view("stacks/index", .{
        .title = "Stacks",
        .stacks = rows,
        .stack_count = rows.len,
        .active_count = countActiveStacks(rows),
        .notice = notice,
    }, .{});
}

fn countActiveStacks(rows: []const StackRow) usize {
    var total: usize = 0;
    for (rows) |row| {
        if (row.is_active) total += 1;
    }
    return total;
}

fn stackNew(c: *spider.Ctx) !spider.Response {
    const models = try db.query(
        StackModelOptionRow,
        c.arena,
        \\SELECT
        \\    pm.id,
        \\    pm.model_name,
        \\    pm.model_id AS model_identifier,
        \\    p.name AS provider_name
        \\FROM provider_models pm
        \\INNER JOIN providers p ON p.id = pm.provider_id
        \\WHERE pm.is_active = TRUE
        \\AND p.is_active = TRUE
        \\ORDER BY p.name ASC, pm.model_name ASC
        ,
        .{},
    );

    return c.view("stacks/new", .{
        .title = "Nova Stack",
        .models = models,
        .model_count = models.len,
        .error_message = "",
        .form = .{
            .name = "",
            .runtime_tool = "OpenCode",
            .provider_model_id = "",
            .is_active = "true",
        },
    }, .{});
}

fn stackCreate(c: *spider.Ctx) !spider.Response {
    const form = try c.parseForm(StackForm);
    const provider_model_id = std.fmt.parseInt(i32, form.provider_model_id, 10) catch 0;
    const active = std.mem.eql(u8, form.is_active, "true");

    const duplicated = try db.query(
        StackIdRow,
        c.arena,
        \\SELECT id
        \\FROM stacks
        \\WHERE name = $1
        \\LIMIT 1
        ,
        .{ form.name },
    );

    const models = try db.query(
        StackModelOptionRow,
        c.arena,
        \\SELECT
        \\    pm.id,
        \\    pm.model_name,
        \\    pm.model_id AS model_identifier,
        \\    p.name AS provider_name
        \\FROM provider_models pm
        \\INNER JOIN providers p ON p.id = pm.provider_id
        \\WHERE pm.is_active = TRUE
        \\AND p.is_active = TRUE
        \\ORDER BY p.name ASC, pm.model_name ASC
        ,
        .{},
    );

    if (duplicated.len > 0) {
        return c.view("stacks/new", .{
            .title = "Nova Stack",
            .models = models,
            .model_count = models.len,
            .error_message = "Já existe uma stack cadastrada com este nome.",
            .form = form,
        }, .{ .status = .bad_request });
    }

    if (provider_model_id <= 0) {
        return c.view("stacks/new", .{
            .title = "Nova Stack",
            .models = models,
            .model_count = models.len,
            .error_message = "Selecione um modelo válido para esta stack.",
            .form = form,
        }, .{ .status = .bad_request });
    }

    try db.query(
        void,
        c.arena,
        \\INSERT INTO stacks (name, runtime_tool, provider_model_id, is_active)
        \\VALUES ($1, $2, $3, $4)
        ,
        .{
            form.name,
            form.runtime_tool,
            provider_model_id,
            active,
        },
    );

    return c.redirect("/stacks?created=1");
}

fn stackEdit(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Stack não informada.", .{ .status = .bad_request });

    const stack_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Stack inválida.", .{ .status = .bad_request });

    const rows = try db.query(
        StackRow,
        c.arena,
        \\SELECT
        \\    s.id,
        \\    s.name,
        \\    s.runtime_tool,
        \\    s.provider_model_id,
        \\    pm.model_name,
        \\    pm.model_id AS model_identifier,
        \\    p.name AS provider_name,
        \\    s.is_active
        \\FROM stacks s
        \\INNER JOIN provider_models pm ON pm.id = s.provider_model_id
        \\INNER JOIN providers p ON p.id = pm.provider_id
        \\WHERE s.id = $1
        \\LIMIT 1
        ,
        .{ stack_id },
    );

    if (rows.len == 0) {
        return c.text("Stack não encontrada.", .{ .status = .not_found });
    }

    const models = try db.query(
        StackModelOptionRow,
        c.arena,
        \\SELECT
        \\    pm.id,
        \\    pm.model_name,
        \\    pm.model_id AS model_identifier,
        \\    p.name AS provider_name
        \\FROM provider_models pm
        \\INNER JOIN providers p ON p.id = pm.provider_id
        \\WHERE pm.is_active = TRUE
        \\AND p.is_active = TRUE
        \\ORDER BY CASE WHEN pm.id = $1 THEN 0 ELSE 1 END,
        \\         p.name ASC,
        \\         pm.model_name ASC
        ,
        .{ rows[0].provider_model_id },
    );

    return c.view("stacks/edit", .{
        .title = "Editar Stack",
        .stack = rows[0],
        .models = models,
        .model_count = models.len,
        .error_message = "",
    }, .{});
}

fn stackUpdate(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Stack não informada.", .{ .status = .bad_request });

    const stack_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Stack inválida.", .{ .status = .bad_request });

    const form = try c.parseForm(StackForm);
    const provider_model_id = std.fmt.parseInt(i32, form.provider_model_id, 10) catch 0;
    const active = std.mem.eql(u8, form.is_active, "true");

    const duplicated = try db.query(
        StackIdRow,
        c.arena,
        \\SELECT id
        \\FROM stacks
        \\WHERE name = $1
        \\AND id <> $2
        \\LIMIT 1
        ,
        .{ form.name, stack_id },
    );

    const models = try db.query(
        StackModelOptionRow,
        c.arena,
        \\SELECT
        \\    pm.id,
        \\    pm.model_name,
        \\    pm.model_id AS model_identifier,
        \\    p.name AS provider_name
        \\FROM provider_models pm
        \\INNER JOIN providers p ON p.id = pm.provider_id
        \\WHERE pm.is_active = TRUE
        \\AND p.is_active = TRUE
        \\ORDER BY p.name ASC, pm.model_name ASC
        ,
        .{},
    );

    const current_rows = try db.query(
        StackRow,
        c.arena,
        \\SELECT
        \\    s.id,
        \\    s.name,
        \\    s.runtime_tool,
        \\    s.provider_model_id,
        \\    pm.model_name,
        \\    pm.model_id AS model_identifier,
        \\    p.name AS provider_name,
        \\    s.is_active
        \\FROM stacks s
        \\INNER JOIN provider_models pm ON pm.id = s.provider_model_id
        \\INNER JOIN providers p ON p.id = pm.provider_id
        \\WHERE s.id = $1
        \\LIMIT 1
        ,
        .{ stack_id },
    );

    if (current_rows.len == 0) {
        return c.text("Stack não encontrada.", .{ .status = .not_found });
    }

    if (duplicated.len > 0) {
        const stack = StackRow{
            .id = stack_id,
            .name = form.name,
            .runtime_tool = form.runtime_tool,
            .provider_model_id = provider_model_id,
            .model_name = current_rows[0].model_name,
            .model_identifier = current_rows[0].model_identifier,
            .provider_name = current_rows[0].provider_name,
            .is_active = active,
        };

        return c.view("stacks/edit", .{
            .title = "Editar Stack",
            .stack = stack,
            .models = models,
            .model_count = models.len,
            .error_message = "Outra stack já utiliza este nome.",
        }, .{ .status = .bad_request });
    }

    if (provider_model_id <= 0) {
        return c.view("stacks/edit", .{
            .title = "Editar Stack",
            .stack = current_rows[0],
            .models = models,
            .model_count = models.len,
            .error_message = "Selecione um modelo válido para esta stack.",
        }, .{ .status = .bad_request });
    }

    try db.query(
        void,
        c.arena,
        \\UPDATE stacks
        \\SET name = $1,
        \\    runtime_tool = $2,
        \\    provider_model_id = $3,
        \\    is_active = $4
        \\WHERE id = $5
        ,
        .{
            form.name,
            form.runtime_tool,
            provider_model_id,
            active,
            stack_id,
        },
    );

    return c.redirect("/stacks?updated=1");
}

fn stackDelete(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Stack não informada.", .{ .status = .bad_request });

    const stack_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Stack inválida.", .{ .status = .bad_request });

    try db.query(
        void,
        c.arena,
        \\DELETE FROM stacks
        \\WHERE id = $1
        ,
        .{ stack_id },
    );

    return c.redirect("/stacks?deleted=1");
}

