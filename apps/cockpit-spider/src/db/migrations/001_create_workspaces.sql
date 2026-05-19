CREATE TABLE IF NOT EXISTS workspaces (
    id SERIAL PRIMARY KEY,
    name VARCHAR(180) NOT NULL,
    local_path TEXT NOT NULL UNIQUE,
    stack_name VARCHAR(120) NOT NULL,
    default_squad VARCHAR(160) NOT NULL,
    status VARCHAR(40) NOT NULL DEFAULT 'registered',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
