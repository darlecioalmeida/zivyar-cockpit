const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const core = @import("core");
const helpers = @import("../../shared/helpers.zig");
const model = @import("./mission_model.zig");
const repo = @import("./mission_repository.zig");

const StepConfig = struct {
    role: []const u8,
    label: []const u8,
};

fn captureAndSave(
    c: *spider.Ctx,
    mission: *const model.MissionNextStepRow,
    pane: *const model.WorkspaceMissionPaneDispatchRow,
    messages_url: []const u8,
    dispatch_msg_id: []const u8,
    config: StepConfig,
    updateFn: *const fn (*spider.Ctx, []const u8, i32) anyerror!void,
) !?[]const u8 {
    const messages_result = core.runRuntimeCommand(c, &.{
        "curl",
        "-fsS",
        messages_url,
    });

    try repo.insertRuntimeCommandLog(
        c,
        mission.workspace_id,
        try std.fmt.allocPrint(c.arena, "opencode-fetch-{s}-session-messages", .{config.role}),
        try std.fmt.allocPrint(c.arena, "GET <opencode-server>/session/<session-id>/message [{s}]", .{config.label}),
        messages_result,
    );

    if (!messages_result.ok) return null;

    const captured_text = try helpers.extractAssistantTextForParentMessage(
        c.arena,
        messages_result.stdout,
        dispatch_msg_id,
    );

    if (captured_text) |text| {
        try updateFn(c, text, mission.id);

        const event_msg = try std.fmt.allocPrint(
            c.arena,
            "{s} capturado a partir da sessão {s}.",
            .{ config.label, pane.session_external_id },
        );

        try repo.insertMissionEvent(
            c,
            mission.id,
            mission.workspace_id,
            try std.fmt.allocPrint(c.arena, "{s}-captured", .{config.role}),
            config.label,
            event_msg,
        );
    }

    return captured_text;
}

