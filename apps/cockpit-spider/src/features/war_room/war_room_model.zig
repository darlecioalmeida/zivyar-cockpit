const std = @import("std");

pub const WarRoomData = struct {
    workspace_name: []const u8,
    squad_name: []const u8,
    stack_name: []const u8,
    local_path: []const u8,
    runtime_state: []const u8,
    server_url: []const u8,
    agents: []AgentPane,
    events: []EventEntry,
};

pub const AgentPane = struct {
    id: i32,
    role: []const u8,
    agent_name: []const u8,
    agent_handle: []const u8,
    status: []const u8,
    session_id: []const u8,
    context_state: []const u8,
    last_message: []const u8,
    model_id: []const u8,
    provider_name: []const u8,
    available_models: []ModelEntry,
    is_active: bool,
    is_stale: bool,
    has_session: bool,
    show_terminal: bool,
    show_stale_warning: bool,
    show_awaiting_session: bool,
};

pub const EventEntry = struct {
    label: []const u8,
    message: []const u8,
    created_at: []const u8,
};

pub const ModelEntry = struct {
    id: []const u8,
    name: []const u8,
    provider_type: []const u8,
};
