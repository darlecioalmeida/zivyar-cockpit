CREATE TABLE IF NOT EXISTS workspace_runtimes (
    id SERIAL PRIMARY KEY,
    workspace_id INTEGER NOT NULL UNIQUE REFERENCES workspaces(id) ON DELETE CASCADE,
    state VARCHAR(60) NOT NULL DEFAULT 'stopped',
    container_name VARCHAR(220) NOT NULL DEFAULT '',
    opencode_port INTEGER NOT NULL DEFAULT 0,
    server_url VARCHAR(260) NOT NULL DEFAULT '',
    status_message TEXT NOT NULL DEFAULT 'Runtime preparado, aguardando inicialização.',
    last_heartbeat_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
