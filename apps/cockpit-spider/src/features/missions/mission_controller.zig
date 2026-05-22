const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const helpers = @import("../../shared/helpers.zig");
const model = @import("./mission_model.zig");
const repo = @import("./mission_repository.zig");

pub fn index(c: *spider.Ctx) !spider.Response {
    const rows = try repo.listMissions(c);

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

fn countOpenMissions(rows: []const model.MissionRow) usize {
    var total: usize = 0;
    for (rows) |row| {
        if (!std.mem.eql(u8, row.mission_operational_closure_status, "closed")) {
            total += 1;
        }
    }
    return total;
}

pub fn newForm(c: *spider.Ctx) !spider.Response {
    const workspaces_rows = try repo.listMissionWorkspaces(c);

    return c.view("missions/new", .{
        .title = "Nova Missão",
        .workspaces = workspaces_rows,
        .workspace_count = workspaces_rows.len,
        .error_message = "",
        .form = .{
            .workspace_id = c.query("workspace_id") orelse "",
            .context_workspace_id = c.query("workspace_id") orelse "",
            .cancel_url = if (c.query("workspace_id")) |workspace_id|
                try std.fmt.allocPrint(c.arena, "/workspaces/{s}", .{workspace_id})
            else
                "/missions",
            .title = "",
            .objective = "",
            .status = "briefing",
            .priority = "normal",
        },
    }, .{});
}

pub fn create(c: *spider.Ctx) !spider.Response {
    const form = try c.parseForm(model.MissionForm);
    const workspaces_rows = try repo.listMissionWorkspaces(c);
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

    const selected_workspace = try repo.getSelectedWorkspaceForMission(c, workspace_id);

    if (selected_workspace.len == 0) {
        return c.view("missions/new", .{
            .title = "Nova Missão",
            .workspaces = workspaces_rows,
            .workspace_count = workspaces_rows.len,
            .error_message = "O workspace selecionado não possui uma squad válida vinculada.",
            .form = form,
        }, .{ .status = .bad_request });
    }

    const created_mission_rows = try repo.createMission(c, workspace_id, selected_workspace[0].default_squad_id, form.title, form.objective, form.priority);

    if (created_mission_rows.len == 0) {
        return c.text("Não foi possível confirmar a criação da missão.", .{ .status = .bad_request });
    }

    const created_mission_id = created_mission_rows[0].id;
    const context_workspace_id = std.fmt.parseInt(i32, form.context_workspace_id, 10) catch 0;

    if (context_workspace_id == workspace_id) {
        const active_rows = try repo.getActiveMissionForActivation(c, workspace_id);

        const should_activate =
            active_rows.len == 0 or
            std.mem.eql(u8, active_rows[0].mission_operational_closure_status, "closed");

        if (should_activate) {
            try repo.activateMissionForWorkspace(c, created_mission_id, workspace_id);

            try repo.insertMissionEvent(c, created_mission_id, workspace_id, "mission-activated-in-cockpit", "Missão ativada no Cockpit", "Esta missão foi criada a partir do workspace e definida automaticamente como foco operacional ativo.");
        }

        const redirect_url = try std.fmt.allocPrint(
            c.arena,
            "/workspaces/{d}?mission_created=1",
            .{workspace_id},
        );

        return c.redirect(redirect_url);
    }

    return c.redirect("/missions?created=1");
}

pub fn show(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    std.log.info("show: calling getMissionById", .{});
    const rows = try repo.getMissionById(c, mission_id);
    std.log.info("show: getMissionById ok rows={d}", .{rows.len});

    if (rows.len == 0) {
        return c.text("Missão não encontrada.", .{ .status = .not_found });
    }

    std.log.info("show: calling listMissionEvents", .{});
    const mission_events = try repo.listMissionEvents(c, mission_id);
    std.log.info("show: listMissionEvents ok count={d}", .{mission_events.len});

    std.log.info("show: calling collectSupervisedExecutionEvents", .{});
    const supervised_execution_events = try model.collectSupervisedExecutionEvents(c.arena, mission_events);
    std.log.info("show: collectSupervisedExecutionEvents ok count={d}", .{supervised_execution_events.len});

    std.log.info("show: calling c.view", .{});
    return c.view("missions/show", .{
        .title = rows[0].title,
        .mission = rows[0],
        .execution_controls_enabled = std.mem.eql(u8, rows[0].execution_mode, "supervised_auto") or
            std.mem.eql(u8, rows[0].execution_mode, "autopilot"),
        .mission_events = mission_events,
        .mission_event_count = mission_events.len,
        .supervised_execution_events = supervised_execution_events,
        .supervised_execution_event_count = supervised_execution_events.len,
        .next_step_notice = if (c.query("next_step_detected") != null)
            "Próxima etapa detectada e registrada na timeline operacional."
        else
            "",
        .next_step_ready_notice = if (c.query("next_step_ready") != null)
            "Próxima etapa pronta para execução supervisionada. Confirme a ação operacional abaixo."
        else
            "",
    }, .{});
}

pub fn edit(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const rows = try repo.getMissionById(c, mission_id);

    if (rows.len == 0) {
        return c.text("Missão não encontrada.", .{ .status = .not_found });
    }

    return c.view("missions/edit", .{
        .title = "Editar Missão",
        .mission = rows[0],
        .error_message = "",
    }, .{});
}

pub fn update(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const form = try c.parseForm(model.MissionUpdateForm);

    const current_rows = try repo.getMissionById(c, mission_id);

    if (current_rows.len == 0) {
        return c.text("Missão não encontrada.", .{ .status = .not_found });
    }

    if (std.mem.eql(u8, current_rows[0].mission_operational_closure_status, "closed")) {
        return c.text(
            "Missões encerradas operacionalmente não podem ser editadas.",
            .{ .status = .bad_request },
        );
    }

    if (!std.mem.eql(u8, form.execution_mode, "manual") and
        !std.mem.eql(u8, form.execution_mode, "supervised_auto") and
        !std.mem.eql(u8, form.execution_mode, "autopilot"))
    {
        return c.text(
            "Modo de execução inválido.",
            .{ .status = .bad_request },
        );
    }

    try repo.updateMission(c, mission_id, form.title, form.objective, form.status, form.priority, form.execution_mode);

    return c.redirect("/missions?updated=1");
}

pub fn delete(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const mission_rows = try repo.getClosureRow(c, mission_id);

    if (mission_rows.len == 0) {
        return c.text("Missão não encontrada.", .{ .status = .not_found });
    }

    if (std.mem.eql(u8, mission_rows[0].mission_operational_closure_status, "closed")) {
        return c.text(
            "Missões encerradas operacionalmente não podem ser excluídas.",
            .{ .status = .bad_request },
        );
    }

    try repo.deleteMission(c, mission_id);

    return c.redirect("/missions?deleted=1");
}

pub fn runNextStep(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const rows = try repo.getNextStepMission(c, mission_id);

    if (rows.len == 0) {
        return c.text("Missão não encontrada.", .{ .status = .not_found });
    }

    const mission = rows[0];

    if (std.mem.eql(u8, mission.mission_operational_closure_status, "closed")) {
        return c.text(
            "Missões encerradas operacionalmente não podem executar próxima etapa.",
            .{ .status = .bad_request },
        );
    }

    if (!std.mem.eql(u8, mission.execution_mode, "supervised_auto") and !std.mem.eql(u8, mission.execution_mode, "autopilot")) {
        return c.text(
            "A execução supervisionada automática só está disponível para missões em modo supervised_auto ou autopilot.",
            .{ .status = .bad_request },
        );
    }

    const next_action =
        if (!std.mem.eql(u8, mission.pilot_operational_brief_status, "captured"))
        if (std.mem.eql(u8, mission.pilot_dispatch_status, "sent"))
        "Capturar briefing do Piloto"
    else
        "Enviar missão ao Piloto"
    else if (!std.mem.eql(u8, mission.planner_operational_plan_status, "captured"))
        if (std.mem.eql(u8, mission.planner_dispatch_status, "sent"))
        "Capturar plano do Planner"
    else
        "Enviar briefing ao Planner"
    else if (!std.mem.eql(u8, mission.scout_report_status, "captured"))
        if (std.mem.eql(u8, mission.scout_dispatch_status, "sent"))
        "Capturar Scout Report"
    else
        "Enviar plano ao Scout"
    else if (!std.mem.eql(u8, mission.builder_implementation_report_status, "captured"))
        if (std.mem.eql(u8, mission.builder_dispatch_status, "sent"))
        "Capturar Implementation Report"
    else
        "Enviar pacote ao Builder"
    else if (!std.mem.eql(u8, mission.reviewer_review_report_status, "captured"))
        if (std.mem.eql(u8, mission.reviewer_dispatch_status, "sent"))
        "Capturar Review Report"
    else
        "Enviar Implementation Report ao Reviewer"
    else if (!std.mem.eql(u8, mission.executor_verification_report_status, "captured"))
        if (std.mem.eql(u8, mission.executor_dispatch_status, "sent"))
        "Capturar Verification Report"
    else
        "Enviar Review Report ao Executor"
    else if (!std.mem.eql(u8, mission.pilot_delivery_report_status, "captured"))
        if (std.mem.eql(u8, mission.pilot_delivery_dispatch_status, "sent"))
        "Capturar Final Delivery Report"
    else
        "Enviar Verification Report ao Piloto"
    else
        "Encerrar missão pelo Cockpit";

    const next_action_code =
        if (!std.mem.eql(u8, mission.pilot_operational_brief_status, "captured"))
        if (std.mem.eql(u8, mission.pilot_dispatch_status, "sent"))
        "capture_pilot_brief"
    else
        "dispatch_pilot"
    else if (!std.mem.eql(u8, mission.planner_operational_plan_status, "captured"))
        if (std.mem.eql(u8, mission.planner_dispatch_status, "sent"))
        "capture_planner_plan"
    else
        "dispatch_planner"
    else if (!std.mem.eql(u8, mission.scout_report_status, "captured"))
        if (std.mem.eql(u8, mission.scout_dispatch_status, "sent"))
        "capture_scout_report"
    else
        "dispatch_scout"
    else if (!std.mem.eql(u8, mission.builder_implementation_report_status, "captured"))
        if (std.mem.eql(u8, mission.builder_dispatch_status, "sent"))
        "capture_builder_report"
    else
        "dispatch_builder"
    else if (!std.mem.eql(u8, mission.reviewer_review_report_status, "captured"))
        if (std.mem.eql(u8, mission.reviewer_dispatch_status, "sent"))
        "capture_reviewer_report"
    else
        "dispatch_reviewer"
    else if (!std.mem.eql(u8, mission.executor_verification_report_status, "captured"))
        if (std.mem.eql(u8, mission.executor_dispatch_status, "sent"))
        "capture_executor_report"
    else
        "dispatch_executor"
    else if (!std.mem.eql(u8, mission.pilot_delivery_report_status, "captured"))
        if (std.mem.eql(u8, mission.pilot_delivery_dispatch_status, "sent"))
        "capture_pilot_delivery_report"
    else
        "dispatch_pilot_delivery"
    else
        "finalize_mission";

    const next_action_route =
        if (std.mem.eql(u8, next_action_code, "dispatch_pilot"))
        try std.fmt.allocPrint(c.arena, "/workspaces/{d}/missions/{d}/dispatch/pilot", .{ mission.workspace_id, mission_id })
    else if (std.mem.eql(u8, next_action_code, "capture_pilot_brief"))
        try std.fmt.allocPrint(c.arena, "/missions/{d}/capture/pilot-brief", .{mission_id})
    else if (std.mem.eql(u8, next_action_code, "dispatch_planner"))
        try std.fmt.allocPrint(c.arena, "/workspaces/{d}/missions/{d}/dispatch/planner", .{ mission.workspace_id, mission_id })
    else if (std.mem.eql(u8, next_action_code, "capture_planner_plan"))
        try std.fmt.allocPrint(c.arena, "/missions/{d}/capture/planner-plan", .{mission_id})
    else if (std.mem.eql(u8, next_action_code, "dispatch_scout"))
        try std.fmt.allocPrint(c.arena, "/workspaces/{d}/missions/{d}/dispatch/scout", .{ mission.workspace_id, mission_id })
    else if (std.mem.eql(u8, next_action_code, "capture_scout_report"))
        try std.fmt.allocPrint(c.arena, "/missions/{d}/capture/scout-report", .{mission_id})
    else if (std.mem.eql(u8, next_action_code, "dispatch_builder"))
        try std.fmt.allocPrint(c.arena, "/workspaces/{d}/missions/{d}/dispatch/builder", .{ mission.workspace_id, mission_id })
    else if (std.mem.eql(u8, next_action_code, "capture_builder_report"))
        try std.fmt.allocPrint(c.arena, "/missions/{d}/capture/builder-report", .{mission_id})
    else if (std.mem.eql(u8, next_action_code, "dispatch_reviewer"))
        try std.fmt.allocPrint(c.arena, "/workspaces/{d}/missions/{d}/dispatch/reviewer", .{ mission.workspace_id, mission_id })
    else if (std.mem.eql(u8, next_action_code, "capture_reviewer_report"))
        try std.fmt.allocPrint(c.arena, "/missions/{d}/capture/reviewer-report", .{mission_id})
    else if (std.mem.eql(u8, next_action_code, "dispatch_executor"))
        try std.fmt.allocPrint(c.arena, "/workspaces/{d}/missions/{d}/dispatch/executor", .{ mission.workspace_id, mission_id })
    else if (std.mem.eql(u8, next_action_code, "capture_executor_report"))
        try std.fmt.allocPrint(c.arena, "/missions/{d}/capture/executor-report", .{mission_id})
    else if (std.mem.eql(u8, next_action_code, "dispatch_pilot_delivery"))
        try std.fmt.allocPrint(c.arena, "/workspaces/{d}/missions/{d}/dispatch/pilot-delivery", .{ mission.workspace_id, mission_id })
    else if (std.mem.eql(u8, next_action_code, "capture_pilot_delivery_report"))
        try std.fmt.allocPrint(c.arena, "/missions/{d}/capture/pilot-delivery-report", .{mission_id})
    else
        try std.fmt.allocPrint(c.arena, "/missions/{d}/finalize", .{mission_id});

    const event_message = if (std.mem.eql(u8, mission.execution_mode, "autopilot"))
        try std.fmt.allocPrint(
        c.arena,
        "Próxima etapa detectada para a missão \"{s}\": {s}. O executor autopilot seguirá diretamente para a ação operacional detectada.",
        .{ mission.title, next_action },
    )
    else
        try std.fmt.allocPrint(
        c.arena,
        "Próxima etapa detectada para a missão \"{s}\": {s}. O executor supervised_auto ainda está em modo diagnóstico e não executou a ação.",
        .{ mission.title, next_action },
    );

    try repo.updateMissionNextStep(c, mission_id, next_action, next_action_code, next_action_route);

    try repo.insertMissionEvent(c, mission_id, mission.workspace_id, "mission-next-step-detected", "Próxima etapa detectada", event_message);

    const redirect_url =
        if (std.mem.eql(u8, next_action_code, "dispatch_pilot"))
        try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}?next_step_ready=dispatch_pilot",
        .{mission_id},
    )
    else if (std.mem.eql(u8, next_action_code, "capture_pilot_brief"))
        try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}?next_step_ready=capture_pilot_brief",
        .{mission_id},
    )
    else if (std.mem.eql(u8, next_action_code, "dispatch_planner"))
        try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}?next_step_ready=dispatch_planner",
        .{mission_id},
    )
    else if (std.mem.eql(u8, next_action_code, "capture_planner_plan"))
        try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}?next_step_ready=capture_planner_plan",
        .{mission_id},
    )
    else if (std.mem.eql(u8, next_action_code, "dispatch_scout"))
        try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}?next_step_ready=dispatch_scout",
        .{mission_id},
    )
    else if (std.mem.eql(u8, next_action_code, "capture_scout_report"))
        try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}?next_step_ready=capture_scout_report",
        .{mission_id},
    )
    else if (std.mem.eql(u8, next_action_code, "dispatch_builder"))
        try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}?next_step_ready=dispatch_builder",
        .{mission_id},
    )
    else if (std.mem.eql(u8, next_action_code, "capture_builder_report"))
        try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}?next_step_ready=capture_builder_report",
        .{mission_id},
    )
    else if (std.mem.eql(u8, next_action_code, "dispatch_reviewer"))
        try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}?next_step_ready=dispatch_reviewer",
        .{mission_id},
    )
    else if (std.mem.eql(u8, next_action_code, "capture_reviewer_report"))
        try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}?next_step_ready=capture_reviewer_report",
        .{mission_id},
    )
    else if (std.mem.eql(u8, next_action_code, "dispatch_executor"))
        try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}?next_step_ready=dispatch_executor",
        .{mission_id},
    )
    else if (std.mem.eql(u8, next_action_code, "capture_executor_report"))
        try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}?next_step_ready=capture_executor_report",
        .{mission_id},
    )
    else if (std.mem.eql(u8, next_action_code, "dispatch_pilot_delivery"))
        try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}?next_step_ready=dispatch_pilot_delivery",
        .{mission_id},
    )
    else if (std.mem.eql(u8, next_action_code, "capture_pilot_delivery_report"))
        try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}?next_step_ready=capture_pilot_delivery_report",
        .{mission_id},
    )
    else if (std.mem.eql(u8, next_action_code, "finalize_mission"))
        try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}?next_step_ready=finalize_mission",
        .{mission_id},
    )
    else
        try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}?next_step_detected=1",
        .{mission_id},
    );

    if (std.mem.eql(u8, mission.execution_mode, "autopilot")) {
        const is_capture_or_finalize = std.mem.startsWith(u8, next_action_code, "capture_");

        if (is_capture_or_finalize) {
            const autopilot_url = try std.fmt.allocPrint(c.arena, "/missions/{d}/autopilot/step?code={s}", .{ mission_id, next_action_code });
            const headers = try c.arena.alloc([2][]const u8, 1);
            headers[0] = .{ "Location", autopilot_url };
            return c.text("", .{
                .status = .temporary_redirect,
                .headers = headers,
            });
        }

        const headers = try c.arena.alloc([2][]const u8, 1);
        headers[0] = .{ "Location", next_action_route };
        return c.text("", .{
            .status = .temporary_redirect,
            .headers = headers,
        });
    }

    return c.redirect(redirect_url);
}

