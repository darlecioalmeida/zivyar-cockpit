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
        .get("/workspaces/:id", workspaceShow)
        .get("/missions", missions)
        .get("/agents", agents)
        .get("/squads", squads)
        .get("/providers", providers)
        .get("/providers/new", providerNew)
        .post("/providers", providerCreate)
        .get("/providers/:id/edit", providerEdit)
        .post("/providers/:id/update", providerUpdate)
        .post("/providers/:id/delete", providerDelete)
        .listen(.{}) catch {};
}

const WorkspaceRow = struct {
    id: i32,
    name: []const u8,
    local_path: []const u8,
    stack_name: []const u8,
    default_squad: []const u8,
    status: []const u8,
};

const WorkspaceForm = struct {
    name: []const u8,
    local_path: []const u8,
    stack_name: []const u8,
    default_squad: []const u8,
};

const WorkspaceIdRow = struct {
    id: i32,
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

fn dashboard(c: *spider.Ctx) !spider.Response {
    return c.view("dashboard/index", .{
        .title = "Zivyar Cockpit",
        .subtitle = "Desktop Multi-Agent Engineering Cockpit",
    }, .{});
}

fn workspaces(c: *spider.Ctx) !spider.Response {
    const rows = try db.query(
        WorkspaceRow,
        c.arena,
        \\SELECT id, name, local_path, stack_name, default_squad, status
        \\FROM workspaces
        \\ORDER BY id DESC
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
        .runtime_count = 0,
        .mission_count = 0,
        .notice = notice,
    }, .{});
}

fn workspaceNew(c: *spider.Ctx) !spider.Response {
    return c.view("workspaces/new", .{
        .title = "Novo Workspace",
        .error_message = "",
        .form = .{
            .name = "",
            .local_path = "",
            .stack_name = "Spider + Zig",
            .default_squad = "Official Cockpit Squad",
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
        \\SELECT id, name, local_path, stack_name, default_squad, status
        \\FROM workspaces
        \\WHERE id = $1
        \\LIMIT 1
        ,
        .{ workspace_id },
    );

    if (rows.len == 0) {
        return c.text("Workspace não encontrado.", .{ .status = .not_found });
    }

    const workspace = rows[0];

    return c.view("workspaces/edit", .{
        .title = "Editar Workspace",
        .workspace = workspace,
        .error_message = "",
    }, .{});
}

fn workspaceUpdate(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });

    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const form = try c.parseForm(WorkspaceForm);

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
        const workspace = WorkspaceRow{
            .id = workspace_id,
            .name = form.name,
            .local_path = form.local_path,
            .stack_name = form.stack_name,
            .default_squad = form.default_squad,
            .status = "registered",
        };

        return c.view("workspaces/edit", .{
            .title = "Editar Workspace",
            .workspace = workspace,
            .error_message = "Outro workspace já utiliza este caminho local.",
        }, .{ .status = .bad_request });
    }

    try db.query(
        void,
        c.arena,
        \\UPDATE workspaces
        \\SET name = $1,
        \\    local_path = $2,
        \\    stack_name = $3,
        \\    default_squad = $4
        \\WHERE id = $5
        ,
        .{
            form.name,
            form.local_path,
            form.stack_name,
            form.default_squad,
            workspace_id,
        },
    );

    return c.redirect("/workspaces?updated=1");
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
        \\SELECT id, name, local_path, stack_name, default_squad, status
        \\FROM workspaces
        \\WHERE id = $1
        \\LIMIT 1
        ,
        .{ workspace_id },
    );

    if (rows.len == 0) {
        return c.text("Workspace não encontrado.", .{ .status = .not_found });
    }

    const workspace = rows[0];

    return c.view("workspaces/show", .{
        .title = workspace.name,
        .workspace = workspace,
    }, .{});
}


fn workspaceCreate(c: *spider.Ctx) !spider.Response {
    const form = try c.parseForm(WorkspaceForm);

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
            .error_message = "Já existe um workspace cadastrado com este caminho local.",
            .form = form,
        }, .{ .status = .bad_request });
    }

    try db.query(
        void,
        c.arena,
        \\INSERT INTO workspaces (name, local_path, stack_name, default_squad)
        \\VALUES ($1, $2, $3, $4)
        ,
        .{
            form.name,
            form.local_path,
            form.stack_name,
            form.default_squad,
        },
    );

    return c.redirect("/workspaces?created=1");
}

fn missions(c: *spider.Ctx) !spider.Response {
    return c.view("missions/index", .{ .title = "Missions" }, .{});
}

fn agents(c: *spider.Ctx) !spider.Response {
    return c.view("agents/index", .{ .title = "Agents" }, .{});
}

fn squads(c: *spider.Ctx) !spider.Response {
    return c.view("squads/index", .{ .title = "Squads" }, .{});
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

    return c.view("providers/index", .{
        .title = "Providers",
        .providers = rows,
        .provider_count = rows.len,
        .active_count = countActiveProviders(rows),
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
