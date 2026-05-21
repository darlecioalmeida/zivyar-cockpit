const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const core = @import("core");
const helpers = @import("../../shared/helpers.zig");
const model = @import("./workspace_model.zig");
const repo = @import("./workspace_repository.zig");

fn loadWorkspaceSquads(c: *spider.Ctx) ![]model.WorkspaceSquadOptionRow {
    return repo.listSquads(c);
}

fn loadWorkspaceSquadsForSelected(c: *spider.Ctx, selected_squad_id: i32) ![]model.WorkspaceSquadOptionRow {
    return repo.listSquadsForSelected(c, selected_squad_id);
}

fn countOpenWorkspaceMissions(rows: []const model.WorkspaceMissionPreviewRow) usize {
    var total: usize = 0;
    for (rows) |row| {
        if (!std.mem.eql(u8, row.mission_operational_closure_status, "closed")) {
            total += 1;
        }
    }
    return total;
}

fn countClosedWorkspaceMissions(rows: []const model.WorkspaceMissionPreviewRow) usize {
    var total: usize = 0;
    for (rows) |row| {
        if (std.mem.eql(u8, row.mission_operational_closure_status, "closed")) {
            total += 1;
        }
    }
    return total;
}

fn reconcileWorkspacePaneSessions(
    c: *spider.Ctx,
    workspace_id: i32,
    runtime: model.WorkspaceRuntimeRow,
) !void {
    if (!std.mem.eql(u8, runtime.state, "running")) {
        return;
    }

    const panes = try repo.listControlPanes(c, workspace_id);

    for (panes) |pane| {
        const check_result = helpers.openCodeSessionExists(
            c,
            runtime.server_url_label,
            pane.session_external_id,
        );

        if (check_result.ok) {
            continue;
        }

        try repo.markPaneStale(c, pane.id, workspace_id);

        try repo.insertRuntimeCommandLogEntry(
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

        try helpers.insertRuntimeEvent(
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
    runtime: model.WorkspaceRuntimeRow,
) !void {
    if (!runtime.is_prepared) {
        return;
    }

    const inspect_result = core.runRuntimeCommand(c, &.{
        "docker",
        "inspect",
        "--format",
        "{{.State.Running}}",
        runtime.container_name,
    });

    if (!inspect_result.ok) {
        if (!std.mem.eql(u8, runtime.state, "missing")) {
            try repo.updateRuntimeState(
                c,
                runtime.workspace_id,
                "missing",
                "O container do runtime não foi encontrado no Docker.",
            );

            try helpers.insertRuntimeEvent(
                c,
                runtime.workspace_id,
                "missing",
                "Container não encontrado",
                "O Zivyar detectou que o container registrado para este workspace não existe mais no Docker.",
            );

            try repo.insertRuntimeCommandLogEntry(
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
        try repo.updateRuntimeState(
            c,
            runtime.workspace_id,
            "running",
            "Estado reconciliado: o container está em execução no Docker.",
        );

        try helpers.insertRuntimeEvent(
            c,
            runtime.workspace_id,
            "reconciled-running",
            "Runtime reconciliado como ativo",
            "O Zivyar verificou o Docker e encontrou o container deste workspace em execução.",
        );
    } else {
        try repo.updateRuntimeState(
            c,
            runtime.workspace_id,
            "stopped",
            "Estado reconciliado: o container está parado no Docker.",
        );

        try helpers.insertRuntimeEvent(
            c,
            runtime.workspace_id,
            "reconciled-stopped",
            "Runtime reconciliado como parado",
            "O Zivyar verificou o Docker e encontrou o container deste workspace interrompido.",
        );
    }

    try repo.insertRuntimeCommandLogEntry(
        c,
        runtime.workspace_id,
        "inspect-container-state",
        "docker inspect --format {{.State.Running}} <workspace-container>",
        inspect_result,
    );
}

pub fn workspaces(c: *spider.Ctx) !spider.Response {
    const initial_rows = try repo.listWorkspaces(c);

    for (initial_rows) |workspace| {
        if (!workspace.runtime_is_prepared) {
            continue;
        }

        const runtime_rows = try repo.getRuntimeRow(c, workspace.id);

        if (runtime_rows.len == 0) {
            continue;
        }

        try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);
    }

    const rows = try repo.listWorkspaces(c);

    const runtime_count_rows = try repo.getRuntimeCountRunning(c);

    const mission_count_rows = try repo.getMissionCountOpen(c);

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

pub fn workspaceNew(c: *spider.Ctx) !spider.Response {
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

pub fn workspaceCreate(c: *spider.Ctx) !spider.Response {
    const form = try c.parseForm(model.WorkspaceForm);
    const squads_rows = try loadWorkspaceSquads(c);
    const default_squad_id = std.fmt.parseInt(i32, form.default_squad_id, 10) catch 0;

    const duplicated = try repo.checkDuplicatedLocalPath(c, form.local_path, null);

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

    const squad_rows = try repo.getSquadById(c, default_squad_id);

    if (squad_rows.len == 0) {
        return c.view("workspaces/new", .{
            .title = "Novo Workspace",
            .squads = squads_rows,
            .squad_count = squads_rows.len,
            .error_message = "A squad selecionada não está disponível.",
            .form = form,
        }, .{ .status = .bad_request });
    }

    if (!helpers.ensureWorkspaceLocalPath(c, form.local_path)) {
        return c.view("workspaces/new", .{
            .title = "Novo Workspace",
            .squads = squads_rows,
            .squad_count = squads_rows.len,
            .error_message = "Não foi possível criar ou acessar o caminho local informado para o workspace.",
            .form = form,
        }, .{ .status = .bad_request });
    }

    try repo.createWorkspace(c, form, squad_rows[0].name, default_squad_id);

    return c.redirect("/workspaces?created=1");
}

pub fn workspaceEdit(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const rows = try repo.getWorkspace(c, workspace_id);

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

pub fn workspaceUpdate(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const form = try c.parseForm(model.WorkspaceForm);
    const squads_rows = try loadWorkspaceSquads(c);
    const default_squad_id = std.fmt.parseInt(i32, form.default_squad_id, 10) catch 0;

    const current_rows = try repo.getWorkspace(c, workspace_id);

    if (current_rows.len == 0) {
        return c.text("Workspace não encontrado.", .{ .status = .not_found });
    }

    const duplicated = try repo.checkDuplicatedLocalPath(c, form.local_path, workspace_id);

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

    const selected_squad_rows = try repo.getSquadById(c, default_squad_id);

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

    if (!helpers.ensureWorkspaceLocalPath(c, form.local_path)) {
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

    try repo.updateWorkspace(c, form, workspace_id, selected_squad_rows[0].name, default_squad_id);

    return c.redirect("/workspaces?updated=1");
}

pub fn workspaceConfirmLocalPathChange(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const form = try c.parseForm(model.WorkspaceLocalPathConfirmForm);
    const squads_rows = try loadWorkspaceSquads(c);
    const default_squad_id = std.fmt.parseInt(i32, form.default_squad_id, 10) catch 0;

    if (!std.mem.eql(u8, form.confirm_local_path_change, "yes")) {
        return c.text(
            "Confirmação explícita obrigatória para alterar o caminho local do workspace.",
            .{ .status = .bad_request },
        );
    }

    const current_rows = try repo.getWorkspace(c, workspace_id);

    if (current_rows.len == 0) {
        return c.text("Workspace não encontrado.", .{ .status = .not_found });
    }

    const current_workspace = current_rows[0];

    const duplicated = try repo.checkDuplicatedLocalPath(c, form.local_path, workspace_id);

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

    const selected_squad_rows = try repo.getSquadById(c, default_squad_id);

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

    if (!helpers.ensureWorkspaceLocalPath(c, form.local_path)) {
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

    const runtime_rows = try repo.getRuntimeControlRow(c, workspace_id);

    if (runtime_rows.len > 0) {
        const runtime = runtime_rows[0];

        const container_exists = core.commandSucceeded(c, &.{
            "docker",
            "container",
            "inspect",
            runtime.container_name,
        });

        if (container_exists) {
            const remove_result = core.runRuntimeCommand(c, &.{
                "docker",
                "rm",
                "-f",
                runtime.container_name,
            });

            try repo.insertRuntimeCommandLogEntry(
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

    try repo.updateWorkspaceWithLocalPathConfirm(c, form, workspace_id, selected_squad_rows[0].name, default_squad_id);

    if (runtime_rows.len > 0) {
        try repo.resetRuntimeOnPathChange(c, workspace_id);

        try repo.markPanesStaleOnPathChange(c, workspace_id);
    }

    const path_change_message = try std.fmt.allocPrint(
        c.arena,
        "O caminho local do workspace foi alterado de {s} para {s}. O runtime anterior foi invalidado para evitar montagem incorreta.",
        .{ current_workspace.local_path, form.local_path },
    );

    try helpers.insertRuntimeEvent(
        c,
        workspace_id,
        "workspace-local-path-changed",
        "Caminho local alterado",
        path_change_message,
    );

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/workspaces/{d}",
        .{workspace_id},
    );

    return c.redirect(redirect_url);
}

pub fn workspaceDelete(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    try repo.deleteWorkspace(c, workspace_id);

    return c.redirect("/workspaces?deleted=1");
}

pub fn workspaceShow(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    std.log.info("workspaceShow start id={d}", .{workspace_id});

    const rows = try repo.getWorkspace(c, workspace_id);

    if (rows.len == 0) {
        return c.text("Workspace não encontrado.", .{ .status = .not_found });
    }

    const workspace = rows[0];
    std.log.info("workspaceShow loaded workspace id={d}", .{workspace.id});
    const linked_squad_id = workspace.default_squad_id orelse 0;
    const runtime_rows = try repo.getRuntimeRow(c, workspace.id);

    std.log.info("workspaceShow runtime rows={d}", .{runtime_rows.len});

    if (runtime_rows.len > 0) {
        reconcileWorkspaceRuntimeState(c, runtime_rows[0]) catch {};
    }

    const refreshed_runtime_rows = try repo.getRuntimeRow(c, workspace.id);

    std.log.info("workspaceShow refreshed runtime rows={d}", .{refreshed_runtime_rows.len});

    if (refreshed_runtime_rows.len > 0) {
        reconcileWorkspacePaneSessions(c, workspace.id, refreshed_runtime_rows[0]) catch {};
    }

    const runtime_events = try repo.listRuntimeEvents(c, workspace.id);

    std.log.info("workspaceShow runtime events={d}", .{runtime_events.len});

    const runtime_logs = try repo.listRuntimeLogs(c, workspace.id);

    std.log.info("workspaceShow runtime logs={d}", .{runtime_logs.len});

    const pane_session_history = try repo.listPaneSessionHistory(c, workspace.id);

    std.log.info("workspaceShow pane session history={d}", .{pane_session_history.len});

    const workspace_memory_entries = try repo.listWorkspaceMemoryEntries(c, workspace.id);

    const workspace_handoffs = try repo.listWorkspaceHandoffs(c, workspace.id);

    const workspace_decision_records = try repo.listWorkspaceDecisionRecords(c, workspace.id);

    const workspace_snapshots = try repo.listWorkspaceSnapshots(c, workspace.id);

    const workspace_missions = try repo.listWorkspaceMissions(c, workspace.id);

    const active_missions = try repo.getActiveMissionPanel(c, workspace.id);

    const members = try repo.listSquadMembers(c, linked_squad_id);

    if (linked_squad_id <= 0) {
        try repo.deleteAllPanes(c, workspace.id);
    } else {
        try repo.deleteOrphanPanes(c, workspace.id, linked_squad_id);

        for (members) |member| {
            try repo.upsertPane(
                c,
                workspace.id,
                member.role_name,
                member.id,
                member.agent_id,
                member.display_order,
            );
        }
    }

    const panes = try repo.listPanesForWorkspace(c, workspace.id);

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
        .runtime = if (refreshed_runtime_rows.len > 0) refreshed_runtime_rows[0] else runtime_rows[0],
        .runtime_events = runtime_events,
        .runtime_event_count = runtime_events.len,
        .runtime_logs = runtime_logs,
        .runtime_log_count = runtime_logs.len,
        .pane_session_history = pane_session_history,
        .pane_session_history_count = pane_session_history.len,
        .workspace_memory_entries = workspace_memory_entries,
        .workspace_memory_count = workspace_memory_entries.len,
        .workspace_handoffs = workspace_handoffs,
        .workspace_handoff_count = workspace_handoffs.len,
        .workspace_decision_records = workspace_decision_records,
        .workspace_decision_record_count = workspace_decision_records.len,
        .workspace_snapshots = workspace_snapshots,
        .workspace_snapshot_count = workspace_snapshots.len,
        .notice = if (c.query("mission_created") != null)
            "Missão criada com sucesso e vinculada a este workspace."
        else
            "",
        .memory_notice = if (c.query("memory_created") != null)
            "Memória de workspace registrada com sucesso."
        else if (c.query("memory_error") != null)
            "Informe título e conteúdo para registrar a memória de workspace."
        else
            "",
        .memory_update_notice = if (c.query("memory_updated") != null)
            "Memória de workspace atualizada com sucesso."
        else if (c.query("memory_deleted") != null)
            "Memória de workspace removida com sucesso."
        else
            "",
        .handoff_notice = if (c.query("handoff_created") != null)
            "Handoff registrado com sucesso."
        else if (c.query("handoff_error") != null)
            "Preencha origem, destino e resumo para registrar o handoff."
        else
            "",
        .handoff_update_notice = if (c.query("handoff_updated") != null)
            "Handoff atualizado com sucesso."
        else if (c.query("handoff_deleted") != null)
            "Handoff removido com sucesso."
        else
            "",
        .decision_notice = if (c.query("decision_created") != null)
            "Decision record registrada com sucesso."
        else if (c.query("decision_error") != null)
            "Preencha título, decisão e racional para registrar a decisão."
        else
            "",
        .decision_update_notice = if (c.query("decision_updated") != null)
            "Decision record atualizada com sucesso."
        else if (c.query("decision_deleted") != null)
            "Decision record removida com sucesso."
        else
            "",
        .snapshot_notice = if (c.query("snapshot_created") != null)
            "Snapshot de contexto registrado com sucesso."
        else if (c.query("snapshot_error") != null)
            "Preencha título, escopo e conteúdo para registrar o snapshot."
        else
            "",
        .snapshot_update_notice = if (c.query("snapshot_updated") != null)
            "Snapshot de contexto atualizado com sucesso."
        else if (c.query("snapshot_deleted") != null)
            "Snapshot de contexto removido com sucesso."
        else
            "",
        .next_step_ready_notice = if (c.query("next_step_ready") != null)
            "Próxima etapa pronta para execução supervisionada. Confirme a ação operacional abaixo."
        else
            "",
    }, .{});
}

pub fn workspaceMemoryCreate(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const form = try c.parseForm(model.WorkspaceMemoryForm);

    if (form.title.len == 0 or form.content.len == 0) {
        return c.redirect(try std.fmt.allocPrint(c.arena, "/workspaces/{d}?memory_error=1", .{workspace_id}));
    }

    const workspace_rows = try repo.getWorkspaceIdOnly(c, workspace_id);

    if (workspace_rows.len == 0) {
        return c.text("Workspace não encontrado.", .{ .status = .not_found });
    }

    try repo.insertMemoryEntry(c, workspace_id, form);

    return c.redirect(try std.fmt.allocPrint(c.arena, "/workspaces/{d}?memory_created=1", .{workspace_id}));
}

pub fn workspaceMemoryUpdate(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const entry_id_raw = c.params.get("entry_id") orelse
        return c.text("Memória não informada.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const entry_id = std.fmt.parseInt(i32, entry_id_raw, 10) catch
        return c.text("Memória inválida.", .{ .status = .bad_request });

    const form = try c.parseForm(model.WorkspaceMemoryForm);

    if (form.title.len == 0 or form.content.len == 0) {
        return c.redirect(try std.fmt.allocPrint(c.arena, "/workspaces/{d}?memory_error=1", .{workspace_id}));
    }

    const entry_rows = try repo.getMemoryEntry(c, entry_id, workspace_id);

    if (entry_rows.len == 0) {
        return c.text("Memória não encontrada.", .{ .status = .not_found });
    }

    try repo.updateMemoryEntry(c, entry_id, workspace_id, form);

    return c.redirect(try std.fmt.allocPrint(c.arena, "/workspaces/{d}?memory_updated=1", .{workspace_id}));
}

pub fn workspaceMemoryDelete(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const entry_id_raw = c.params.get("entry_id") orelse
        return c.text("Memória não informada.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const entry_id = std.fmt.parseInt(i32, entry_id_raw, 10) catch
        return c.text("Memória inválida.", .{ .status = .bad_request });

    try repo.deleteMemoryEntry(c, entry_id, workspace_id);

    return c.redirect(try std.fmt.allocPrint(c.arena, "/workspaces/{d}?memory_deleted=1", .{workspace_id}));
}

pub fn workspaceHandoffCreate(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const form = try c.parseForm(model.WorkspaceHandoffForm);

    if (form.from_role.len == 0 or form.to_role.len == 0 or form.summary.len == 0) {
        return c.redirect(try std.fmt.allocPrint(c.arena, "/workspaces/{d}?handoff_error=1", .{workspace_id}));
    }

    const workspace_rows = try repo.getWorkspaceIdOnly(c, workspace_id);

    if (workspace_rows.len == 0) {
        return c.text("Workspace não encontrado.", .{ .status = .not_found });
    }

    try repo.insertHandoff(c, workspace_id, form);

    return c.redirect(try std.fmt.allocPrint(c.arena, "/workspaces/{d}?handoff_created=1", .{workspace_id}));
}

pub fn workspaceHandoffUpdate(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const entry_id_raw = c.params.get("entry_id") orelse
        return c.text("Handoff não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const entry_id = std.fmt.parseInt(i32, entry_id_raw, 10) catch
        return c.text("Handoff inválido.", .{ .status = .bad_request });

    const form = try c.parseForm(model.WorkspaceHandoffForm);

    if (form.from_role.len == 0 or form.to_role.len == 0 or form.summary.len == 0) {
        return c.redirect(try std.fmt.allocPrint(c.arena, "/workspaces/{d}?handoff_error=1", .{workspace_id}));
    }

    const entry_rows = try repo.getHandoff(c, entry_id, workspace_id);

    if (entry_rows.len == 0) {
        return c.text("Handoff não encontrado.", .{ .status = .not_found });
    }

    try repo.updateHandoff(c, entry_id, workspace_id, form);

    return c.redirect(try std.fmt.allocPrint(c.arena, "/workspaces/{d}?handoff_updated=1", .{workspace_id}));
}

pub fn workspaceHandoffDelete(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const entry_id_raw = c.params.get("entry_id") orelse
        return c.text("Handoff não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const entry_id = std.fmt.parseInt(i32, entry_id_raw, 10) catch
        return c.text("Handoff inválido.", .{ .status = .bad_request });

    try repo.deleteHandoff(c, entry_id, workspace_id);

    return c.redirect(try std.fmt.allocPrint(c.arena, "/workspaces/{d}?handoff_deleted=1", .{workspace_id}));
}

pub fn workspaceDecisionRecordCreate(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const form = try c.parseForm(model.WorkspaceDecisionRecordForm);

    if (form.title.len == 0 or form.decision.len == 0 or form.rationale.len == 0) {
        return c.redirect(try std.fmt.allocPrint(c.arena, "/workspaces/{d}?decision_error=1", .{workspace_id}));
    }

    const workspace_rows = try repo.getWorkspaceIdOnly(c, workspace_id);

    if (workspace_rows.len == 0) {
        return c.text("Workspace não encontrado.", .{ .status = .not_found });
    }

    try repo.insertDecisionRecord(c, workspace_id, form);

    return c.redirect(try std.fmt.allocPrint(c.arena, "/workspaces/{d}?decision_created=1", .{workspace_id}));
}

pub fn workspaceDecisionRecordUpdate(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const entry_id_raw = c.params.get("entry_id") orelse
        return c.text("Decision record não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const entry_id = std.fmt.parseInt(i32, entry_id_raw, 10) catch
        return c.text("Decision record inválido.", .{ .status = .bad_request });

    const form = try c.parseForm(model.WorkspaceDecisionRecordForm);

    if (form.title.len == 0 or form.decision.len == 0 or form.rationale.len == 0) {
        return c.redirect(try std.fmt.allocPrint(c.arena, "/workspaces/{d}?decision_error=1", .{workspace_id}));
    }

    const entry_rows = try repo.getDecisionRecord(c, entry_id, workspace_id);

    if (entry_rows.len == 0) {
        return c.text("Decision record não encontrado.", .{ .status = .not_found });
    }

    try repo.updateDecisionRecord(c, entry_id, workspace_id, form);

    return c.redirect(try std.fmt.allocPrint(c.arena, "/workspaces/{d}?decision_updated=1", .{workspace_id}));
}

pub fn workspaceDecisionRecordDelete(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const entry_id_raw = c.params.get("entry_id") orelse
        return c.text("Decision record não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const entry_id = std.fmt.parseInt(i32, entry_id_raw, 10) catch
        return c.text("Decision record inválido.", .{ .status = .bad_request });

    try repo.deleteDecisionRecord(c, entry_id, workspace_id);

    return c.redirect(try std.fmt.allocPrint(c.arena, "/workspaces/{d}?decision_deleted=1", .{workspace_id}));
}

pub fn workspaceSnapshotCreate(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const form = try c.parseForm(model.WorkspaceSnapshotForm);

    if (form.title.len == 0 or form.scope.len == 0 or form.content.len == 0) {
        return c.redirect(try std.fmt.allocPrint(c.arena, "/workspaces/{d}?snapshot_error=1", .{workspace_id}));
    }

    const workspace_rows = try repo.getWorkspaceIdOnly(c, workspace_id);

    if (workspace_rows.len == 0) {
        return c.text("Workspace não encontrado.", .{ .status = .not_found });
    }

    try repo.insertSnapshot(c, workspace_id, form);

    return c.redirect(try std.fmt.allocPrint(c.arena, "/workspaces/{d}?snapshot_created=1", .{workspace_id}));
}

pub fn workspaceSnapshotUpdate(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const entry_id_raw = c.params.get("entry_id") orelse
        return c.text("Snapshot não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const entry_id = std.fmt.parseInt(i32, entry_id_raw, 10) catch
        return c.text("Snapshot inválido.", .{ .status = .bad_request });

    const form = try c.parseForm(model.WorkspaceSnapshotForm);

    if (form.title.len == 0 or form.scope.len == 0 or form.content.len == 0) {
        return c.redirect(try std.fmt.allocPrint(c.arena, "/workspaces/{d}?snapshot_error=1", .{workspace_id}));
    }

    const entry_rows = try repo.getSnapshot(c, entry_id, workspace_id);

    if (entry_rows.len == 0) {
        return c.text("Snapshot não encontrado.", .{ .status = .not_found });
    }

    try repo.updateSnapshot(c, entry_id, workspace_id, form);

    return c.redirect(try std.fmt.allocPrint(c.arena, "/workspaces/{d}?snapshot_updated=1", .{workspace_id}));
}

pub fn workspaceSnapshotDelete(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const entry_id_raw = c.params.get("entry_id") orelse
        return c.text("Snapshot não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const entry_id = std.fmt.parseInt(i32, entry_id_raw, 10) catch
        return c.text("Snapshot inválido.", .{ .status = .bad_request });

    try repo.deleteSnapshot(c, entry_id, workspace_id);

    return c.redirect(try std.fmt.allocPrint(c.arena, "/workspaces/{d}?snapshot_deleted=1", .{workspace_id}));
}

pub fn workspaceRuntimePrepare(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const workspace_rows = try repo.getWorkspaceIdOnly(c, workspace_id);

    if (workspace_rows.len == 0) {
        return c.text("Workspace não encontrado.", .{ .status = .not_found });
    }

    const container_name = try std.fmt.allocPrint(
        c.arena,
        "zivyar_workspace_{d}",
        .{workspace_id},
    );

    try repo.upsertRuntimeRow(c, workspace_id, container_name);

    try helpers.insertRuntimeEvent(
        c,
        workspace_id,
        "prepared",
        "Runtime preparado",
        "O workspace foi registrado no Runtime Manager e está pronto para iniciar o OpenCode Server.",
    );

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/workspaces/{d}",
        .{workspace_id},
    );

    return c.redirect(redirect_url);
}

pub fn workspaceRuntimeStart(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const runtime_rows = try repo.getRuntimeControlRow(c, workspace_id);

    if (runtime_rows.len == 0) {
        return c.text("Prepare o runtime antes de iniciar.", .{ .status = .bad_request });
    }

    const runtime = runtime_rows[0];

    if (!helpers.ensureWorkspaceLocalPath(c, runtime.local_path)) {
        try repo.updateRuntimeState(
            c,
            workspace_id,
            "error",
            "Falha ao criar ou acessar o diretório local do workspace.",
        );

        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "error",
            "Diretório do workspace indisponível",
            "O Zivyar não conseguiu criar ou acessar o caminho local configurado para este workspace.",
        );

        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{workspace_id});
        return c.redirect(redirect_url);
    }

    const image_name = spider.env.getOr("ZIVYAR_RUNTIME_IMAGE", "zivyar-opencode-runtime:latest");
    const runtime_context = spider.env.getOr("ZIVYAR_RUNTIME_CONTEXT", "../../infra/docker/opencode-runtime");
    const internal_port = spider.env.getInt(i32, "ZIVYAR_RUNTIME_INTERNAL_PORT", 4096);
    const host_port = core.runtimeHostPort(workspace_id);

    const host_port_text = try std.fmt.allocPrint(c.arena, "{d}", .{host_port});
    const internal_port_text = try std.fmt.allocPrint(c.arena, "{d}", .{internal_port});
    const published_port = try std.fmt.allocPrint(
        c.arena,
        "127.0.0.1:{d}:{d}",
        .{ host_port, internal_port },
    );
    const volume_mount = try std.fmt.allocPrint(
        c.arena,
        "{s}:/workspace",
        .{runtime.local_path},
    );
    const server_url = try std.fmt.allocPrint(
        c.arena,
        "http://127.0.0.1:{d}",
        .{host_port},
    );

    try repo.updateRuntimeState(
        c,
        workspace_id,
        "starting",
        "Preparando imagem e iniciando OpenCode Server...",
    );

    try helpers.insertRuntimeEvent(
        c,
        workspace_id,
        "starting",
        "Inicialização solicitada",
        "O Zivyar iniciou o fluxo de validação da imagem Docker e abertura do OpenCode Server.",
    );

    const image_exists = core.commandSucceeded(c, &.{
        "docker",
        "image",
        "inspect",
        image_name,
    });

    if (!image_exists) {
        const build_result = core.runRuntimeCommand(c, &.{
            "docker",
            "build",
            "-t",
            image_name,
            runtime_context,
        });

        try repo.insertRuntimeCommandLogEntry(
            c,
            workspace_id,
            "build-image",
            "docker build -t zivyar-opencode-runtime:latest <runtime-context>",
            build_result,
        );

        if (!build_result.ok) {
            try repo.updateRuntimeState(
                c,
                workspace_id,
                "error",
                "Falha ao construir a imagem do runtime Zivyar.",
            );

            try helpers.insertRuntimeEvent(
                c,
                workspace_id,
                "error",
                "Falha ao construir imagem",
                "O Docker não conseguiu construir a imagem zivyar-opencode-runtime:latest.",
            );

            const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{workspace_id});
            return c.redirect(redirect_url);
        }
    }

    const container_exists = core.commandSucceeded(c, &.{
        "docker",
        "container",
        "inspect",
        runtime.container_name,
    });

    var container_result = core.RuntimeCommandResult{
        .ok = false,
        .exit_code = -1,
        .stdout = "",
        .stderr = "",
    };

    if (container_exists) {
        container_result = core.runRuntimeCommand(c, &.{
            "docker",
            "start",
            runtime.container_name,
        });

        try repo.insertRuntimeCommandLogEntry(
            c,
            workspace_id,
            "start-container",
            "docker start <workspace-container>",
            container_result,
        );
    } else {
        container_result = core.runRuntimeCommand(c, &.{
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

        try repo.insertRuntimeCommandLogEntry(
            c,
            workspace_id,
            "create-container",
            "docker run -d --name <workspace-container> -p <host>:<container> -v <workspace>:/workspace",
            container_result,
        );
    }

    if (!container_result.ok) {
        try repo.updateRuntimeState(
            c,
            workspace_id,
            "error",
            "Falha ao criar ou iniciar o container do runtime.",
        );

        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "error",
            "Falha ao iniciar container",
            "O Docker não conseguiu criar ou iniciar o container associado a este workspace.",
        );

        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{workspace_id});
        return c.redirect(redirect_url);
    }

    const healthy = core.waitForOpenCodeHealth(c, server_url);

    if (!healthy) {
        try repo.insertRuntimeCommandLogEntry(
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

        try repo.updateRuntimeStateWithPort(
            c,
            workspace_id,
            "error",
            host_port,
            server_url,
            "Container iniciou, mas o healthcheck do OpenCode não respondeu.",
        );

        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "error",
            "Healthcheck indisponível",
            "O container iniciou, porém o endpoint de saúde do OpenCode não respondeu dentro da janela esperada.",
        );

        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{workspace_id});
        return c.redirect(redirect_url);
    }

    try repo.updateRuntimeStateWithPort(
        c,
        workspace_id,
        "running",
        host_port,
        server_url,
        "OpenCode Server em execução e validado com sucesso.",
    );

    try helpers.insertRuntimeEvent(
        c,
        workspace_id,
        "running",
        "Runtime em execução",
        "O container foi iniciado e o OpenCode Server respondeu ao healthcheck com sucesso.",
    );

    _ = host_port_text;
    _ = internal_port_text;

    const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{workspace_id});

    return c.redirect(redirect_url);
}

pub fn workspaceRuntimeStop(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const runtime_rows = try repo.getRuntimeControlRow(c, workspace_id);

    if (runtime_rows.len == 0) {
        return c.text("Runtime não encontrado.", .{ .status = .not_found });
    }

    const runtime = runtime_rows[0];

    const stop_result = core.runRuntimeCommand(c, &.{
        "docker",
        "stop",
        runtime.container_name,
    });

    try repo.insertRuntimeCommandLogEntry(
        c,
        workspace_id,
        "stop-container",
        "docker stop <workspace-container>",
        stop_result,
    );

    if (!stop_result.ok) {
        try repo.updateRuntimeState(
            c,
            workspace_id,
            "error",
            "Falha ao parar o container do runtime.",
        );

        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "error",
            "Falha ao parar runtime",
            "O Docker não confirmou a parada do container deste workspace.",
        );
    } else {
        try repo.updateRuntimeState(
            c,
            workspace_id,
            "stopped",
            "Runtime parado pelo usuário.",
        );

        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "stopped",
            "Runtime parado",
            "O usuário interrompeu o OpenCode Server deste workspace.",
        );
    }

    const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{workspace_id});
    return c.redirect(redirect_url);
}

pub fn workspaceRuntimeLiveStatus(c: *spider.Ctx) !spider.Response {
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

    const runtime_rows = try repo.getRuntimeRow(c, workspace_id);

    if (runtime_rows.len == 0) {
        return c.json(.{
            .ok = false,
            .message = "Runtime não encontrado.",
        }, .{ .status = .not_found });
    }

    try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_rows = try repo.getRuntimeRow(c, workspace_id);

    if (refreshed_rows.len == 0) {
        return c.json(.{
            .ok = false,
            .message = "Runtime não encontrado após reconciliação.",
        }, .{ .status = .not_found });
    }

    const runtime = refreshed_rows[0];

    try reconcileWorkspacePaneSessions(c, workspace_id, runtime);

    const runtime_events = try repo.listRuntimeEvents(c, workspace_id);

    const runtime_logs = try repo.listRuntimeLogs(c, workspace_id);

    const workspace_panes = try repo.listPanesForWorkspace(c, workspace_id);

    const pane_session_history = try repo.listPaneSessionHistory(c, workspace_id);

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

pub fn workspacePaneCloseSession(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const pane_id_raw = c.params.get("pane_id") orelse
        return c.text("Pane não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const pane_id = std.fmt.parseInt(i32, pane_id_raw, 10) catch
        return c.text("Pane inválido.", .{ .status = .bad_request });

    const pane_rows = try repo.getPaneControlRow(c, pane_id, workspace_id);

    if (pane_rows.len == 0) {
        return c.text("Pane não encontrado.", .{ .status = .not_found });
    }

    const pane = pane_rows[0];

    if (!std.mem.eql(u8, pane.pane_state, "active")) {
        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{workspace_id});
        return c.redirect(redirect_url);
    }

    try repo.updatePaneState(c, pane_id, workspace_id, "closed");

    const close_message = try std.fmt.allocPrint(
        c.arena,
        "O pane {s} foi encerrado no Cockpit. A sessão {s} permanece vinculada e pode ser retomada.",
        .{ pane.role_name, pane.session_external_id },
    );

    try helpers.insertRuntimeEvent(
        c,
        workspace_id,
        "pane-session-closed",
        "Pane encerrado",
        close_message,
    );

    const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{workspace_id});
    return c.redirect(redirect_url);
}

pub fn workspacePaneResumeSession(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const pane_id_raw = c.params.get("pane_id") orelse
        return c.text("Pane não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const pane_id = std.fmt.parseInt(i32, pane_id_raw, 10) catch
        return c.text("Pane inválido.", .{ .status = .bad_request });

    const pane_rows = try repo.getPaneControlRow(c, pane_id, workspace_id);

    if (pane_rows.len == 0) {
        return c.text("Pane não encontrado.", .{ .status = .not_found });
    }

    const pane = pane_rows[0];

    if (!std.mem.eql(u8, pane.pane_state, "closed") or pane.session_external_id.len == 0) {
        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{workspace_id});
        return c.redirect(redirect_url);
    }

    const runtime_rows = try repo.getRuntimeRow(c, workspace_id);

    if (runtime_rows.len == 0) {
        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{workspace_id});
        return c.redirect(redirect_url);
    }

    try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try repo.getRuntimeRow(c, workspace_id);

    if (refreshed_runtime_rows.len == 0) {
        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{workspace_id});
        return c.redirect(redirect_url);
    }

    const runtime = refreshed_runtime_rows[0];

    if (!std.mem.eql(u8, runtime.state, "running")) {
        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{workspace_id});
        return c.redirect(redirect_url);
    }

    const validate_result = helpers.openCodeSessionExists(
        c,
        runtime.server_url_label,
        pane.session_external_id,
    );

    try repo.insertRuntimeCommandLogEntry(
        c,
        workspace_id,
        "opencode-resume-session",
        "GET <opencode-server>/session/<session-id>",
        validate_result,
    );

    if (!validate_result.ok) {
        try repo.markPaneStale(c, pane_id, workspace_id);

        const stale_message = try std.fmt.allocPrint(
            c.arena,
            "A sessão {s} do pane {s} não existe mais no OpenCode Server.",
            .{ pane.session_external_id, pane.role_name },
        );

        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "pane-session-stale",
            "Sessão não pode ser retomada",
            stale_message,
        );

        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{workspace_id});
        return c.redirect(redirect_url);
    }

    try repo.updatePaneState(c, pane_id, workspace_id, "active");

    const resume_message = try std.fmt.allocPrint(
        c.arena,
        "O pane {s} retomou a sessão {s}.",
        .{ pane.role_name, pane.session_external_id },
    );

    try helpers.insertRuntimeEvent(
        c,
        workspace_id,
        "pane-session-resumed",
        "Sessão retomada",
        resume_message,
    );

    const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{workspace_id});
    return c.redirect(redirect_url);
}

pub fn workspacePaneRecreateSession(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const pane_id_raw = c.params.get("pane_id") orelse
        return c.text("Pane não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const pane_id = std.fmt.parseInt(i32, pane_id_raw, 10) catch
        return c.text("Pane inválido.", .{ .status = .bad_request });

    const pane_rows = try repo.getPaneControlRowSparse(c, pane_id, workspace_id);

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

    try repo.markContextOutdated(c, pane_id, workspace_id);

    return workspacePaneOpenSession(c);
}

pub fn workspacePaneOpenSession(c: *spider.Ctx) !spider.Response {
    const workspace_id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const pane_id_raw = c.params.get("pane_id") orelse
        return c.text("Pane não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, workspace_id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const pane_id = std.fmt.parseInt(i32, pane_id_raw, 10) catch
        return c.text("Pane inválido.", .{ .status = .bad_request });

    const pane_rows = try repo.getPaneControlRowFull(c, pane_id, workspace_id);

    if (pane_rows.len == 0) {
        return c.text("Pane não encontrado.", .{ .status = .not_found });
    }

    const pane = pane_rows[0];
    const is_recreating_stale_session = std.mem.eql(u8, pane.pane_state, "stale");
    const is_recreating_outdated_context = std.mem.eql(u8, pane.context_state, "outdated");

    if (pane.session_external_id.len > 0 and
        !is_recreating_stale_session and
        !is_recreating_outdated_context)
    {
        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{workspace_id});
        return c.redirect(redirect_url);
    }

    const runtime_rows = try repo.getRuntimeRow(c, workspace_id);

    if (runtime_rows.len == 0) {
        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "pane-session-error",
            "Sessão não criada",
            "O runtime deste workspace ainda não foi preparado.",
        );

        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{workspace_id});
        return c.redirect(redirect_url);
    }

    try reconcileWorkspaceRuntimeState(c, runtime_rows[0]);

    const refreshed_runtime_rows = try repo.getRuntimeRow(c, workspace_id);

    if (refreshed_runtime_rows.len == 0) {
        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{workspace_id});
        return c.redirect(redirect_url);
    }

    const runtime = refreshed_runtime_rows[0];

    if (!std.mem.eql(u8, runtime.state, "running")) {
        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "pane-session-error",
            "Sessão não criada",
            "O Runtime precisa estar em execução para abrir uma sessão de pane.",
        );

        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{workspace_id});
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
        .{runtime.server_url_label},
    );

    const create_session_result = core.runRuntimeCommand(c, &.{
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

    try repo.insertRuntimeCommandLogEntry(
        c,
        workspace_id,
        "opencode-create-session",
        "POST <opencode-server>/session",
        create_session_result,
    );

    if (!create_session_result.ok) {
        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "pane-session-error",
            "Falha ao criar sessão",
            "A chamada ao OpenCode Server não concluiu com sucesso.",
        );

        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{workspace_id});
        return c.redirect(redirect_url);
    }

    const session_id = helpers.extractOpenCodeSessionId(create_session_result.stdout) orelse {
        try helpers.insertRuntimeEvent(
            c,
            workspace_id,
            "pane-session-error",
            "Resposta inválida do OpenCode",
            "O OpenCode respondeu, mas o Zivyar não encontrou o identificador da sessão.",
        );

        const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{workspace_id});
        return c.redirect(redirect_url);
    };

    const bootstrap_rows = try repo.getPaneBootstrapData(c, pane_id, workspace_id);

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

        const OpenCodeTextPart = struct {
            type: []const u8,
            text: []const u8,
        };

        const OpenCodeBootstrapMessageRequest = struct {
            noReply: bool,
            parts: []const OpenCodeTextPart,
        };

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

        const bootstrap_result = core.runRuntimeCommand(c, &.{
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

        try repo.insertRuntimeCommandLogEntry(
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

            try helpers.insertRuntimeEvent(
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

            try helpers.insertRuntimeEvent(
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

    if (pane.session_external_id.len > 0 and
        (is_recreating_stale_session or is_recreating_outdated_context))
    {
        const replacement_reason =
            if (is_recreating_stale_session)
                "stale_recovery"
            else
                "context_outdated";

        try repo.insertPaneSessionHistory(
            c,
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
        );
    }

    try repo.updatePaneSession(c, pane_id, workspace_id, session_id, pane.agent_id, session_agent_handle);

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

    try helpers.insertRuntimeEvent(
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

    const redirect_url = try std.fmt.allocPrint(c.arena, "/workspaces/{d}", .{workspace_id});
    return c.redirect(redirect_url);
}

pub fn workspaceMissionActivate(c: *spider.Ctx) !spider.Response {
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

    try repo.setActiveMission(c, workspace_id, mission_id);

    try repo.insertMissionEvent(c, mission_id, workspace_id);

    const redirect_url = try std.fmt.allocPrint(
        c.arena,
        "/workspaces/{d}",
        .{workspace_id},
    );

    return c.redirect(redirect_url);
}
