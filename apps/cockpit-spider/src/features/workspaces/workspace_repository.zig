const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const model = @import("./workspace_model.zig");

pub fn listWorkspaces(c: *spider.Ctx) ![]model.WorkspaceIndexRow {
    return db.query(
        model.WorkspaceIndexRow,
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
}

pub fn getWorkspace(c: *spider.Ctx, workspace_id: i32) ![]model.WorkspaceRow {
    return db.query(
        model.WorkspaceRow,
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
        .{workspace_id},
    );
}

pub fn getWorkspaceIdOnly(c: *spider.Ctx, workspace_id: i32) ![]model.WorkspaceIdRow {
    return db.query(
        model.WorkspaceIdRow,
        c.arena,
        \\SELECT id
        \\FROM workspaces
        \\WHERE id = $1
        \\LIMIT 1
    ,
        .{workspace_id},
    );
}

pub fn createWorkspace(c: *spider.Ctx, form: model.WorkspaceForm, squad_name: []const u8, default_squad_id: i32) !void {
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
            squad_name,
            default_squad_id,
        },
    );
}

pub fn updateWorkspace(c: *spider.Ctx, form: model.WorkspaceForm, workspace_id: i32, squad_name: []const u8, default_squad_id: i32) !void {
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
            squad_name,
            default_squad_id,
            workspace_id,
        },
    );
}

pub fn updateWorkspaceWithLocalPathConfirm(c: *spider.Ctx, form: model.WorkspaceLocalPathConfirmForm, workspace_id: i32, squad_name: []const u8, default_squad_id: i32) !void {
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
            squad_name,
            default_squad_id,
            workspace_id,
        },
    );
}

pub fn deleteWorkspace(c: *spider.Ctx, workspace_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\DELETE FROM workspaces
        \\WHERE id = $1
    ,
        .{workspace_id},
    );
}

pub fn checkDuplicatedLocalPath(c: *spider.Ctx, local_path: []const u8, exclude_id: ?i32) ![]model.WorkspaceIdRow {
    if (exclude_id) |eid| {
        return db.query(
            model.WorkspaceIdRow,
            c.arena,
            \\SELECT id
            \\FROM workspaces
            \\WHERE local_path = $1
            \\AND id <> $2
            \\LIMIT 1
        ,
            .{ local_path, eid },
        );
    } else {
        return db.query(
            model.WorkspaceIdRow,
            c.arena,
            \\SELECT id
            \\FROM workspaces
            \\WHERE local_path = $1
            \\LIMIT 1
        ,
            .{local_path},
        );
    }
}

pub fn listSquads(c: *spider.Ctx) ![]model.WorkspaceSquadOptionRow {
    return db.query(
        model.WorkspaceSquadOptionRow,
        c.arena,
        \\SELECT id, name, slug
        \\FROM squads
        \\WHERE is_active = TRUE
        \\ORDER BY is_default DESC, name ASC
    ,
        .{},
    );
}

pub fn listSquadsForSelected(c: *spider.Ctx, selected_squad_id: i32) ![]model.WorkspaceSquadOptionRow {
    return db.query(
        model.WorkspaceSquadOptionRow,
        c.arena,
        \\SELECT id, name, slug
        \\FROM squads
        \\WHERE is_active = TRUE
        \\ORDER BY CASE WHEN id = $1 THEN 0 ELSE 1 END,
        \\         is_default DESC,
        \\         name ASC
    ,
        .{selected_squad_id},
    );
}

pub fn getSquadById(c: *spider.Ctx, squad_id: i32) ![]model.WorkspaceSquadOptionRow {
    return db.query(
        model.WorkspaceSquadOptionRow,
        c.arena,
        \\SELECT id, name, slug
        \\FROM squads
        \\WHERE id = $1
        \\AND is_active = TRUE
        \\LIMIT 1
    ,
        .{squad_id},
    );
}

pub fn listPanesForWorkspace(c: *spider.Ctx, workspace_id: i32) ![]model.WorkspacePaneRow {
    return db.query(
        model.WorkspacePaneRow,
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
        .{workspace_id},
    );
}

pub fn listControlPanes(c: *spider.Ctx, workspace_id: i32) ![]model.WorkspacePaneControlRow {
    return db.query(
        model.WorkspacePaneControlRow,
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
        .{workspace_id},
    );
}

