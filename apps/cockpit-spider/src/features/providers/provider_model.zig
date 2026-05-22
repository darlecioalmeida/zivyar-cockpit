pub const ProviderRow = struct { id: i32, name: []const u8, provider_type: []const u8, base_url: []const u8, api_key: []const u8, is_active: bool };
pub const ProviderForm = struct { name: []const u8, provider_type: []const u8, base_url: []const u8, api_key: []const u8, is_active: []const u8 };
pub const ProviderIdRow = struct { id: i32 };

pub const ProviderModelRow = struct { id: i32, provider_id: i32, model_name: []const u8, model_id: []const u8, context_window: i32, is_active: bool };
pub const ProviderModelForm = struct { model_name: []const u8, model_id: []const u8, context_window: []const u8, is_active: []const u8 };
pub const ProviderModelIdRow = struct { id: i32 };
pub const ProviderModelWithProviderRow = struct { id: i32, provider_id: i32, model_name: []const u8, model_id: []const u8, context_window: i32, is_active: bool, provider_name: []const u8, provider_type: []const u8 };
