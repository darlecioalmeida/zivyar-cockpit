const std = @import("std");
const spider = @import("spider");
const core = @import("core");
const helpers = @import("../../shared/helpers.zig");
const model = @import("./war_room_model.zig");
const repo = @import("./war_room_repository.zig");

pub fn show(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("Workspace não informado.", .{ .status = .bad_request });
    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("Workspace inválido.", .{ .status = .bad_request });

    const data = repo.loadWarRoomData(c, workspace_id) catch |err| {
        std.log.err("war_room: loadWarRoomData error: {}", .{err});
        return switch (err) {
            error.NotFound => c.text("Workspace não encontrado.", .{ .status = .not_found }),
            else => blk: {
                const msg = std.fmt.allocPrint(c.arena, "Erro ao carregar war room: {s}", .{@errorName(err)}) catch
                    "Erro ao carregar war room.";
                break :blk c.text(msg, .{ .status = .bad_request });
            },
        };
    };

    return c.view("war_room/index", .{
        .title = data.workspace_name,
        .workspace_id = workspace_id,
        .ws_name = data.workspace_name,
        .squad_name = data.squad_name,
        .stack_name = data.stack_name,
        .local_path = data.local_path,
        .runtime_state = data.runtime_state,
        .server_url = data.server_url,
        .agents = data.agents,
        .agent_count = data.agents.len,
        .events = data.events,
        .event_count = data.events.len,
    }, .{});
}

pub fn agentsJson(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("", .{ .status = .bad_request });
    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("", .{ .status = .bad_request });

    const data = repo.loadWarRoomData(c, workspace_id) catch |err| {
        std.log.err("war_room: agentsJson loadWarRoomData error: {}", .{err});
        return c.json(.{ .agents = &[_]model.AgentPane{} }, .{});
    };

    return c.json(.{ 
        .agents = data.agents, 
        .events = data.events, 
        .server_url = data.server_url
    }, .{});
}

pub fn prompt(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("", .{ .status = .bad_request });
    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("", .{ .status = .bad_request });

    const parsed = try c.bodyJson(struct {
        text: []const u8,
        target: []const u8,
        model_id: ?[]const u8 = null,
    });

    const msg_text = parsed.text;
    if (msg_text.len == 0) return c.text("", .{ .status = .bad_request });

    const panes = try repo.loadAgentPanesForPrompt(c, workspace_id);
    for (panes) |pane| {
        if (pane.session_external_id.len == 0) continue;
        const runtime = repo.loadRuntimeForPrompt(c, workspace_id) catch continue;
        if (runtime.server_url.len == 0) continue;
        
        const model_id = parsed.model_id orelse "big-pickle";
        const prompt_url = try std.fmt.allocPrint(c.arena, "{s}/session/{s}/prompt_async", .{ runtime.server_url, pane.session_external_id });
        const prompt_body = try std.fmt.allocPrint(c.arena,
            \\{{"model":{{"providerID":"opencode","modelID":"{s}"}},"parts":[{{"type":"text","text":"{s}"}}]}}
        , .{ model_id, msg_text });
        
        const result = core.runRuntimeCommand(c, &.{
            "curl", "-fsS", "-X", "POST", prompt_url,
            "-H", "Content-Type: application/json",
            "-d", prompt_body,
        });
        
        if (!result.ok) {
            std.log.err("war_room: broadcast prompt failed for session {s}: {s}", .{ pane.session_external_id, result.stderr });
        }
    }

    return c.json(.{ .ok = true }, .{});
}

pub fn reorder(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("", .{ .status = .bad_request });
    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("", .{ .status = .bad_request });

    const Payload = struct {
        order: []const i32,
    };

    const payload = c.bodyJson(Payload) catch
        return c.text("", .{ .status = .bad_request });

    repo.updatePaneDisplayOrder(c, workspace_id, payload.order) catch |err| {
        std.log.err("war_room: reorder update error: {}", .{err});
        return c.text("", .{ .status = .internal_server_error });
    };

    return c.json(.{ .ok = true }, .{});
}

pub fn promptAgent(c: *spider.Ctx) !spider.Response {
    const id_raw = c.params.get("id") orelse
        return c.text("", .{ .status = .bad_request });
    const workspace_id = std.fmt.parseInt(i32, id_raw, 10) catch
        return c.text("", .{ .status = .bad_request });

    const parsed = try c.bodyJson(struct {
        text: []const u8,
        session_id: []const u8,
        model_id: ?[]const u8 = null,
        provider_id: ?[]const u8 = null,
    });

    const msg_text = parsed.text;
    if (msg_text.len == 0 or parsed.session_id.len == 0)
        return c.text("", .{ .status = .bad_request });

    const runtime = repo.loadRuntimeForPrompt(c, workspace_id) catch {
        return c.json(.{ .ok = false, .err = "runtime not running" }, .{ .status = .bad_request });
    };
    if (runtime.server_url.len == 0)
        return c.json(.{ .ok = false, .err = "no runtime url" }, .{ .status = .bad_request });

    const model_id = parsed.model_id orelse "big-pickle";
    const provider_id = parsed.provider_id orelse "opencode";
    
    const opencode_provider = helpers.mapProviderTypeToOpenCode(provider_id, provider_id);

    const prompt_url = try std.fmt.allocPrint(c.arena, "{s}/session/{s}/prompt_async", .{ runtime.server_url, parsed.session_id });
    const prompt_body = try std.fmt.allocPrint(c.arena,
        \\{{"model":{{"providerID":"{s}","modelID":"{s}"}},"parts":[{{"type":"text","text":"{s}"}}]}}
    , .{ opencode_provider, model_id, msg_text });
    
    std.log.info("war_room: sending prompt to {s} using model {s}/{s}", .{ prompt_url, opencode_provider, model_id });
    
    const result = core.runRuntimeCommand(c, &.{
        "curl", "-v", "-fsS", "-X", "POST", prompt_url,
        "-H", "Content-Type: application/json",
        "-d", prompt_body,
    });
    
    if (!result.ok) {
        std.log.err("war_room: promptAgent failed: {s}", .{result.stderr});
        return c.json(.{ .ok = false, .err = result.stderr }, .{ .status = .internal_server_error });
    }

    return c.json(.{ .ok = true }, .{});
}