pub fn getPaneControlRow(c: *spider.Ctx, pane_id: i32, workspace_id: i32) ![]model.WorkspacePaneControlRow {
    return db.query(
        model.WorkspacePaneControlRow,
        c.arena,
        \\SELECT id, workspace_id, role_name, agent_id, pane_state, session_external_id, session_agent_id, session_agent_handle, context_state
        \\FROM workspace_panes
        \\WHERE id = $1
        \\AND workspace_id = $2
        \\LIMIT 1
    ,
        .{ pane_id, workspace_id },
    );
}

pub fn getPaneControlRowSparse(c: *spider.Ctx, pane_id: i32, workspace_id: i32) ![]model.WorkspacePaneControlRow {
    return db.query(
        model.WorkspacePaneControlRow,
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
}

pub fn getPaneControlRowFull(c: *spider.Ctx, pane_id: i32, workspace_id: i32) ![]model.WorkspacePaneControlRow {
    return db.query(
        model.WorkspacePaneControlRow,
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
}

pub fn getPaneBootstrapData(c: *spider.Ctx, pane_id: i32, workspace_id: i32) ![]model.WorkspacePaneBootstrapRow {
    return db.query(
        model.WorkspacePaneBootstrapRow,
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
}

pub fn getRuntimeRow(c: *spider.Ctx, workspace_id: i32) ![]model.WorkspaceRuntimeRow {
    return db.query(
        model.WorkspaceRuntimeRow,
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
        .{workspace_id},
    );
}

pub fn getRuntimeControlRow(c: *spider.Ctx, workspace_id: i32) ![]model.WorkspaceRuntimeControlRow {
    return db.query(
        model.WorkspaceRuntimeControlRow,
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
        .{workspace_id},
    );
}

pub fn upsertRuntimeRow(c: *spider.Ctx, workspace_id: i32, container_name: []const u8) !void {
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
}

pub fn updateRuntimeState(c: *spider.Ctx, workspace_id: i32, state: []const u8, status_message: []const u8) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE workspace_runtimes
        \\SET state = $1,
        \\    status_message = $2,
        \\    updated_at = NOW()
        \\WHERE workspace_id = $3
    ,
        .{ state, status_message, workspace_id },
    );
}

pub fn updateRuntimeStateWithPort(c: *spider.Ctx, workspace_id: i32, state: []const u8, opencode_port: i32, server_url: []const u8, status_message: []const u8) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE workspace_runtimes
        \\SET state = $1,
        \\    opencode_port = $2,
        \\    server_url = $3,
        \\    status_message = $4,
        \\    updated_at = NOW()
        \\WHERE workspace_id = $5
    ,
        .{ state, opencode_port, server_url, status_message, workspace_id },
    );
}

pub fn resetRuntimeOnPathChange(c: *spider.Ctx, workspace_id: i32) !void {
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
        .{workspace_id},
    );
}

pub fn markPanesStaleOnPathChange(c: *spider.Ctx, workspace_id: i32) !void {
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
        .{workspace_id},
    );
}

pub fn listRuntimeEvents(c: *spider.Ctx, workspace_id: i32) ![]model.WorkspaceRuntimeEventRow {
    return db.query(
        model.WorkspaceRuntimeEventRow,
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
        .{workspace_id},
    );
}

pub fn listRuntimeLogs(c: *spider.Ctx, workspace_id: i32) ![]model.WorkspaceRuntimeLogRow {
    return db.query(
        model.WorkspaceRuntimeLogRow,
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
        .{workspace_id},
    );
}

pub fn listPaneSessionHistory(c: *spider.Ctx, workspace_id: i32) ![]model.WorkspacePaneSessionHistoryRow {
    return db.query(
        model.WorkspacePaneSessionHistoryRow,
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
        .{workspace_id},
    );
}

pub fn getRuntimeCountRunning(c: *spider.Ctx) ![]model.WorkspaceRuntimeCountRow {
    return db.query(
        model.WorkspaceRuntimeCountRow,
        c.arena,
        \\SELECT COUNT(*)::bigint AS total
        \\FROM workspace_runtimes
        \\WHERE state = 'running'
    ,
        .{},
    );
}

pub fn getMissionCountOpen(c: *spider.Ctx) ![]model.WorkspaceRuntimeCountRow {
    return db.query(
        model.WorkspaceRuntimeCountRow,
        c.arena,
        \\SELECT COUNT(*)::bigint AS total
        \\FROM missions
        \\WHERE status <> 'completed'
    ,
        .{},
    );
}

