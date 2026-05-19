CREATE TABLE IF NOT EXISTS workspace_runtime_events (
    id SERIAL PRIMARY KEY,
    workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    event_type VARCHAR(80) NOT NULL,
    title VARCHAR(220) NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
