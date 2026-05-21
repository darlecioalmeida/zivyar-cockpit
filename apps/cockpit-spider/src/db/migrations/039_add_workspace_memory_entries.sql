CREATE TABLE workspace_memory_entries (
    id SERIAL PRIMARY KEY,
    workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_workspace_memory_entries_workspace_created_at
    ON workspace_memory_entries (workspace_id, created_at DESC);
