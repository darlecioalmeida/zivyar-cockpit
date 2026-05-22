const std = @import("std");
const spider = @import("spider");
const db = spider.pg;
const model = @import("./war_room_model.zig");

pub fn loadWarRoomData(c: *spider.Ctx, workspace_id: i32) !model.WarRoomData {
    const ws_rows = try db.query(
        struct {
            id: i32,
            name: []const u8,
            local_path: []const u8,
            stack_name: []const u8,
            squad_name: []const u8,
        },
        c.arena,
        \\SELECT w.id, w.name, w.local_path, w.stack_name, COALESCE(s.name, '') AS squad_name
        \\FROM workspaces w
        \\LEFT JOIN squads s ON s.id = w.default_squad_id
        \\WHERE w.id = $1
        \\LIMIT 1
    , .{workspace_id});

    if (ws_rows.len == 0) return error.NotFound;

    const ws = ws_rows[0];

    const rt_rows = try db.query(
        struct {
            state: []const u8,
            server_url_label: []const u8,
        },
        c.arena,
        \\SELECT COALESCE(state, '') AS state, COALESCE(server_url, '') AS server_url_label
        \\FROM workspace_runtimes
        \\WHERE workspace_id = $1
        \\LIMIT 1
    , .{workspace_id});

    const RuntimeInfo = struct { state: []const u8, server_url_label: []const u8 };
    const runtime = if (rt_rows.len > 0) RuntimeInfo{ .state = rt_rows[0].state, .server_url_label = rt_rows[0].server_url_label } else RuntimeInfo{ .state = "", .server_url_label = "" };

    const pane_rows = try db.query(
        struct {
            id: i32,
            role_name: []const u8,
            agent_name: []const u8,
            agent_handle: []const u8,
            pane_state: []const u8,
            session_external_id: []const u8,
            context_state: []const u8,
            session_agent_handle: ?[]const u8,
            provider_id: i32,
            provider_name: []const u8,
        },
        c.arena,
        \\SELECT 
        \\  wp.id, 
        \\  wp.role_name, 
        \\  COALESCE(a.name, '') AS agent_name, 
        \\  COALESCE(a.handle, '') AS agent_handle, 
        \\  wp.pane_state, 
        \\  COALESCE(wp.session_external_id, '') AS session_external_id, 
        \\  wp.context_state, 
        \\  wp.session_agent_handle,
        \\  p.id as provider_id,
        \\  COALESCE(p.name, 'N/A') as provider_name
        \\FROM workspace_panes wp
        \\LEFT JOIN agents a ON a.id = wp.agent_id
        \\LEFT JOIN stacks s ON s.id = a.default_stack_id
        \\LEFT JOIN provider_models pm ON pm.id = s.provider_model_id
        \\LEFT JOIN providers p ON p.id = pm.provider_id
        \\WHERE wp.workspace_id = $1
        \\ORDER BY wp.display_order
    , .{workspace_id});

    const agents = try c.arena.alloc(model.AgentPane, pane_rows.len);
    for (pane_rows, 0..) |p, idx| {
        const model_rows = try db.query(
            struct {
                model_id: []const u8,
                model_name: []const u8,
            },
            c.arena,
            \\SELECT model_id, model_name
            \\FROM provider_models
            \\WHERE provider_id = $1 AND is_active = TRUE
            \\ORDER BY model_name ASC
        , .{p.provider_id});

        const agent_models = try c.arena.alloc(model.ModelEntry, model_rows.len);
        for (model_rows, 0..) |m_row, i| {
            agent_models[i] = .{ .id = m_row.model_id, .name = m_row.model_name };
        }

        agents[idx] = .{
            .id = p.id,
            .role = p.role_name,
            .agent_name = p.agent_name,
            .agent_handle = p.agent_handle,
            .status = p.pane_state,
            .session_id = p.session_external_id,
            .context_state = p.context_state,
            .last_message = "",
            .model_id = p.session_agent_handle orelse "",
            .provider_name = p.provider_name,
            .available_models = agent_models,
        };
    }

    const event_rows = try db.query(
        struct {
            created_at_label: []const u8,
            title: []const u8,
            message: []const u8,
        },
        c.arena,
        \\SELECT COALESCE(TO_CHAR(me.created_at, 'HH24:MI'), '') AS created_at_label, me.title, COALESCE(me.message, '') AS message
        \\FROM mission_events me
        \\JOIN missions m ON m.id = me.mission_id
        \\WHERE m.workspace_id = $1 AND m.status != 'closed'
        \\ORDER BY me.created_at DESC
        \\LIMIT 20
    , .{workspace_id});

    const event_count = @min(event_rows.len, 20);
    const events = try c.arena.alloc(model.EventEntry, event_count);
    for (event_rows, 0..) |ev, i| {
        if (i >= event_count) break;
        events[i] = .{ .label = ev.title, .message = ev.message, .created_at = ev.created_at_label };
    }

    return model.WarRoomData{
        .workspace_name = ws.name,
        .squad_name = ws.squad_name,
        .stack_name = ws.stack_name,
        .local_path = ws.local_path,
        .runtime_state = runtime.state,
        .server_url = runtime.server_url_label,
        .agents = agents,
        .events = events,
    };
}

pub const AgentPanePromptRow = struct {
    session_external_id: []const u8,
};

pub fn loadAgentPanesForPrompt(c: *spider.Ctx, workspace_id: i32) ![]AgentPanePromptRow {
    return db.query(
        AgentPanePromptRow,
        c.arena,
        \\SELECT COALESCE(session_external_id, '') AS session_external_id
        \\FROM workspace_panes
        \\WHERE workspace_id = $1 AND session_external_id != ''
        \\ORDER BY display_order
    , .{workspace_id});
}

pub const RuntimePromptRow = struct {
    server_url: []const u8,
};

pub fn loadRuntimeForPrompt(c: *spider.Ctx, workspace_id: i32) !RuntimePromptRow {
    const rows = try db.query(
        RuntimePromptRow,
        c.arena,
        \\SELECT COALESCE(server_url, '') AS server_url
        \\FROM workspace_runtimes
        \\WHERE workspace_id = $1 AND state = 'running'
        \\LIMIT 1
    , .{workspace_id});
    if (rows.len == 0) return error.NotFound;
    return rows[0];
}

pub fn updatePaneDisplayOrder(
    c: *spider.Ctx,
    workspace_id: i32,
    pane_ids: []const i32,
) !void {
    if (pane_ids.len == 0) return;

    var tx = try db.begin();
    defer tx.rollback();

    const UpdateStmt = "UPDATE workspace_panes SET display_order = $1 WHERE id = $2 AND workspace_id = $3";

    for (pane_ids, 0..) |pane_id, idx| {
        const display_order = @as(i32, @intCast(idx));
        try tx.query(
            void,
            c.arena,
            UpdateStmt,
            .{display_order, pane_id, workspace_id},
        );
    }

    try tx.commit();
}
