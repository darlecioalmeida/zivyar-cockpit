pub const StackRow = struct {
    id: i32,
    name: []const u8,
    runtime_tool: []const u8,
    provider_model_id: i32,
    model_name: []const u8,
    model_identifier: []const u8,
    provider_name: []const u8,
    is_active: bool,
};

pub const StackForm = struct {
    name: []const u8,
    runtime_tool: []const u8,
    provider_model_id: []const u8,
    is_active: []const u8,
};

pub const StackIdRow = struct { id: i32 };

pub const StackModelOptionRow = struct {
    id: i32,
    model_name: []const u8,
    model_identifier: []const u8,
    provider_name: []const u8,
};
