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
        .post("/workspaces/:id/delete", workspaceDelete)
        .post("/workspaces/:id/runtime/prepare", workspaceRuntimePrepare)
        .post("/workspaces/:id/runtime/start", workspaceRuntimeStart)
        .post("/workspaces/:id/runtime/stop", workspaceRuntimeStop)
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

const WorkspaceForm = struct {
    name: []const u8,
    local_path: []const u8,
    stack_name: []const u8,
    default_squad_id: []const u8,
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
};

const MissionForm = struct {
    workspace_id: []const u8,
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

const MissionWorkspaceOptionRow = struct {
    id: i32,
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
        .stdout = runtimeLogExcerpt(result.stdout),
        .stderr = runtimeLogExcerpt(result.stderr),
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
            result.stdout,
            result.stderr,
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
        \\    m.priority
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
        \\ORDER BY w.id DESC
        ,
        .{},
    );

    const runtime_count_rows = try db.query(
        WorkspaceRuntimeCountRow,
        c.arena,
        \\SELECT COUNT(*)::bigint AS total
        \\FROM workspace_runtimes
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
        .mission_count = 0,
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
        }, .{ .status = .bad_request });
    }

    if (default_squad_id <= 0) {
        return c.view("workspaces/edit", .{
            .title = "Editar Workspace",
            .workspace = current_rows[0],
            .squads = squads_rows,
            .squad_count = squads_rows.len,
            .error_message = "Selecione uma squad padrão válida.",
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

    const workspace_missions = try db.query(
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
        \\    m.priority
        \\FROM missions m
        \\INNER JOIN workspaces w ON w.id = m.workspace_id
        \\LEFT JOIN squads s ON s.id = m.squad_id
        \\WHERE m.workspace_id = $1
        \\ORDER BY m.id DESC
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

    return c.view("workspaces/show", .{
        .title = workspace.name,
        .workspace = workspace,
        .members = members,
        .member_count = members.len,
        .missions = workspace_missions,
        .mission_count = workspace_missions.len,
        .runtime = refreshed_runtime_rows[0],
        .runtime_events = runtime_events,
        .runtime_event_count = runtime_events.len,
        .runtime_logs = runtime_logs,
        .runtime_log_count = runtime_logs.len,
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
        \\    m.priority
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
        if (!std.mem.eql(u8, row.status, "completed")) {
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
            .workspace_id = "",
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

    try db.query(
        void,
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
        ,
        .{
            workspace_id,
            selected_workspace[0].default_squad_id,
            form.title,
            form.objective,
            form.status,
            form.priority,
        },
    );

    return c.redirect("/missions?created=1");
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
        \\    m.priority
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

    return c.view("missions/show", .{
        .title = rows[0].title,
        .mission = rows[0],
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
        \\    m.priority
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
        \\    m.priority
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
            form.status,
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