pub fn executeAutopilotStep(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const code = c.query("code") orelse
        return c.text("Código da etapa não informado.", .{ .status = .bad_request });

    const rows = try repo.getNextStepMission(c, mission_id);
    if (rows.len == 0) {
        return c.text("Missão não encontrada.", .{ .status = .not_found });
    }

    const mission = rows[0];

    if (std.mem.eql(u8, mission.mission_operational_closure_status, "closed")) {
        return c.text("Missão encerrada.", .{ .status = .bad_request });
    }

    if (!std.mem.eql(u8, mission.execution_mode, "autopilot")) {
        return c.text("Modo autopilot não está ativo.", .{ .status = .bad_request });
    }

    if (std.mem.eql(u8, code, "finalize_mission")) {
        const closure_rows = try repo.getClosureRow(c, mission_id);
        if (closure_rows.len > 0 and
            closure_rows[0].pilot_delivery_report.len > 0 and
            std.mem.eql(u8, closure_rows[0].pilot_delivery_report_status, "captured"))
        {
            const verdict = helpers.extractMissionFinalVerdictFromPilotDeliveryReport(closure_rows[0].pilot_delivery_report);
            const final_verdict = if (verdict.len > 0) verdict else "needs_follow_up";
            const formal_status = if (std.mem.eql(u8, final_verdict, "completed")) "completed" else if (std.mem.eql(u8, final_verdict, "needs_follow_up")) "needs_follow_up" else "blocked";
            try repo.finalizeMission(c, final_verdict, formal_status, mission_id);
            try repo.insertMissionEvent(c, mission_id, closure_rows[0].workspace_id, "mission-operationally-closed", "Missão encerrada pelo Cockpit", "Missão encerrada automaticamente pelo autopilot.");
            try repo.releaseActiveMission(c, closure_rows[0].workspace_id, mission_id);
            return c.redirect(try std.fmt.allocPrint(c.arena, "/missions/{d}", .{mission_id}));
        }
        const final_config: StepConfig = .{ .role = "Piloto", .label = "Capturar Final Delivery Report" };
        const pane_rows = try repo.getPaneByRole(c, mission.workspace_id, final_config.role);
        if (pane_rows.len == 0 or pane_rows[0].session_external_id.len == 0) {
            return renderError(c, &mission, final_config.label,
                try std.fmt.allocPrint(c.arena, "O pane {s} não possui sessão disponível.", .{final_config.role}));
        }
        const final_runtime_rows = try repo.loadWorkspaceRuntime(c, mission.workspace_id);
        if (final_runtime_rows.len == 0) {
            return renderError(c, &mission, final_config.label, "Runtime do workspace não encontrado.");
        }
        try repo.reconcileWorkspaceRuntimeState(c, final_runtime_rows[0]);
        const final_refreshed_runtime = try repo.loadWorkspaceRuntime(c, mission.workspace_id);
        if (final_refreshed_runtime.len == 0) {
            return renderError(c, &mission, final_config.label, "Runtime indisponível após reconciliação.");
        }
        const final_runtime = final_refreshed_runtime[0];
        if (!std.mem.eql(u8, final_runtime.state, "running")) {
            return renderError(c, &mission, final_config.label, "O runtime precisa estar em execução.");
        }
        const final_messages_url = try std.fmt.allocPrint(c.arena, "{s}/session/{s}/message", .{ final_runtime.server_url_label, pane_rows[0].session_external_id });
        const dt_rows = try repo.getPilotDeliveryDispatchTrace(c, mission_id);
        if (dt_rows.len == 0 or dt_rows[0].pilot_delivery_dispatch_user_message_id.len == 0)
            return renderError(c, &mission, final_config.label, "Nenhum rastreio de despacho encontrado para o Piloto.");
        const captured = try captureAndSave(c, &mission, &pane_rows[0], final_messages_url, dt_rows[0].pilot_delivery_dispatch_user_message_id, final_config, repo.updateMissionAfterPilotDeliveryReportCapture);
        if (captured != null) {
            return c.redirect(try std.fmt.allocPrint(c.arena, "/missions/{d}/finalize", .{mission_id}));
        }
        const refresh_url = try std.fmt.allocPrint(c.arena, "/missions/{d}/autopilot/step?code={s}", .{ mission_id, code });
        return renderWaiting(c, &mission, final_config.label, refresh_url);
    }

    const config: StepConfig = blk: {
        if (std.mem.eql(u8, code, "capture_pilot_brief")) break :blk .{ .role = "Piloto", .label = "Capturar briefing do Piloto" };
        if (std.mem.eql(u8, code, "capture_planner_plan")) break :blk .{ .role = "Planner", .label = "Capturar plano do Planner" };
        if (std.mem.eql(u8, code, "capture_scout_report")) break :blk .{ .role = "Scout", .label = "Capturar Scout Report" };
        if (std.mem.eql(u8, code, "capture_builder_report")) break :blk .{ .role = "Builder", .label = "Capturar Implementation Report" };
        if (std.mem.eql(u8, code, "capture_reviewer_report")) break :blk .{ .role = "Reviewer", .label = "Capturar Review Report" };
        if (std.mem.eql(u8, code, "capture_executor_report")) break :blk .{ .role = "Executor", .label = "Capturar Verification Report" };
        if (std.mem.eql(u8, code, "capture_pilot_delivery_report")) break :blk .{ .role = "Piloto", .label = "Capturar Final Delivery Report" };
        const error_msg = try std.fmt.allocPrint(c.arena, "Código de etapa desconhecido: {s}", .{code});
        return c.text(error_msg, .{ .status = .bad_request });
    };

    const pane_rows = try repo.getPaneByRole(c, mission.workspace_id, config.role);
    if (pane_rows.len == 0 or pane_rows[0].session_external_id.len == 0) {
        return renderError(c, &mission, config.label,
            try std.fmt.allocPrint(c.arena, "O pane {s} não possui sessão disponível.", .{config.role}));
    }

    const pane = pane_rows[0];
    const runtime_rows = try repo.loadWorkspaceRuntime(c, mission.workspace_id);
    if (runtime_rows.len == 0) {
        return renderError(c, &mission, config.label, "Runtime do workspace não encontrado.");
    }

    try repo.reconcileWorkspaceRuntimeState(c, runtime_rows[0]);
    const refreshed_runtime_rows = try repo.loadWorkspaceRuntime(c, mission.workspace_id);
    if (refreshed_runtime_rows.len == 0) {
        return renderError(c, &mission, config.label, "Runtime indisponível após reconciliação.");
    }

    const runtime = refreshed_runtime_rows[0];
    if (!std.mem.eql(u8, runtime.state, "running")) {
        return renderError(c, &mission, config.label, "O runtime precisa estar em execução.");
    }

    const messages_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/message",
        .{ runtime.server_url_label, pane.session_external_id },
    );

    const capture_result: bool = if (std.mem.eql(u8, code, "capture_pilot_brief")) blk: {
        const dt_rows = try repo.getPilotDispatchTrace(c, mission_id);
        if (dt_rows.len == 0 or dt_rows[0].pilot_dispatch_user_message_id.len == 0)
            return renderError(c, &mission, config.label, "Nenhum rastreio de despacho encontrado para o Piloto.");
        break :blk (try captureAndSave(c, &mission, &pane, messages_url, dt_rows[0].pilot_dispatch_user_message_id, config, repo.updateMissionAfterPilotBriefCapture)) != null;
    } else if (std.mem.eql(u8, code, "capture_planner_plan")) blk: {
        const dt_rows = try repo.getPlannerDispatchTrace(c, mission_id);
        if (dt_rows.len == 0 or dt_rows[0].planner_dispatch_user_message_id.len == 0)
            return renderError(c, &mission, config.label, "Nenhum rastreio de despacho encontrado para o Planner.");
        break :blk (try captureAndSave(c, &mission, &pane, messages_url, dt_rows[0].planner_dispatch_user_message_id, config, repo.updateMissionAfterPlannerPlanCapture)) != null;
    } else if (std.mem.eql(u8, code, "capture_scout_report")) blk: {
        const dt_rows = try repo.getScoutDispatchTrace(c, mission_id);
        if (dt_rows.len == 0 or dt_rows[0].scout_dispatch_user_message_id.len == 0)
            return renderError(c, &mission, config.label, "Nenhum rastreio de despacho encontrado para o Scout.");
        break :blk (try captureAndSave(c, &mission, &pane, messages_url, dt_rows[0].scout_dispatch_user_message_id, config, repo.updateMissionAfterScoutReportCapture)) != null;
    } else if (std.mem.eql(u8, code, "capture_builder_report")) blk: {
        const dt_rows = try repo.getBuilderDispatchTrace(c, mission_id);
        if (dt_rows.len == 0 or dt_rows[0].builder_dispatch_user_message_id.len == 0)
            return renderError(c, &mission, config.label, "Nenhum rastreio de despacho encontrado para o Builder.");
        break :blk (try captureAndSave(c, &mission, &pane, messages_url, dt_rows[0].builder_dispatch_user_message_id, config, repo.updateMissionAfterBuilderReportCapture)) != null;
    } else if (std.mem.eql(u8, code, "capture_reviewer_report")) blk: {
        const dt_rows = try repo.getReviewerDispatchTrace(c, mission_id);
        if (dt_rows.len == 0 or dt_rows[0].reviewer_dispatch_user_message_id.len == 0)
            return renderError(c, &mission, config.label, "Nenhum rastreio de despacho encontrado para o Reviewer.");
        break :blk (try captureAndSave(c, &mission, &pane, messages_url, dt_rows[0].reviewer_dispatch_user_message_id, config, repo.updateMissionAfterReviewerReportCapture)) != null;
    } else if (std.mem.eql(u8, code, "capture_executor_report")) blk: {
        const dt_rows = try repo.getExecutorDispatchTrace(c, mission_id);
        if (dt_rows.len == 0 or dt_rows[0].executor_dispatch_user_message_id.len == 0)
            return renderError(c, &mission, config.label, "Nenhum rastreio de despacho encontrado para o Executor.");
        break :blk (try captureAndSave(c, &mission, &pane, messages_url, dt_rows[0].executor_dispatch_user_message_id, config, repo.updateMissionAfterExecutorReportCapture)) != null;
    } else if (std.mem.eql(u8, code, "capture_pilot_delivery_report")) blk: {
        const dt_rows = try repo.getPilotDeliveryDispatchTrace(c, mission_id);
        if (dt_rows.len == 0 or dt_rows[0].pilot_delivery_dispatch_user_message_id.len == 0)
            return renderError(c, &mission, config.label, "Nenhum rastreio de despacho encontrado para o Piloto.");
        break :blk (try captureAndSave(c, &mission, &pane, messages_url, dt_rows[0].pilot_delivery_dispatch_user_message_id, config, repo.updateMissionAfterPilotDeliveryReportCapture)) != null;
    } else unreachable;

    if (capture_result) {
        return c.redirect(try std.fmt.allocPrint(c.arena, "/missions/{d}/next-step", .{mission_id}));
    }

    const refresh_url = try std.fmt.allocPrint(c.arena, "/missions/{d}/autopilot/step?code={s}", .{ mission_id, code });
    return renderWaiting(c, &mission, config.label, refresh_url);
}

fn renderWaiting(c: *spider.Ctx, mission: *const model.MissionNextStepRow, step_label: []const u8, refresh_url: []const u8) !spider.Response {
    return c.view("missions/autopilot_step", .{
        .mission = mission.*,
        .step_description = step_label,
        .status = "waiting",
        .status_message = try std.fmt.allocPrint(c.arena, "Aguardando resposta do agente...", .{}),
        .refresh_url = refresh_url,
        .elapsed_label = "",
        .executed_steps = &[_][]const u8{},
    }, .{});
}

fn renderError(c: *spider.Ctx, mission: *const model.MissionNextStepRow, step_label: []const u8, msg: []const u8) !spider.Response {
    return c.view("missions/autopilot_step", .{
        .mission = mission.*,
        .step_description = step_label,
        .status = "error",
        .status_message = msg,
        .refresh_url = "",
        .elapsed_label = "",
        .executed_steps = &[_][]const u8{},
    }, .{ .status = .bad_request });
}