pub fn listWorkspaceMemoryEntries(c: *spider.Ctx, workspace_id: i32) ![]model.WorkspaceMemoryEntryRow {
    return db.query(
        model.WorkspaceMemoryEntryRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    title,
        \\    content,
        \\    TO_CHAR(created_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS') AS created_at_label
        \\FROM workspace_memory_entries
        \\WHERE workspace_id = $1
        \\ORDER BY id DESC
        \\LIMIT 8
    ,
        .{workspace_id},
    );
}

pub fn insertMemoryEntry(c: *spider.Ctx, workspace_id: i32, form: model.WorkspaceMemoryForm) !void {
    try db.query(
        void,
        c.arena,
        \\INSERT INTO workspace_memory_entries (
        \\    workspace_id,
        \\    title,
        \\    content
        \\)
        \\VALUES ($1, $2, $3)
    ,
        .{ workspace_id, form.title, form.content },
    );
}

pub fn getMemoryEntry(c: *spider.Ctx, entry_id: i32, workspace_id: i32) ![]model.WorkspaceMemoryEntryRow {
    return db.query(
        model.WorkspaceMemoryEntryRow,
        c.arena,
        \\SELECT id, title, content, TO_CHAR(created_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS') AS created_at_label
        \\FROM workspace_memory_entries
        \\WHERE id = $1
        \\AND workspace_id = $2
        \\LIMIT 1
    ,
        .{ entry_id, workspace_id },
    );
}

pub fn updateMemoryEntry(c: *spider.Ctx, entry_id: i32, workspace_id: i32, form: model.WorkspaceMemoryForm) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE workspace_memory_entries
        \\SET title = $1,
        \\    content = $2
        \\WHERE id = $3
        \\AND workspace_id = $4
    ,
        .{ form.title, form.content, entry_id, workspace_id },
    );
}

pub fn deleteMemoryEntry(c: *spider.Ctx, entry_id: i32, workspace_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\DELETE FROM workspace_memory_entries
        \\WHERE id = $1
        \\AND workspace_id = $2
    ,
        .{ entry_id, workspace_id },
    );
}

pub fn listWorkspaceHandoffs(c: *spider.Ctx, workspace_id: i32) ![]model.WorkspaceHandoffRow {
    return db.query(
        model.WorkspaceHandoffRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    from_role,
        \\    to_role,
        \\    summary,
        \\    context,
        \\    TO_CHAR(created_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS') AS created_at_label
        \\FROM workspace_handoffs
        \\WHERE workspace_id = $1
        \\ORDER BY id DESC
        \\LIMIT 8
    ,
        .{workspace_id},
    );
}

pub fn insertHandoff(c: *spider.Ctx, workspace_id: i32, form: model.WorkspaceHandoffForm) !void {
    try db.query(
        void,
        c.arena,
        \\INSERT INTO workspace_handoffs (
        \\    workspace_id,
        \\    from_role,
        \\    to_role,
        \\    summary,
        \\    context
        \\)
        \\VALUES ($1, $2, $3, $4, $5)
    ,
        .{ workspace_id, form.from_role, form.to_role, form.summary, form.context },
    );
}

pub fn getHandoff(c: *spider.Ctx, entry_id: i32, workspace_id: i32) ![]model.WorkspaceHandoffRow {
    return db.query(
        model.WorkspaceHandoffRow,
        c.arena,
        \\SELECT id, from_role, to_role, summary, context, TO_CHAR(created_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS') AS created_at_label
        \\FROM workspace_handoffs
        \\WHERE id = $1
        \\AND workspace_id = $2
        \\LIMIT 1
    ,
        .{ entry_id, workspace_id },
    );
}

pub fn updateHandoff(c: *spider.Ctx, entry_id: i32, workspace_id: i32, form: model.WorkspaceHandoffForm) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE workspace_handoffs
        \\SET from_role = $1,
        \\    to_role = $2,
        \\    summary = $3,
        \\    context = $4
        \\WHERE id = $5
        \\AND workspace_id = $6
    ,
        .{ form.from_role, form.to_role, form.summary, form.context, entry_id, workspace_id },
    );
}

pub fn deleteHandoff(c: *spider.Ctx, entry_id: i32, workspace_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\DELETE FROM workspace_handoffs
        \\WHERE id = $1
        \\AND workspace_id = $2
    ,
        .{ entry_id, workspace_id },
    );
}

