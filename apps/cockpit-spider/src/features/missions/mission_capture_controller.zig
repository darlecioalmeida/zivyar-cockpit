const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const core = @import("core");
const helpers = @import("../../shared/helpers.zig");
const model = @import("./mission_model.zig");
const repo = @import("./mission_repository.zig");

pub fn capturePilotBrief(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const mission_rows = try repo.getMissionById(c, mission_id);

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

    const pilot_rows = try repo.getPaneByRole(c, mission.workspace_id, "Piloto");

    if (pilot_rows.len == 0 or pilot_rows[0].session_external_id.len == 0) {
        return c.text("O pane Piloto não possui sessão disponível.", .{ .status = .bad_request });
    }

    const pilot = pilot_rows[0];

    const dispatch_trace_rows = try repo.getPilotDispatchTrace(c, mission_id);

    if (dispatch_trace_rows.len == 0 or dispatch_trace_rows[0].pilot_dispatch_user_message_id.len == 0) {
        return c.text(
            "Esta missão ainda não possui rastreio do despacho ao Piloto. Reenvie a missão ao Piloto antes de capturar o briefing.",
            .{ .status = .bad_request },
        );
    }

    const dispatch_trace = dispatch_trace_rows[0];
    const runtime_rows = try repo.loadWorkspaceRuntime(c, mission.workspace_id);

    if (runtime_rows.len == 0) {
        return c.text("Runtime do workspace não encontrado.", .{ .status = .bad_request });
    }

    try repo.reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try repo.loadWorkspaceRuntime(c, mission.workspace_id);
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

    const max_attempts: usize = if (std.mem.eql(u8, mission.execution_mode, "autopilot")) 300 else 8;
    var messages_result: core.RuntimeCommandResult = .{
        .ok = false,
        .exit_code = -1,
        .stdout = "",
        .stderr = "",
    };
    var brief_text: ?[]const u8 = null;
    var attempt: usize = 0;

    while (attempt < max_attempts and brief_text == null) : (attempt += 1) {
        messages_result = core.runRuntimeCommand(c, &.{
            "curl",
            "-fsS",
            messages_url,
        });

        if (!messages_result.ok) break;

        brief_text = try helpers.extractAssistantTextForParentMessage(
            c.arena,
            messages_result.stdout,
            dispatch_trace.pilot_dispatch_user_message_id,
        );

        if (brief_text == null and attempt + 1 < max_attempts) {
            std.Io.sleep(c._io, std.Io.Duration.fromMilliseconds(200), .real) catch {};
        }
    }

    try repo.insertRuntimeCommandLog(
        c,
        mission.workspace_id,
        "opencode-fetch-pilot-session-messages",
        "GET <opencode-server>/session/<session-id>/message",
        messages_result,
    );

    if (!messages_result.ok) {
        return c.text("Falha ao consultar mensagens da sessão do Piloto.", .{ .status = .bad_request });
    }

    const brief_text_value = brief_text orelse {
        return c.text(
            "Nenhuma resposta textual vinculada ao último despacho rastreado foi encontrada. Aguarde o Piloto concluir a resposta e tente novamente.",
            .{ .status = .bad_request },
        );
    };

    try repo.updateMissionAfterPilotBriefCapture(c, brief_text_value, mission_id);

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Briefing Operacional do Piloto foi capturado a partir da sessão {s}.",
        .{pilot.session_external_id},
    );

    try repo.insertMissionEvent(c, mission_id, mission.workspace_id, "pilot-operational-brief-captured", "Briefing do Piloto capturado", event_message);

    if (std.mem.eql(u8, mission.execution_mode, "autopilot")) {
        const next_url = try std.fmt.allocPrint(c.arena, "/missions/{d}/next-step", .{mission_id});
        return c.redirect(next_url);
    }

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}",
        .{mission_id},
    );

    return c.redirect(redirect_url);
}

