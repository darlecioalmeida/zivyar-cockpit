CREATE TABLE IF NOT EXISTS workspace_runtime_logs (
    id SERIAL PRIMARY KEY,
    workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    action VARCHAR(80) NOT NULL,
    command_label TEXT NOT NULL,
    exit_code INTEGER NOT NULL DEFAULT -1,
    succeeded BOOLEAN NOT NULL DEFAULT FALSE,
    stdout_excerpt TEXT NOT NULL DEFAULT '',
    stderr_excerpt TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