pub fn finalize(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Missão não informada.", .{ .status = .bad_request });

    const mission_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Missão inválida.", .{ .status = .bad_request });

    const rows = try repo.getClosureRow(c, mission_id);

    if (rows.len == 0) {
        return c.text("Missão não encontrada.", .{ .status = .not_found });
    }

    const mission = rows[0];

    if (mission.pilot_delivery_report.len == 0 or
        !std.mem.eql(u8, mission.pilot_delivery_report_status, "captured"))
    {
        return c.text(
            "Capture o Final Delivery Report do Piloto antes de encerrar a missão.",
            .{ .status = .bad_request },
        );
    }

    if (std.mem.eql(u8, mission.mission_operational_closure_status, "closed")) {
        const redirect_url = try std.fmt.allocPrint(
            c.arena,
            "/missions/{d}",
            .{mission_id},
        );

        return c.redirect(redirect_url);
    }

    const final_verdict = helpers.extractMissionFinalVerdictFromPilotDeliveryReport(
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

    try repo.finalizeMission(c, final_verdict, formal_mission_status, mission_id);

    const event_message = try std.fmt.allocPrint(
        c.arena,
        "A missão \"{s}\" foi encerrada operacionalmente pelo Cockpit com veredito final: {s}.",
        .{ mission.title, final_verdict },
    );

    try repo.insertMissionEvent(c, mission_id, mission.workspace_id, "mission-operationally-closed", "Missão encerrada pelo Cockpit", event_message);

    try repo.releaseActiveMission(c, mission.workspace_id, mission_id);

    const release_event_message = try std.fmt.allocPrint(
        c.arena,
        "A missão \"{s}\" foi removida do foco ativo do workspace após o encerramento operacional.",
        .{mission.title},
    );

    try repo.insertMissionEvent(c, mission_id, mission.workspace_id, "mission-released-from-workspace-focus", "Missão removida do foco ativo", release_event_message);

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/missions/{d}",
        .{mission_id},
    );

    return c.redirect(redirect_url);
}