pub fn capturePlannerPlan(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const mission_rows = try repo.getMissionById(c, mission_id);

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

    const planner_rows = try repo.getPaneByRole(c, mission.workspace_id, "Planner");

    if (planner_rows.len == 0 or planner_rows[0].session_external_id.len == 0) {
        return c.text(
            "O pane Planner não possui sessão disponível.",
            .{ .status = .bad_request },
        );
    }

    const planner = planner_rows[0];

    const dispatch_trace_rows = try repo.getPlannerDispatchTrace(c, mission_id);

    if (dispatch_trace_rows.len == 0 or
        dispatch_trace_rows[0].planner_dispatch_user_message_id.len == 0)
    {
        return c.text(
            "Esta missão ainda não possui rastreio do despacho ao Planner. Reenvie o briefing antes de capturar o plano.",
            .{ .status = .bad_request },
        );
    }

    const dispatch_trace = dispatch_trace_rows[0];
    const runtime_rows = try repo.loadWorkspaceRuntime(c, mission.workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "Runtime do workspace não encontrado.",
            .{ .status = .bad_request },
        );
    }

    try repo.reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try repo.loadWorkspaceRuntime(c, mission.workspace_id);
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

    const max_message_attempts: usize = 8;
    var messages_result: core.RuntimeCommandResult = .{
        .ok = false,
        .exit_code = -1,
        .stdout = "",
        .stderr = "",
    };
    var plan_text: ?[]const u8 = null;
    var message_attempt: usize = 0;

    while (message_attempt < max_message_attempts and plan_text == null) : (message_attempt += 1) {
        messages_result = core.runRuntimeCommand(c, &.{
            "curl",
            "-fsS",
            messages_url,
        });

        if (!messages_result.ok) {
            break;
        }

        plan_text = try helpers.extractAssistantTextForParentMessage(
            c.arena,
            messages_result.stdout,
            dispatch_trace.planner_dispatch_user_message_id,
        );

        if (plan_text == null and message_attempt + 1 < max_message_attempts) {
            std.Io.sleep(c._io, std.Io.Duration.fromMilliseconds(200), .real) catch {};
        }
    }

    try repo.insertRuntimeCommandLog(
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

    const plan_text_value = plan_text orelse {
        return c.text(
            "Nenhuma resposta textual vinculada ao último despacho rastreado foi encontrada. Aguarde o Planner concluir a resposta e tente novamente.",
            .{ .status = .bad_request },
        );
    };

    try repo.updateMissionAfterPlannerPlanCapture(c, plan_text_value, mission_id);

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Plano Operacional do Planner foi capturado a partir da sessão {s}.",
        .{planner.session_external_id},
    );

    try repo.insertMissionEvent(c, mission_id, mission.workspace_id, "planner-operational-plan-captured", "Plano do Planner capturado", event_message);

    if (std.mem.eql(u8, mission.execution_mode, "autopilot")) {
        const next_url = try std.fmt.allocPrint(c.arena, "/missions/{d}/next-step", .{mission_id});
        return c.redirect(next_url);
    }

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}",
        .{mission_id},
    );

    return c.redirect(redirect_url);
}

pub fn captureScoutReport(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const mission_rows = try repo.getMissionById(c, mission_id);

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

    const scout_rows = try repo.getPaneByRole(c, mission.workspace_id, "Scout");

    if (scout_rows.len == 0 or scout_rows[0].session_external_id.len == 0) {
        return c.text(
            "O pane Scout não possui sessão disponível.",
            .{ .status = .bad_request },
        );
    }

    const scout = scout_rows[0];

    const dispatch_trace_rows = try repo.getScoutDispatchTrace(c, mission_id);

    if (dispatch_trace_rows.len == 0 or
        dispatch_trace_rows[0].scout_dispatch_user_message_id.len == 0)
    {
        return c.text(
            "Esta missão ainda não possui rastreio do despacho ao Scout. Reenvie o plano ao Scout antes de capturar o relatório.",
            .{ .status = .bad_request },
        );
    }

    const dispatch_trace = dispatch_trace_rows[0];
    const runtime_rows = try repo.loadWorkspaceRuntime(c, mission.workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "Runtime do workspace não encontrado.",
            .{ .status = .bad_request },
        );
    }

    try repo.reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try repo.loadWorkspaceRuntime(c, mission.workspace_id);
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

    const max_attempts: usize = if (std.mem.eql(u8, mission.execution_mode, "autopilot")) 300 else 8;
    var messages_result: core.RuntimeCommandResult = .{
        .ok = false,
        .exit_code = -1,
        .stdout = "",
        .stderr = "",
    };
    var scout_report_text: ?[]const u8 = null;
    var attempt: usize = 0;

    while (attempt < max_attempts and scout_report_text == null) : (attempt += 1) {
        messages_result = core.runRuntimeCommand(c, &.{
            "curl",
            "-fsS",
            messages_url,
        });

        if (!messages_result.ok) break;

        scout_report_text = try helpers.extractAssistantTextForParentMessage(
            c.arena,
            messages_result.stdout,
            dispatch_trace.scout_dispatch_user_message_id,
        );

        if (scout_report_text == null and attempt + 1 < max_attempts) {
            std.Io.sleep(c._io, std.Io.Duration.fromMilliseconds(200), .real) catch {};
        }
    }

    try repo.insertRuntimeCommandLog(
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

    const scout_report_text_value = scout_report_text orelse {
        return c.text(
            "Nenhuma resposta textual vinculada ao último despacho rastreado foi encontrada. Aguarde o Scout concluir a resposta e tente novamente.",
            .{ .status = .bad_request },
        );
    };

    try repo.updateMissionAfterScoutReportCapture(c, scout_report_text_value, mission_id);

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Scout Report foi capturado a partir da sessão {s}.",
        .{scout.session_external_id},
    );

    try repo.insertMissionEvent(c, mission_id, mission.workspace_id, "scout-report-captured", "Scout Report capturado", event_message);

    if (std.mem.eql(u8, mission.execution_mode, "autopilot")) {
        const next_url = try std.fmt.allocPrint(c.arena, "/missions/{d}/next-step", .{mission_id});
        return c.redirect(next_url);
    }

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}",
        .{mission_id},
    );

    return c.redirect(redirect_url);
}

