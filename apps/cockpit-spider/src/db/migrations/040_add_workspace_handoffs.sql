CREATE TABLE workspace_handoffs (
    id SERIAL PRIMARY KEY,
    workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    from_role TEXT NOT NULL,
    to_role TEXT NOT NULL,
    summary TEXT NOT NULL,
    context TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_workspace_handoffs_workspace_created_at
    ON workspace_handoffs (workspace_id, created_at DESC);
