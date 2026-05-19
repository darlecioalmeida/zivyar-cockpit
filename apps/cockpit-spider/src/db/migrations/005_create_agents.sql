CREATE TABLE IF NOT EXISTS agents (
    id SERIAL PRIMARY KEY,
    name VARCHAR(180) NOT NULL,
    handle VARCHAR(120) NOT NULL UNIQUE,
    agent_role VARCHAR(80) NOT NULL,
    summary TEXT NOT NULL,
    system_prompt TEXT NOT NULL,
    operating_rules TEXT NOT NULL,
    default_stack_id INTEGER NOT NULL REFERENCES stacks(id) ON DELETE RESTRICT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