pub fn captureBuilderReport(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const mission_rows = try repo.getMissionById(c, mission_id);

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

    const builder_rows = try repo.getPaneByRole(c, mission.workspace_id, "Builder");

    if (builder_rows.len == 0 or builder_rows[0].session_external_id.len == 0) {
        return c.text(
            "O pane Builder não possui sessão disponível.",
            .{ .status = .bad_request },
        );
    }

    const builder = builder_rows[0];

    const dispatch_trace_rows = try repo.getBuilderDispatchTrace(c, mission_id);

    if (dispatch_trace_rows.len == 0 or
        dispatch_trace_rows[0].builder_dispatch_user_message_id.len == 0)
    {
        return c.text(
            "Esta missão ainda não possui rastreio do despacho ao Builder. Reenvie o pacote antes de capturar o Implementation Report.",
            .{ .status = .bad_request },
        );
    }

    const dispatch_trace = dispatch_trace_rows[0];
    const runtime_rows = try repo.loadWorkspaceRuntime(c, mission.workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "Runtime do workspace não encontrado.",
            .{ .status = .bad_request },
        );
    }

    try repo.reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try repo.loadWorkspaceRuntime(c, mission.workspace_id);
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

    const max_attempts: usize = if (std.mem.eql(u8, mission.execution_mode, "autopilot")) 300 else 8;
    var messages_result: core.RuntimeCommandResult = .{
        .ok = false,
        .exit_code = -1,
        .stdout = "",
        .stderr = "",
    };
    var implementation_report_text: ?[]const u8 = null;
    var attempt: usize = 0;

    while (attempt < max_attempts and implementation_report_text == null) : (attempt += 1) {
        messages_result = core.runRuntimeCommand(c, &.{
            "curl",
            "-fsS",
            messages_url,
        });

        if (!messages_result.ok) break;

        implementation_report_text = try helpers.extractAssistantTextForParentMessage(
            c.arena,
            messages_result.stdout,
            dispatch_trace.builder_dispatch_user_message_id,
        );

        if (implementation_report_text == null and attempt + 1 < max_attempts) {
            std.Io.sleep(c._io, std.Io.Duration.fromMilliseconds(200), .real) catch {};
        }
    }

    try repo.insertRuntimeCommandLog(
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

    const implementation_report_text_value = implementation_report_text orelse {
        return c.text(
            "Nenhuma resposta textual vinculada ao último despacho rastreado foi encontrada. Aguarde o Builder concluir a resposta e tente novamente.",
            .{ .status = .bad_request },
        );
    };

    try repo.updateMissionAfterBuilderReportCapture(c, implementation_report_text_value, mission_id);

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Implementation Report do Builder foi capturado a partir da sessão {s}.",
        .{builder.session_external_id},
    );

    try repo.insertMissionEvent(c, mission_id, mission.workspace_id, "builder-implementation-report-captured", "Implementation Report capturado", event_message);

    if (std.mem.eql(u8, mission.execution_mode, "autopilot")) {
        const next_url = try std.fmt.allocPrint(c.arena, "/missions/{d}/next-step", .{mission_id});
        return c.redirect(next_url);
    }

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}",
        .{mission_id},
    );

    return c.redirect(redirect_url);
}