pub fn listWorkspaceDecisionRecords(c: *spider.Ctx, workspace_id: i32) ![]model.WorkspaceDecisionRecordRow {
    return db.query(
        model.WorkspaceDecisionRecordRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    title,
        \\    decision,
        \\    rationale,
        \\    TO_CHAR(created_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS') AS created_at_label
        \\FROM workspace_decision_records
        \\WHERE workspace_id = $1
        \\ORDER BY id DESC
        \\LIMIT 8
    ,
        .{workspace_id},
    );
}

pub fn insertDecisionRecord(c: *spider.Ctx, workspace_id: i32, form: model.WorkspaceDecisionRecordForm) !void {
    try db.query(
        void,
        c.arena,
        \\INSERT INTO workspace_decision_records (
        \\    workspace_id,
        \\    title,
        \\    decision,
        \\    rationale
        \\)
        \\VALUES ($1, $2, $3, $4)
    ,
        .{ workspace_id, form.title, form.decision, form.rationale },
    );
}

pub fn getDecisionRecord(c: *spider.Ctx, entry_id: i32, workspace_id: i32) ![]model.WorkspaceDecisionRecordRow {
    return db.query(
        model.WorkspaceDecisionRecordRow,
        c.arena,
        \\SELECT id, title, decision, rationale, TO_CHAR(created_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS') AS created_at_label
        \\FROM workspace_decision_records
        \\WHERE id = $1
        \\AND workspace_id = $2
        \\LIMIT 1
    ,
        .{ entry_id, workspace_id },
    );
}

pub fn updateDecisionRecord(c: *spider.Ctx, entry_id: i32, workspace_id: i32, form: model.WorkspaceDecisionRecordForm) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE workspace_decision_records
        \\SET title = $1,
        \\    decision = $2,
        \\    rationale = $3
        \\WHERE id = $4
        \\AND workspace_id = $5
    ,
        .{ form.title, form.decision, form.rationale, entry_id, workspace_id },
    );
}

pub fn deleteDecisionRecord(c: *spider.Ctx, entry_id: i32, workspace_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\DELETE FROM workspace_decision_records
        \\WHERE id = $1
        \\AND workspace_id = $2
    ,
        .{ entry_id, workspace_id },
    );
}

pub fn listWorkspaceSnapshots(c: *spider.Ctx, workspace_id: i32) ![]model.WorkspaceSnapshotRow {
    return db.query(
        model.WorkspaceSnapshotRow,
        c.arena,
        \\SELECT
        \\    id,
        \\    title,
        \\    scope,
        \\    content,
        \\    TO_CHAR(created_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS') AS created_at_label
        \\FROM workspace_snapshots
        \\WHERE workspace_id = $1
        \\ORDER BY id DESC
        \\LIMIT 8
    ,
        .{workspace_id},
    );
}

pub fn insertSnapshot(c: *spider.Ctx, workspace_id: i32, form: model.WorkspaceSnapshotForm) !void {
    try db.query(
        void,
        c.arena,
        \\INSERT INTO workspace_snapshots (
        \\    workspace_id,
        \\    title,
        \\    scope,
        \\    content
        \\)
        \\VALUES ($1, $2, $3, $4)
    ,
        .{ workspace_id, form.title, form.scope, form.content },
    );
}

pub fn getSnapshot(c: *spider.Ctx, entry_id: i32, workspace_id: i32) ![]model.WorkspaceSnapshotRow {
    return db.query(
        model.WorkspaceSnapshotRow,
        c.arena,
        \\SELECT id, title, scope, content, TO_CHAR(created_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS') AS created_at_label
        \\FROM workspace_snapshots
        \\WHERE id = $1
        \\AND workspace_id = $2
        \\LIMIT 1
    ,
        .{ entry_id, workspace_id },
    );
}

pub fn updateSnapshot(c: *spider.Ctx, entry_id: i32, workspace_id: i32, form: model.WorkspaceSnapshotForm) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE workspace_snapshots
        \\SET title = $1,
        \\    scope = $2,
        \\    content = $3
        \\WHERE id = $4
        \\AND workspace_id = $5
    ,
        .{ form.title, form.scope, form.content, entry_id, workspace_id },
    );
}

pub fn deleteSnapshot(c: *spider.Ctx, entry_id: i32, workspace_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\DELETE FROM workspace_snapshots
        \\WHERE id = $1
        \\AND workspace_id = $2
    ,
        .{ entry_id, workspace_id },
    );
}

pub fn listWorkspaceMissions(c: *spider.Ctx, workspace_id: i32) ![]model.WorkspaceMissionPreviewRow {
    return db.query(
        model.WorkspaceMissionPreviewRow,
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
        \\    m.execution_mode,
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
        .{workspace_id},
    );
}

