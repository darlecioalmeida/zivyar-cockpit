pub const AgentRow = struct {
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

pub const AgentForm = struct {
    name: []const u8,
    handle: []const u8,
    agent_role: []const u8,
    summary: []const u8,
    system_prompt: []const u8,
    operating_rules: []const u8,
    default_stack_id: []const u8,
    is_active: []const u8,
};

pub const AgentIdRow = struct {
    id: i32,
};

pub const AgentStackOptionRow = struct {
    id: i32,
    name: []const u8,
    runtime_tool: []const u8,
    model_name: []const u8,
};