pub fn captureReviewerReport(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const mission_rows = try repo.getMissionById(c, mission_id);

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

    const reviewer_rows = try repo.getPaneByRole(c, mission.workspace_id, "Reviewer");

    if (reviewer_rows.len == 0 or reviewer_rows[0].session_external_id.len == 0) {
        return c.text(
            "O pane Reviewer não possui sessão disponível.",
            .{ .status = .bad_request },
        );
    }

    const reviewer = reviewer_rows[0];

    const dispatch_trace_rows = try repo.getReviewerDispatchTrace(c, mission_id);

    if (dispatch_trace_rows.len == 0 or
        dispatch_trace_rows[0].reviewer_dispatch_user_message_id.len == 0)
    {
        return c.text(
            "Esta missão ainda não possui rastreio do despacho ao Reviewer. Reenvie o relatório antes de capturar o review.",
            .{ .status = .bad_request },
        );
    }

    const dispatch_trace = dispatch_trace_rows[0];
    const runtime_rows = try repo.loadWorkspaceRuntime(c, mission.workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "Runtime do workspace não encontrado.",
            .{ .status = .bad_request },
        );
    }

    try repo.reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try repo.loadWorkspaceRuntime(c, mission.workspace_id);

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

    const max_attempts: usize = if (std.mem.eql(u8, mission.execution_mode, "autopilot")) 300 else 8;
    var messages_result: core.RuntimeCommandResult = .{
        .ok = false,
        .exit_code = -1,
        .stdout = "",
        .stderr = "",
    };
    var review_text: ?[]const u8 = null;
    var attempt: usize = 0;

    while (attempt < max_attempts and review_text == null) : (attempt += 1) {
        messages_result = core.runRuntimeCommand(c, &.{
            "curl",
            "-fsS",
            messages_url,
        });

        if (!messages_result.ok) break;

        review_text = try helpers.extractAssistantTextForParentMessage(
            c.arena,
            messages_result.stdout,
            dispatch_trace.reviewer_dispatch_user_message_id,
        );

        if (review_text == null and attempt + 1 < max_attempts) {
            std.Io.sleep(c._io, std.Io.Duration.fromMilliseconds(200), .real) catch {};
        }
    }

    try repo.insertRuntimeCommandLog(
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

    const review_text_value = review_text orelse {
        return c.text(
            "Nenhuma resposta textual vinculada ao último despacho rastreado foi encontrada. Aguarde o Reviewer concluir a resposta e tente novamente.",
            .{ .status = .bad_request },
        );
    };

    try repo.updateMissionAfterReviewerReportCapture(c, review_text_value, mission_id);

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Review Report do Reviewer foi capturado a partir da sessão {s}.",
        .{reviewer.session_external_id},
    );

    try repo.insertMissionEvent(c, mission_id, mission.workspace_id, "reviewer-review-report-captured", "Review Report do Reviewer capturado", event_message);

    if (std.mem.eql(u8, mission.execution_mode, "autopilot")) {
        const next_url = try std.fmt.allocPrint(c.arena, "/missions/{d}/next-step", .{mission_id});
        return c.redirect(next_url);
    }

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}",
        .{mission_id},
    );

    return c.redirect(redirect_url);
}

pub fn captureExecutorReport(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const mission_rows = try repo.getMissionById(c, mission_id);

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

    const executor_rows = try repo.getPaneByRole(c, mission.workspace_id, "Executor");

    if (executor_rows.len == 0 or executor_rows[0].session_external_id.len == 0) {
        return c.text(
            "O pane Executor não possui sessão disponível.",
            .{ .status = .bad_request },
        );
    }

    const executor = executor_rows[0];

    const dispatch_trace_rows = try repo.getExecutorDispatchTrace(c, mission_id);

    if (dispatch_trace_rows.len == 0 or
        dispatch_trace_rows[0].executor_dispatch_user_message_id.len == 0)
    {
        return c.text(
            "Esta missão ainda não possui rastreio do despacho ao Executor. Reenvie o Review Report antes de capturar a verificação.",
            .{ .status = .bad_request },
        );
    }

    const dispatch_trace = dispatch_trace_rows[0];
    const runtime_rows = try repo.loadWorkspaceRuntime(c, mission.workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "Runtime do workspace não encontrado.",
            .{ .status = .bad_request },
        );
    }

    try repo.reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try repo.loadWorkspaceRuntime(c, mission.workspace_id);

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

    const max_attempts: usize = if (std.mem.eql(u8, mission.execution_mode, "autopilot")) 300 else 8;
    var messages_result: core.RuntimeCommandResult = .{
        .ok = false,
        .exit_code = -1,
        .stdout = "",
        .stderr = "",
    };
    var verification_report_text: ?[]const u8 = null;
    var attempt: usize = 0;

    while (attempt < max_attempts and verification_report_text == null) : (attempt += 1) {
        messages_result = core.runRuntimeCommand(c, &.{
            "curl",
            "-fsS",
            messages_url,
        });

        if (!messages_result.ok) break;

        verification_report_text = try helpers.extractAssistantTextForParentMessage(
            c.arena,
            messages_result.stdout,
            dispatch_trace.executor_dispatch_user_message_id,
        );

        if (verification_report_text == null and attempt + 1 < max_attempts) {
            std.Io.sleep(c._io, std.Io.Duration.fromMilliseconds(200), .real) catch {};
        }
    }

    try repo.insertRuntimeCommandLog(
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

    const verification_report_text_value = verification_report_text orelse {
        return c.text(
            "Nenhuma resposta textual vinculada ao último despacho rastreado foi encontrada. Aguarde o Executor concluir a resposta e tente novamente.",
            .{ .status = .bad_request },
        );
    };

    try repo.updateMissionAfterExecutorReportCapture(c, verification_report_text_value, mission_id);

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Verification Report do Executor foi capturado a partir da sessão {s}.",
        .{executor.session_external_id},
    );

    try repo.insertMissionEvent(c, mission_id, mission.workspace_id, "executor-verification-report-captured", "Verification Report do Executor capturado", event_message);

    if (std.mem.eql(u8, mission.execution_mode, "autopilot")) {
        const next_url = try std.fmt.allocPrint(c.arena, "/missions/{d}/next-step", .{mission_id});
        return c.redirect(next_url);
    }

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}",
        .{mission_id},
    );

    return c.redirect(redirect_url);
}

