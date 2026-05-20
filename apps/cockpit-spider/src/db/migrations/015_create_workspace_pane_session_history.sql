CREATE TABLE IF NOT EXISTS workspace_pane_session_history (
    id SERIAL PRIMARY KEY,
    workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    pane_id INTEGER NULL REFERENCES workspace_panes(id) ON DELETE SET NULL,
    role_name VARCHAR(80) NOT NULL,

    previous_session_external_id TEXT NOT NULL,
    previous_session_agent_id INTEGER NULL REFERENCES agents(id) ON DELETE SET NULL,
    previous_session_agent_handle TEXT NOT NULL DEFAULT '',
    previous_context_state VARCHAR(60) NOT NULL DEFAULT '',

    replacement_session_external_id TEXT NOT NULL,
    replacement_session_agent_id INTEGER NULL REFERENCES agents(id) ON DELETE SET NULL,
    replacement_session_agent_handle TEXT NOT NULL DEFAULT '',

    replacement_reason VARCHAR(80) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS workspace_pane_session_history_workspace_idx
    ON workspace_pane_session_history(workspace_id, created_at DESC);

CREATE INDEX IF NOT EXISTS workspace_pane_session_history_pane_idx
    ON workspace_pane_session_history(pane_id, created_at DESC);
