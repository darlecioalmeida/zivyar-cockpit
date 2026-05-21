pub const SquadRow = struct { id: i32, name: []const u8, slug: []const u8, summary: []const u8, is_default: bool, is_active: bool };
pub const SquadIdRow = struct { id: i32 };
pub const SquadForm = struct { name: []const u8, slug: []const u8, summary: []const u8, is_default: []const u8, is_active: []const u8, pilot_agent_id: []const u8, planner_agent_id: []const u8, scout_agent_id: []const u8, builder_agent_id: []const u8, reviewer_agent_id: []const u8, executor_agent_id: []const u8 };
pub const SquadAgentOptionRow = struct { id: i32, name: []const u8, handle: []const u8, agent_role: []const u8 };
pub const SquadMemberRow = struct { id: i32, squad_id: i32, role_name: []const u8, agent_id: i32, display_order: i32, agent_name: []const u8, agent_handle: []const u8, agent_role: []const u8, stack_name: []const u8 };
pub const SquadMemberAgentIdRow = struct { agent_id: i32 };