pub fn getActiveMissionPanel(c: *spider.Ctx, workspace_id: i32) ![]model.ActiveMissionPanelRow {
    return db.query(
        model.ActiveMissionPanelRow,
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
        \\    m.execution_mode,
        \\    CASE
        \\        WHEN m.pilot_dispatch_status IS NULL THEN FALSE
        \\        ELSE TRUE
        \\    END AS execution_controls_enabled,
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
        \\    m.pilot_delivery_report_status,
        \\    m.next_step_detected_action,
        \\    m.next_step_detected_code,
        \\    m.next_step_detected_route,
        \\    COALESCE(
        \\        TO_CHAR(m.next_step_detected_at AT TIME ZONE 'America/Bahia', 'DD/MM/YYYY HH24:MI:SS'),
        \\        'Ainda não detectada'
        \\    ) AS next_step_detected_at_label
        \\FROM workspaces w
        \\INNER JOIN missions m ON m.id = w.active_mission_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\WHERE w.id = $1
        \\LIMIT 1
    ,
        .{workspace_id},
    );
}

pub fn listSquadMembers(c: *spider.Ctx, squad_id: i32) ![]model.SquadMemberRow {
    return db.query(
        model.SquadMemberRow,
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
        .{squad_id},
    );
}

pub fn deleteOrphanPanes(c: *spider.Ctx, workspace_id: i32, linked_squad_id: i32) !void {
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
        .{ workspace_id, linked_squad_id },
    );
}

pub fn deleteAllPanes(c: *spider.Ctx, workspace_id: i32) !void {
    try db.query(
        void,
        c.arena,
        \\DELETE FROM workspace_panes
        \\WHERE workspace_id = $1
    ,
        .{workspace_id},
    );
}

pub fn upsertPane(c: *spider.Ctx, workspace_id: i32, role_name: []const u8, squad_member_id: i32, agent_id: i32, display_order: i32) !void {
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
            workspace_id,
            role_name,
            squad_member_id,
            agent_id,
            display_order,
        },
    );
}

pub fn updatePaneState(c: *spider.Ctx, pane_id: i32, workspace_id: i32, pane_state: []const u8) !void {
    try db.query(
        void,
        c.arena,
        \\UPDATE workspace_panes
        \\SET pane_state = $1,
        \\    updated_at = NOW()
        \\WHERE id = $2
        \\AND workspace_id = $3
    ,
        .{ pane_state, pane_id, workspace_id },
    );
}

pub fn markPaneStale(c: *spider.Ctx, pane_id: i32, workspace_id: i32) !void {
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
}

pub fn updatePaneSession(c: *spider.Ctx, pane_id: i32, workspace_id: i32, session_id: []const u8, agent_id: i32, agent_handle: []const u8) !void {
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
        .{ session_id, agent_id, agent_handle, pane_id, workspace_id },
    );
}

pub fn markContextOutdated(c: *spider.Ctx, pane_id: i32, workspace_id: i32) !void {
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
}

pub fn insertPaneSessionHistory(c: *spider.Ctx, workspace_id: i32, pane_id: i32, role_name: []const u8, previous_session: []const u8, previous_agent_id: ?i32, previous_agent_handle: []const u8, previous_context_state: []const u8, new_session: []const u8, new_agent_id: i32, new_agent_handle: []const u8, replacement_reason: []const u8) !void {
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
            role_name,
            previous_session,
            previous_agent_id,
            previous_agent_handle,
            previous_context_state,
            new_session,
            new_agent_id,
            new_agent_handle,
            replacement_reason,
        },
    );
}

pub fn setActiveMission(c: *spider.Ctx, workspace_id: i32, mission_id: i32) !void {
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

pub fn insertMissionEvent(c: *spider.Ctx, mission_id: i32, workspace_id: i32) !void {
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

pub fn getPaneMissionDispatch(c: *spider.Ctx, workspace_id: i32) ![]model.WorkspaceMissionPaneDispatchRow {
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
        \\AND role_name = 'Piloto'
        \\LIMIT 1
    ,
        .{workspace_id},
    );
}

pub fn insertRuntimeCommandLogEntry(c: *spider.Ctx, workspace_id: i32, action: []const u8, command_label: []const u8, result: anytype) !void {
    const core = @import("core");
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
            core.runtimeLogExcerpt(result.stdout),
            core.runtimeLogExcerpt(result.stderr),
        },
    );
}
