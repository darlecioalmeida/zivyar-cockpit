pub const WorkspaceRow = struct {
    id: i32, name: []const u8, local_path: []const u8, stack_name: []const u8,
    default_squad_id: ?i32, squad_name: []const u8, status: []const u8,
};

pub const WorkspaceMemoryEntryRow = struct { id: i32, title: []const u8, content: []const u8, created_at_label: []const u8 };
pub const WorkspaceHandoffRow = struct { id: i32, from_role: []const u8, to_role: []const u8, summary: []const u8, context: []const u8, created_at_label: []const u8 };
pub const WorkspaceDecisionRecordRow = struct { id: i32, title: []const u8, decision: []const u8, rationale: []const u8, created_at_label: []const u8 };
pub const WorkspaceSnapshotRow = struct { id: i32, title: []const u8, scope: []const u8, content: []const u8, created_at_label: []const u8 };
