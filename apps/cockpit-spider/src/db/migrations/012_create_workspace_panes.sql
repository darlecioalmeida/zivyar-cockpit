CREATE TABLE IF NOT EXISTS workspace_panes (
    id SERIAL PRIMARY KEY,
    workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    role_name VARCHAR(80) NOT NULL,
    squad_member_id INTEGER NULL REFERENCES squad_members(id) ON DELETE SET NULL,
    agent_id INTEGER NOT NULL REFERENCES agents(id) ON DELETE RESTRICT,
    pane_state VARCHAR(60) NOT NULL DEFAULT 'idle',
    session_external_id TEXT NOT NULL DEFAULT '',
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT workspace_panes_workspace_role_unique UNIQUE (workspace_id, role_name)
);
