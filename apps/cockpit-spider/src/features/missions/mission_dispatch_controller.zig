const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const core = @import("core");
const helpers = @import("../../shared/helpers.zig");
const model = @import("./mission_model.zig");
const repo = @import("./mission_repository.zig");

pub fn activate(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const mission_id_raw = c.params.get("mission_id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, mission_id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const mission_rows = try repo.getMissionActivationTarget(c, mission_id, workspace_id);

    if (mission_rows.len == 0) {
        return c.text("Missão não encontrada neste workspace.", .{ .status = .not_found });
    }

    if (std.mem.eql(u8, mission_rows[0].mission_operational_closure_status, "closed")) {
        return c.text(
            "Missões encerradas operacionalmente não podem ser reativadas no Cockpit.",
            .{ .status = .bad_request },
        );
    }

    try repo.activateMissionForWorkspace(c, mission_id, workspace_id);

    try repo.insertMissionEvent(c, mission_id, workspace_id, "mission-activated-in-cockpit", "Missão ativada no Cockpit", "Esta missão foi definida como foco operacional ativo do workspace.");

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/workspaces/{d}",
        .{workspace_id},
    );

    return c.redirect(redirect_url);
}

pub fn dispatchToPilot(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const mission_id_raw = c.params.get("mission_id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, mission_id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const active_mission_rows = try repo.getActiveMissionForWorkspace(c, workspace_id, mission_id);

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

    const pilot_rows = try repo.getPaneByRole(c, workspace_id, "Piloto");

    if (pilot_rows.len == 0) {
        return c.text(
            "O pane Piloto ainda não foi materializado neste workspace.",
            .{ .status = .bad_request },
        );
    }

    const pilot = pilot_rows[0];

    if (pilot.session_external_id.len == 0) {
        return c.text(
            "O pane Piloto não possui sessão OpenCode vinculada.",
            .{ .status = .bad_request },
        );
    }

    if (!std.mem.eql(u8, pilot.context_state, "current")) {
        return c.text(
            "O contexto do pane Piloto está desatualizado. Recrie a sessão antes de enviar a missão.",
            .{ .status = .bad_request },
        );
    }

    const runtime_rows = try repo.loadWorkspaceRuntime(c, workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "O runtime deste workspace ainda não foi preparado.",
            .{ .status = .bad_request },
        );
    }

    try repo.reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try repo.loadWorkspaceRuntime(c, workspace_id);

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

    if (!std.mem.eql(u8, pilot.pane_state, "active")) {
        if (std.mem.eql(u8, pilot.pane_state, "stale")) {
            const validate = helpers.openCodeSessionExists(c, runtime.server_url_label, pilot.session_external_id);
            try repo.insertRuntimeCommandLog(c, workspace_id, "opencode-validate-pane-session", "GET <opencode-server>/session/<session-id>", validate);
            if (validate.ok) {
                try repo.updatePaneState(c, pilot.id, workspace_id, "active");
            } else {
                return c.text("A sessão do pane Piloto não existe mais no OpenCode. Recrie a sessão antes de despachar.", .{ .status = .bad_request });
            }
        } else {
            return c.text("O pane Piloto precisa estar ativo para receber a missão.", .{ .status = .bad_request });
        }
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
             "Não implemente código diretamente neste primeiro retorno. " ++
             "Sempre finalize sua resposta com um relatório textual completo, mesmo após usar ferramentas.",
        .{
            mission.workspace_name,
            mission.squad_name,
            mission.title,
            mission.objective,
            mission.status,
            mission.priority,
        },
    );

    const prompt_parts = [_]model.OpenCodeTextPart{
        .{
            .type = "text",
            .text = mission_prompt,
        },
    };

    const prompt_body = try std.json.Stringify.valueAlloc(
        c.arena,
        model.OpenCodePromptAsyncRequest{
            .model = model.open_code_prompt_model,
            .parts = prompt_parts[0..],
        },
        .{},
    );

    const prompt_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/prompt_async",
        .{ runtime.server_url_label, pilot.session_external_id },
    );

    const dispatch_result = core.runRuntimeCommand(c, &.{
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

    try repo.insertRuntimeCommandLog(
        c,
        workspace_id,
        "opencode-dispatch-active-mission-to-pilot",
        "POST <opencode-server>/session/<session-id>/prompt_async",
        dispatch_result,
    );

    if (!dispatch_result.ok) {
        try repo.setPilotDispatchError(c, mission_id);

        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "mission-dispatch-error",
            "Falha ao enviar missão ao Piloto",
            "O OpenCode Server não confirmou o envio assíncrono da missão ativa.",
        );

        try repo.insertMissionEvent(c, mission_id, workspace_id, "mission-dispatch-to-pilot-error", "Falha ao enviar missão ao Piloto", "O despacho assíncrono ao pane Piloto não foi confirmado pelo OpenCode Server.");

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
        const dispatch_messages_result = core.runRuntimeCommand(c, &.{
            "curl",
            "-fsS",
            dispatch_messages_url,
        });

        if (dispatch_messages_result.ok) {
            if (try helpers.extractLatestUserMessageIdMatchingText(
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

    if (dispatch_user_message_id.len == 0) {
        try repo.setPilotDispatchError(c, mission_id);

        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "mission-dispatch-error",
            "Falha ao rastrear envio da missão ao Piloto",
            "O sistema não conseguiu confirmar a criação da mensagem de despacho na sessão do Piloto.",
        );

        try repo.insertMissionEvent(c, mission_id, workspace_id, "mission-dispatch-to-pilot-error", "Falha ao rastrear mensagem de despacho", "O sistema não conseguiu localizar a mensagem de despacho na sessão do Piloto (pilot_dispatch_user_message_id) após o envio.");

        return c.text(
            "Falha ao rastrear a mensagem de despacho na sessão do Piloto.",
            .{ .status = .bad_request },
        );
    }

    try repo.updateMissionAfterPilotDispatch(c, pilot.session_external_id, dispatch_user_message_id, mission_id);

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "A missão ativa \"{s}\" foi enviada ao pane Piloto na sessão {s}.",
        .{ mission.title, pilot.session_external_id },
    );

    try helpers.insertRuntimeEvent(
        c,
        workspace_id,
        "mission-dispatched-to-pilot",
        "Missão enviada ao Piloto",
        event_message,
    );

    try repo.insertMissionEvent(c, mission_id, workspace_id, "mission-dispatched-to-pilot", "Missão enviada ao Piloto", event_message);

    const pilot_session_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/Lw/session/{s}",
        .{ runtime.server_url_label, pilot.session_external_id },
    );

    if (std.mem.eql(u8, mission.execution_mode, "autopilot")) {
        const next_url = try std.fmt.allocPrint(c.arena, "/missions/{d}/next-step", .{mission_id});
        return c.redirect(next_url);
    }
    return c.redirect(pilot_session_url);
}

pub fn dispatchPilotBriefToPlanner(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const mission_id_raw = c.params.get("mission_id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, mission_id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const active_mission_rows = try repo.getActiveMissionForWorkspace(c, workspace_id, mission_id);

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

    if (mission.pilot_operational_brief.len == 0 or
        !std.mem.eql(u8, mission.pilot_operational_brief_status, "captured"))
    {
        return c.text(
            "Capture o Briefing Operacional do Piloto antes de enviá-lo ao Planner.",
            .{ .status = .bad_request },
        );
    }

    const planner_rows = try repo.getPaneByRole(c, workspace_id, "Planner");

    if (planner_rows.len == 0) {
        return c.text(
            "O pane Planner ainda não foi materializado neste workspace.",
            .{ .status = .bad_request },
        );
    }

    const planner = planner_rows[0];

    if (planner.session_external_id.len == 0) {
        return c.text(
            "O pane Planner não possui sessão OpenCode vinculada.",
            .{ .status = .bad_request },
        );
    }

    if (!std.mem.eql(u8, planner.context_state, "current")) {
        return c.text(
            "O contexto do pane Planner está desatualizado. Recrie a sessão antes de enviar o briefing.",
            .{ .status = .bad_request },
        );
    }

    const runtime_rows = try repo.loadWorkspaceRuntime(c, workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "O runtime deste workspace ainda não foi preparado.",
            .{ .status = .bad_request },
        );
    }

    try repo.reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try repo.loadWorkspaceRuntime(c, workspace_id);

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

    if (!std.mem.eql(u8, planner.pane_state, "active")) {
        if (std.mem.eql(u8, planner.pane_state, "stale")) {
            const validate = helpers.openCodeSessionExists(c, runtime.server_url_label, planner.session_external_id);
            try repo.insertRuntimeCommandLog(c, workspace_id, "opencode-validate-pane-session", "GET <opencode-server>/session/<session-id>", validate);
            if (validate.ok) {
                try repo.updatePaneState(c, planner.id, workspace_id, "active");
            } else {
                return c.text("A sessão do pane Planner não existe mais no OpenCode. Recrie a sessão antes de despachar.", .{ .status = .bad_request });
            }
        } else {
            return c.text("O pane Planner precisa estar ativo para receber o briefing.", .{ .status = .bad_request });
        }
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
             "Não implemente código neste retorno. " ++
             "Sempre finalize sua resposta com um relatório textual completo, mesmo após usar ferramentas.",
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

    const prompt_parts = [_]model.OpenCodeTextPart{
        .{
            .type = "text",
            .text = planner_prompt,
        },
    };

    const prompt_body = try std.json.Stringify.valueAlloc(
        c.arena,
        model.OpenCodePromptAsyncRequest{
            .model = model.open_code_prompt_model,
            .parts = prompt_parts[0..],
        },
        .{},
    );

    const prompt_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/prompt_async",
        .{ runtime.server_url_label, planner.session_external_id },
    );

    const dispatch_result = core.runRuntimeCommand(c, &.{
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

    try repo.insertRuntimeCommandLog(
        c,
        workspace_id,
        "opencode-dispatch-pilot-brief-to-planner",
        "POST <opencode-server>/session/<session-id>/prompt_async",
        dispatch_result,
    );

    if (!dispatch_result.ok) {
        try repo.setPlannerDispatchError(c, mission_id);

        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "planner-dispatch-error",
            "Falha ao enviar briefing ao Planner",
            "O OpenCode Server não confirmou o envio assíncrono do briefing ao pane Planner.",
        );

        try repo.insertMissionEvent(c, mission_id, workspace_id, "pilot-brief-dispatch-to-planner-error", "Falha ao enviar briefing ao Planner", "O despacho assíncrono do briefing ao pane Planner não foi confirmado pelo OpenCode Server.");

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
        const dispatch_messages_result = core.runRuntimeCommand(c, &.{
            "curl",
            "-fsS",
            dispatch_messages_url,
        });

        if (dispatch_messages_result.ok) {
            if (try helpers.extractLatestUserMessageIdMatchingText(
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

    if (planner_dispatch_user_message_id.len == 0) {
        try repo.setPlannerDispatchError(c, mission_id);

        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "mission-dispatch-error",
            "Falha ao rastrear envio do briefing ao Planner",
            "O sistema não conseguiu confirmar a criação da mensagem de despacho na sessão do Planner.",
        );

        try repo.insertMissionEvent(c, mission_id, workspace_id, "mission-dispatch-to-planner-error", "Falha ao rastrear mensagem de despacho", "O sistema não conseguiu localizar a mensagem de despacho na sessão do Planner (planner_dispatch_user_message_id) após o envio.");

        return c.text(
            "Falha ao rastrear a mensagem de despacho na sessão do Planner.",
            .{ .status = .bad_request },
        );
    }

    try repo.updateMissionAfterPlannerDispatch(c, planner.session_external_id, planner_dispatch_user_message_id, mission_id);

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Briefing Operacional do Piloto da missão \"{s}\" foi enviado ao pane Planner na sessão {s}.",
        .{ mission.title, planner.session_external_id },
    );

    try helpers.insertRuntimeEvent(
        c,
        workspace_id,
        "pilot-brief-dispatched-to-planner",
        "Briefing enviado ao Planner",
        event_message,
    );

    try repo.insertMissionEvent(c, mission_id, workspace_id, "pilot-brief-dispatched-to-planner", "Briefing enviado ao Planner", event_message);

    const planner_session_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/Lw/session/{s}",
        .{ runtime.server_url_label, planner.session_external_id },
    );

    if (std.mem.eql(u8, mission.execution_mode, "autopilot")) {
        const next_url = try std.fmt.allocPrint(c.arena, "/missions/{d}/next-step", .{mission_id});
        return c.redirect(next_url);
    }
    return c.redirect(planner_session_url);
}

pub fn dispatchPlannerPlanToScout(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const mission_id_raw = c.params.get("mission_id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, mission_id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const active_mission_rows = try repo.getActiveMissionForWorkspace(c, workspace_id, mission_id);

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

    if (mission.planner_operational_plan.len == 0 or
        !std.mem.eql(u8, mission.planner_operational_plan_status, "captured"))
    {
        return c.text(
            "Capture o Plano Operacional do Planner antes de enviá-lo ao Scout.",
            .{ .status = .bad_request },
        );
    }

    const scout_rows = try repo.getPaneByRole(c, workspace_id, "Scout");

    if (scout_rows.len == 0) {
        return c.text(
            "O pane Scout ainda não foi materializado neste workspace.",
            .{ .status = .bad_request },
        );
    }

    const scout = scout_rows[0];

    if (scout.session_external_id.len == 0) {
        return c.text(
            "O pane Scout não possui sessão OpenCode vinculada.",
            .{ .status = .bad_request },
        );
    }

    if (!std.mem.eql(u8, scout.context_state, "current")) {
        return c.text(
            "O contexto do pane Scout está desatualizado. Recrie a sessão antes de enviar o plano.",
            .{ .status = .bad_request },
        );
    }

    const runtime_rows = try repo.loadWorkspaceRuntime(c, workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "O runtime deste workspace ainda não foi preparado.",
            .{ .status = .bad_request },
        );
    }

    try repo.reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try repo.loadWorkspaceRuntime(c, workspace_id);

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

    if (!std.mem.eql(u8, scout.pane_state, "active")) {
        if (std.mem.eql(u8, scout.pane_state, "stale")) {
            const validate = helpers.openCodeSessionExists(c, runtime.server_url_label, scout.session_external_id);
            try repo.insertRuntimeCommandLog(c, workspace_id, "opencode-validate-pane-session", "GET <opencode-server>/session/<session-id>", validate);
            if (validate.ok) {
                try repo.updatePaneState(c, scout.id, workspace_id, "active");
            } else {
                return c.text("A sessão do pane Scout não existe mais no OpenCode. Recrie a sessão antes de despachar.", .{ .status = .bad_request });
            }
        } else {
            return c.text("O pane Scout precisa estar ativo para receber o plano.", .{ .status = .bad_request });
        }
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
             "Não implemente código neste retorno. " ++
             "Sempre finalize sua resposta com um relatório textual completo, mesmo após executar comandos ou ferramentas.",
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

    const prompt_parts = [_]model.OpenCodeTextPart{
        .{
            .type = "text",
            .text = scout_prompt,
        },
    };

    const prompt_body = try std.json.Stringify.valueAlloc(
        c.arena,
        model.OpenCodePromptAsyncRequest{
            .model = model.open_code_prompt_model,
            .parts = prompt_parts[0..],
        },
        .{},
    );

    const prompt_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/prompt_async",
        .{ runtime.server_url_label, scout.session_external_id },
    );

    const dispatch_result = core.runRuntimeCommand(c, &.{
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

    try repo.insertRuntimeCommandLog(
        c,
        workspace_id,
        "opencode-dispatch-planner-plan-to-scout",
        "POST <opencode-server>/session/<session-id>/prompt_async",
        dispatch_result,
    );

    if (!dispatch_result.ok) {
        try repo.setScoutDispatchError(c, mission_id);

        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "scout-dispatch-error",
            "Falha ao enviar plano ao Scout",
            "O OpenCode Server não confirmou o envio assíncrono do plano ao pane Scout.",
        );

        try repo.insertMissionEvent(c, mission_id, workspace_id, "planner-plan-dispatch-to-scout-error", "Falha ao enviar plano ao Scout", "O despacho assíncrono do plano ao pane Scout não foi confirmado pelo OpenCode Server.");

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
        const dispatch_messages_result = core.runRuntimeCommand(c, &.{
            "curl",
            "-fsS",
            dispatch_messages_url,
        });

        if (dispatch_messages_result.ok) {
            if (try helpers.extractLatestUserMessageIdMatchingText(
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

    if (scout_dispatch_user_message_id.len == 0) {
        try repo.setScoutDispatchError(c, mission_id);

        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "mission-dispatch-error",
            "Falha ao rastrear envio do plano ao Scout",
            "O sistema não conseguiu confirmar a criação da mensagem de despacho na sessão do Scout.",
        );

        try repo.insertMissionEvent(c, mission_id, workspace_id, "mission-dispatch-to-scout-error", "Falha ao rastrear mensagem de despacho", "O sistema não conseguiu localizar a mensagem de despacho na sessão do Scout (scout_dispatch_user_message_id) após o envio.");

        return c.text(
            "Falha ao rastrear a mensagem de despacho na sessão do Scout.",
            .{ .status = .bad_request },
        );
    }

    try repo.updateMissionAfterScoutDispatch(c, scout.session_external_id, scout_dispatch_user_message_id, mission_id);

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Plano Operacional do Planner da missão \"{s}\" foi enviado ao pane Scout na sessão {s}.",
        .{ mission.title, scout.session_external_id },
    );

    try helpers.insertRuntimeEvent(
        c,
        workspace_id,
        "planner-plan-dispatched-to-scout",
        "Plano enviado ao Scout",
        event_message,
    );

    try repo.insertMissionEvent(c, mission_id, workspace_id, "planner-plan-dispatched-to-scout", "Plano enviado ao Scout", event_message);

    const scout_session_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/Lw/session/{s}",
        .{ runtime.server_url_label, scout.session_external_id },
    );

    if (std.mem.eql(u8, mission.execution_mode, "autopilot")) {
        const next_url = try std.fmt.allocPrint(c.arena, "/missions/{d}/next-step", .{mission_id});
        return c.redirect(next_url);
    }
    return c.redirect(scout_session_url);
}

pub fn dispatchScoutReportToBuilder(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const mission_id_raw = c.params.get("mission_id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, mission_id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const active_mission_rows = try repo.getActiveMissionForWorkspace(c, workspace_id, mission_id);

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

    if (mission.scout_report.len == 0 or
        !std.mem.eql(u8, mission.scout_report_status, "captured"))
    {
        return c.text(
            "Capture o Scout Report antes de enviá-lo ao Builder.",
            .{ .status = .bad_request },
        );
    }

    const builder_rows = try repo.getPaneByRole(c, workspace_id, "Builder");

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

    const runtime_rows = try repo.loadWorkspaceRuntime(c, workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "O runtime deste workspace ainda não foi preparado.",
            .{ .status = .bad_request },
        );
    }

    try repo.reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try repo.loadWorkspaceRuntime(c, workspace_id);

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
            "4) riscos remanescentes, 5) comandos ou validações recomendadas para o Executor. " ++
             "Sempre finalize sua resposta com um relatório textual completo, mesmo após executar comandos.",
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

    const prompt_parts = [_]model.OpenCodeTextPart{
        .{
            .type = "text",
            .text = builder_prompt,
        },
    };

    const prompt_body = try std.json.Stringify.valueAlloc(
        c.arena,
        model.OpenCodePromptAsyncRequest{
            .model = model.open_code_prompt_model,
            .parts = prompt_parts[0..],
        },
        .{},
    );

    const prompt_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/prompt_async",
        .{ runtime.server_url_label, builder.session_external_id },
    );

    const dispatch_result = core.runRuntimeCommand(c, &.{
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

    try repo.insertRuntimeCommandLog(
        c,
        workspace_id,
        "opencode-dispatch-scout-report-to-builder",
        "POST <opencode-server>/session/<session-id>/prompt_async",
        dispatch_result,
    );

    if (!dispatch_result.ok) {
        try repo.setBuilderDispatchError(c, mission_id);

        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "builder-dispatch-error",
            "Falha ao enviar pacote ao Builder",
            "O OpenCode Server não confirmou o envio assíncrono do pacote de execução ao pane Builder.",
        );

        try repo.insertMissionEvent(c, mission_id, workspace_id, "scout-report-dispatch-to-builder-error", "Falha ao enviar pacote ao Builder", "O despacho assíncrono do pacote de execução ao pane Builder não foi confirmado pelo OpenCode Server.");

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
        const dispatch_messages_result = core.runRuntimeCommand(c, &.{
            "curl",
            "-fsS",
            dispatch_messages_url,
        });

        if (dispatch_messages_result.ok) {
            if (try helpers.extractLatestUserMessageIdMatchingText(
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

    if (builder_dispatch_user_message_id.len == 0) {
        try repo.setBuilderDispatchError(c, mission_id);

        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "mission-dispatch-error",
            "Falha ao rastrear envio do pacote ao Builder",
            "O sistema não conseguiu confirmar a criação da mensagem de despacho na sessão do Builder.",
        );

        try repo.insertMissionEvent(c, mission_id, workspace_id, "mission-dispatch-to-builder-error", "Falha ao rastrear mensagem de despacho", "O sistema não conseguiu localizar a mensagem de despacho na sessão do Builder (builder_dispatch_user_message_id) após o envio.");

        return c.text(
            "Falha ao rastrear a mensagem de despacho na sessão do Builder.",
            .{ .status = .bad_request },
        );
    }

    try repo.updateMissionAfterBuilderDispatch(c, builder.session_external_id, builder_dispatch_user_message_id, mission_id);

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O pacote de execução da missão \"{s}\" foi enviado ao pane Builder na sessão {s}.",
        .{ mission.title, builder.session_external_id },
    );

    try helpers.insertRuntimeEvent(
        c,
        workspace_id,
        "execution-package-dispatched-to-builder",
        "Pacote enviado ao Builder",
        event_message,
    );

    try repo.insertMissionEvent(c, mission_id, workspace_id, "execution-package-dispatched-to-builder", "Pacote enviado ao Builder", event_message);

    const builder_session_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/Lw/session/{s}",
        .{ runtime.server_url_label, builder.session_external_id },
    );

    if (std.mem.eql(u8, mission.execution_mode, "autopilot")) {
        const next_url = try std.fmt.allocPrint(c.arena, "/missions/{d}/next-step", .{mission_id});
        return c.redirect(next_url);
    }
    return c.redirect(builder_session_url);
}

pub fn dispatchBuilderReportToReviewer(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const mission_id_raw = c.params.get("mission_id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, mission_id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const active_mission_rows = try repo.getActiveMissionForWorkspace(c, workspace_id, mission_id);

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

    if (mission.builder_implementation_report.len == 0 or
        !std.mem.eql(u8, mission.builder_implementation_report_status, "captured"))
    {
        return c.text(
            "Capture o Implementation Report do Builder antes de enviá-lo ao Reviewer.",
            .{ .status = .bad_request },
        );
    }

    const reviewer_rows = try repo.getPaneByRole(c, workspace_id, "Reviewer");

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

    const runtime_rows = try repo.loadWorkspaceRuntime(c, workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "O runtime deste workspace ainda não foi preparado.",
            .{ .status = .bad_request },
        );
    }

    try repo.reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try repo.loadWorkspaceRuntime(c, workspace_id);

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
             "Não implemente código neste retorno. " ++
             "Sempre finalize sua resposta com um relatório textual completo, mesmo após usar ferramentas.",
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

    const prompt_parts = [_]model.OpenCodeTextPart{
        .{
            .type = "text",
            .text = reviewer_prompt,
        },
    };

    const prompt_body = try std.json.Stringify.valueAlloc(
        c.arena,
        model.OpenCodePromptAsyncRequest{
            .model = model.open_code_prompt_model,
            .parts = prompt_parts[0..],
        },
        .{},
    );

    const prompt_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/prompt_async",
        .{ runtime.server_url_label, reviewer.session_external_id },
    );

    const dispatch_result = core.runRuntimeCommand(c, &.{
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

    try repo.insertRuntimeCommandLog(
        c,
        workspace_id,
        "opencode-dispatch-builder-report-to-reviewer",
        "POST <opencode-server>/session/<session-id>/prompt_async",
        dispatch_result,
    );

    if (!dispatch_result.ok) {
        try repo.setReviewerDispatchError(c, mission_id);

        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "reviewer-dispatch-error",
            "Falha ao enviar relatório ao Reviewer",
            "O OpenCode Server não confirmou o envio assíncrono do Implementation Report ao pane Reviewer.",
        );

        try repo.insertMissionEvent(c, mission_id, workspace_id, "builder-report-dispatch-to-reviewer-error", "Falha ao enviar relatório ao Reviewer", "O despacho assíncrono do Implementation Report ao pane Reviewer não foi confirmado pelo OpenCode Server.");

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
        const dispatch_messages_result = core.runRuntimeCommand(c, &.{
            "curl",
            "-fsS",
            dispatch_messages_url,
        });

        if (dispatch_messages_result.ok) {
            if (try helpers.extractLatestUserMessageIdMatchingText(
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

    if (reviewer_dispatch_user_message_id.len == 0) {
        try repo.setReviewerDispatchError(c, mission_id);

        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "mission-dispatch-error",
            "Falha ao rastrear envio do Implementation Report ao Reviewer",
            "O sistema não conseguiu confirmar a criação da mensagem de despacho na sessão do Reviewer.",
        );

        try repo.insertMissionEvent(c, mission_id, workspace_id, "mission-dispatch-to-reviewer-error", "Falha ao rastrear mensagem de despacho", "O sistema não conseguiu localizar a mensagem de despacho na sessão do Reviewer (reviewer_dispatch_user_message_id) após o envio.");

        return c.text(
            "Falha ao rastrear a mensagem de despacho na sessão do Reviewer.",
            .{ .status = .bad_request },
        );
    }

    try repo.updateMissionAfterReviewerDispatch(c, reviewer.session_external_id, reviewer_dispatch_user_message_id, mission_id);

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Implementation Report do Builder da missão \"{s}\" foi enviado ao pane Reviewer na sessão {s}.",
        .{ mission.title, reviewer.session_external_id },
    );

    try helpers.insertRuntimeEvent(
        c,
        workspace_id,
        "builder-report-dispatched-to-reviewer",
        "Implementation Report enviado ao Reviewer",
        event_message,
    );

    try repo.insertMissionEvent(c, mission_id, workspace_id, "builder-report-dispatched-to-reviewer", "Implementation Report enviado ao Reviewer", event_message);

    const reviewer_session_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/Lw/session/{s}",
        .{ runtime.server_url_label, reviewer.session_external_id },
    );

    if (std.mem.eql(u8, mission.execution_mode, "autopilot")) {
        const next_url = try std.fmt.allocPrint(c.arena, "/missions/{d}/next-step", .{mission_id});
        return c.redirect(next_url);
    }
    return c.redirect(reviewer_session_url);
}

pub fn dispatchReviewerReportToExecutor(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const mission_id_raw = c.params.get("mission_id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, mission_id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const active_mission_rows = try repo.getActiveMissionForWorkspace(c, workspace_id, mission_id);

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

    if (mission.reviewer_review_report.len == 0 or
        !std.mem.eql(u8, mission.reviewer_review_report_status, "captured"))
    {
        return c.text(
            "Capture o Review Report do Reviewer antes de enviá-lo ao Executor.",
            .{ .status = .bad_request },
        );
    }

    const executor_rows = try repo.getPaneByRole(c, workspace_id, "Executor");

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

    const runtime_rows = try repo.loadWorkspaceRuntime(c, workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "O runtime deste workspace ainda não foi preparado.",
            .{ .status = .bad_request },
        );
    }

    try repo.reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try repo.loadWorkspaceRuntime(c, workspace_id);

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
             "Não implemente código neste retorno. " ++
             "Sempre finalize sua resposta com um relatório textual completo, mesmo após executar comandos.",
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

    const prompt_parts = [_]model.OpenCodeTextPart{
        .{
            .type = "text",
            .text = executor_prompt,
        },
    };

    const prompt_body = try std.json.Stringify.valueAlloc(
        c.arena,
        model.OpenCodePromptAsyncRequest{
            .model = model.open_code_prompt_model,
            .parts = prompt_parts[0..],
        },
        .{},
    );

    const prompt_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/prompt_async",
        .{ runtime.server_url_label, executor.session_external_id },
    );

    const dispatch_result = core.runRuntimeCommand(c, &.{
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

    try repo.insertRuntimeCommandLog(
        c,
        workspace_id,
        "opencode-dispatch-reviewer-report-to-executor",
        "POST <opencode-server>/session/<session-id>/prompt_async",
        dispatch_result,
    );

    if (!dispatch_result.ok) {
        try repo.setExecutorDispatchError(c, mission_id);

        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "executor-dispatch-error",
            "Falha ao enviar pacote ao Executor",
            "O OpenCode Server não confirmou o envio assíncrono do pacote de verificação ao pane Executor.",
        );

        try repo.insertMissionEvent(c, mission_id, workspace_id, "reviewer-report-dispatch-to-executor-error", "Falha ao enviar pacote ao Executor", "O despacho assíncrono do Review Report ao pane Executor não foi confirmado pelo OpenCode Server.");

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
        const dispatch_messages_result = core.runRuntimeCommand(c, &.{
            "curl",
            "-fsS",
            dispatch_messages_url,
        });

        if (dispatch_messages_result.ok) {
            if (try helpers.extractLatestUserMessageIdMatchingText(
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

    if (executor_dispatch_user_message_id.len == 0) {
        try repo.setExecutorDispatchError(c, mission_id);

        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "mission-dispatch-error",
            "Falha ao rastrear envio do Review Report ao Executor",
            "O sistema não conseguiu confirmar a criação da mensagem de despacho na sessão do Executor.",
        );

        try repo.insertMissionEvent(c, mission_id, workspace_id, "mission-dispatch-to-executor-error", "Falha ao rastrear mensagem de despacho", "O sistema não conseguiu localizar a mensagem de despacho na sessão do Executor (executor_dispatch_user_message_id) após o envio.");

        return c.text(
            "Falha ao rastrear a mensagem de despacho na sessão do Executor.",
            .{ .status = .bad_request },
        );
    }

    try repo.updateMissionAfterExecutorDispatch(c, executor.session_external_id, executor_dispatch_user_message_id, mission_id);

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Review Report da missão \"{s}\" foi enviado ao pane Executor na sessão {s}.",
        .{ mission.title, executor.session_external_id },
    );

    try helpers.insertRuntimeEvent(
        c,
        workspace_id,
        "reviewer-report-dispatched-to-executor",
        "Review Report enviado ao Executor",
        event_message,
    );

    try repo.insertMissionEvent(c, mission_id, workspace_id, "reviewer-report-dispatched-to-executor", "Review Report enviado ao Executor", event_message);

    const executor_session_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/Lw/session/{s}",
        .{ runtime.server_url_label, executor.session_external_id },
    );

    if (std.mem.eql(u8, mission.execution_mode, "autopilot")) {
        const next_url = try std.fmt.allocPrint(c.arena, "/missions/{d}/next-step", .{mission_id});
        return c.redirect(next_url);
    }
    return c.redirect(executor_session_url);
}

pub fn dispatchExecutorReportToPilot(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const mission_id_raw = c.params.get("mission_id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, mission_id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const active_mission_rows = try repo.getActiveMissionForWorkspace(c, workspace_id, mission_id);

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

    if (mission.executor_verification_report.len == 0 or
        !std.mem.eql(u8, mission.executor_verification_report_status, "captured"))
    {
        return c.text(
            "Capture o Verification Report do Executor antes de enviá-lo ao Piloto.",
            .{ .status = .bad_request },
        );
    }

    const pilot_rows = try repo.getPaneByRole(c, workspace_id, "Piloto");

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

    const runtime_rows = try repo.loadWorkspaceRuntime(c, workspace_id);

    if (runtime_rows.len == 0) {
        return c.text(
            "O runtime deste workspace ainda não foi preparado.",
            .{ .status = .bad_request },
        );
    }

    try repo.reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try repo.loadWorkspaceRuntime(c, workspace_id);

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
             "Não implemente código neste retorno. " ++
             "Sempre finalize sua resposta com um relatório textual completo, mesmo após usar ferramentas.",
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

    const prompt_parts = [_]model.OpenCodeTextPart{
        .{
            .type = "text",
            .text = pilot_delivery_prompt,
        },
    };

    const prompt_body = try std.json.Stringify.valueAlloc(
        c.arena,
        model.OpenCodePromptAsyncRequest{
            .model = model.open_code_prompt_model,
            .parts = prompt_parts[0..],
        },
        .{},
    );

    const prompt_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/session/{s}/prompt_async",
        .{ runtime.server_url_label, pilot.session_external_id },
    );

    const dispatch_result = core.runRuntimeCommand(c, &.{
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

    try repo.insertRuntimeCommandLog(
        c,
        workspace_id,
        "opencode-dispatch-executor-report-to-pilot-delivery",
        "POST <opencode-server>/session/<session-id>/prompt_async",
        dispatch_result,
    );

    if (!dispatch_result.ok) {
        try repo.setPilotDeliveryDispatchError(c, mission_id);

        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "pilot-delivery-dispatch-error",
            "Falha ao enviar relatório final ao Piloto",
            "O OpenCode Server não confirmou o envio assíncrono do Verification Report ao pane Piloto.",
        );

        try repo.insertMissionEvent(c, mission_id, workspace_id, "executor-report-dispatch-to-pilot-error", "Falha ao enviar Verification Report ao Piloto", "O despacho assíncrono do Verification Report ao pane Piloto não foi confirmado pelo OpenCode Server.");

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
        const dispatch_messages_result = core.runRuntimeCommand(c, &.{
            "curl",
            "-fsS",
            dispatch_messages_url,
        });

        if (dispatch_messages_result.ok) {
            if (try helpers.extractLatestUserMessageIdMatchingText(
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

    if (pilot_delivery_dispatch_user_message_id.len == 0) {
        try repo.setPilotDeliveryDispatchError(c, mission_id);

        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "mission-dispatch-error",
            "Falha ao rastrear envio do Verification Report ao Piloto",
            "O sistema não conseguiu confirmar a criação da mensagem de despacho na sessão do Piloto.",
        );

        try repo.insertMissionEvent(c, mission_id, workspace_id, "mission-dispatch-to-pilot-delivery-error", "Falha ao rastrear mensagem de despacho", "O sistema não conseguiu localizar a mensagem de despacho na sessão do Piloto (pilot_delivery_dispatch_user_message_id) após o envio.");

        return c.text(
            "Falha ao rastrear a mensagem de despacho na sessão do Piloto.",
            .{ .status = .bad_request },
        );
    }

    try repo.updateMissionAfterPilotDeliveryDispatch(c, pilot.session_external_id, pilot_delivery_dispatch_user_message_id, mission_id);

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "O Verification Report do Executor da missão \"{s}\" foi enviado ao pane Piloto na sessão {s} para consolidação da entrega final.",
        .{ mission.title, pilot.session_external_id },
    );

    try helpers.insertRuntimeEvent(
        c,
        workspace_id,
        "executor-report-dispatched-to-pilot-delivery",
        "Verification Report enviado ao Piloto",
        event_message,
    );

    try repo.insertMissionEvent(c, mission_id, workspace_id, "executor-report-dispatched-to-pilot-delivery", "Verification Report enviado ao Piloto", event_message);

    const pilot_session_url = try std.fmt.allocPrint(
        c.arena,
        "{s}/Lw/session/{s}",
        .{ runtime.server_url_label, pilot.session_external_id },
    );

    if (std.mem.eql(u8, mission.execution_mode, "autopilot")) {
        const next_url = try std.fmt.allocPrint(c.arena, "/missions/{d}/next-step", .{mission_id});
        return c.redirect(next_url);
    }
    return c.redirect(pilot_session_url);
}