pub fn capturePilotDeliveryReport(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const mission_rows = try repo.getMissionById(c, mission_id);

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

    const pilot_rows = try repo.getPaneByRole(c, mission.workspace_id, "Piloto");

    if (pilot_rows.len == 0 or pilot_rows[0].session_external_id.len == 0) {
        return c.text(
            "O pane Piloto não possui sessão disponível.",
            .{ .status = .bad_request },
        );
    }

    const pilot = pilot_rows[0];

    const dispatch_trace_rows = try repo.getPilotDeliveryDispatchTrace(c, mission_id);

    if (dispatch_trace_rows.len == 0 or
        dispatch_trace_rows[0].pilot_delivery_dispatch_user_message_id.len == 0)
    {
        return c.text(
            "Esta missão ainda não possui rastreio do despacho final ao Piloto. Reenvie o Verification Report antes de capturar a entrega.",
            .{ .status = .bad_request },
        );
    }

    const dispatch_trace = dispatch_trace_rows[0];
    const runtime_rows = try repo.loadWorkspaceRuntime(c, mission.workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "Runtime do workspace não encontrado.",
            .{ .status = .bad_request },
        );
    }

    try repo.reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try repo.loadWorkspaceRuntime(c, mission.workspace_id);

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

    const max_attempts: usize = if (std.mem.eql(u8, mission.execution_mode, "autopilot")) 300 else 8;
    var messages_result: core.RuntimeCommandResult = .{
        .ok = false,
        .exit_code = -1,
        .stdout = "",
        .stderr = "",
    };
    var delivery_text: ?[]const u8 = null;
    var attempt: usize = 0;

    while (attempt < max_attempts and delivery_text == null) : (attempt += 1) {
        messages_result = core.runRuntimeCommand(c, &.{
            "curl",
            "-fsS",
            messages_url,
        });

        if (!messages_result.ok) break;

        delivery_text = try helpers.extractAssistantTextForParentMessage(
            c.arena,
            messages_result.stdout,
            dispatch_trace.pilot_delivery_dispatch_user_message_id,
        );

        if (delivery_text == null and attempt + 1 < max_attempts) {
            std.Io.sleep(c._io, std.Io.Duration.fromMilliseconds(200), .real) catch {};
        }
    }

    try repo.insertRuntimeCommandLog(
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

    const delivery_text_value = delivery_text orelse {
        return c.text(
            "Nenhuma resposta textual vinculada ao último despacho final foi encontrada. Aguarde o Piloto concluir a entrega e tente novamente.",
            .{ .status = .bad_request },
        );
    };

    try repo.updateMissionAfterPilotDeliveryReportCapture(c, delivery_text_value, mission_id);

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Final Delivery Report do Piloto foi capturado a partir da sessão {s}.",
        .{pilot.session_external_id},
    );

    try repo.insertMissionEvent(c, mission_id, mission.workspace_id, "pilot-delivery-report-captured", "Final Delivery Report do Piloto capturado", event_message);

    if (std.mem.eql(u8, mission.execution_mode, "autopilot")) {
        const next_url = try std.fmt.allocPrint(c.arena, "/missions/{d}/next-step", .{mission_id});
        return c.redirect(next_url);
    }

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}",
        .{mission_id},
    );

    return c.redirect(redirect_url);
}
