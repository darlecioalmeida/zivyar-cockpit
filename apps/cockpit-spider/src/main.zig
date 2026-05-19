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
    return c.view("providers/index", .{ .title = "Providers" }, .{});
}
