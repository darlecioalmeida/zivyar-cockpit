CREATE TABLE IF NOT EXISTS mission_events (
    id SERIAL PRIMARY KEY,
    mission_id INTEGER NOT NULL REFERENCES missions(id) ON DELETE CASCADE,
    workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    event_type VARCHAR(100) NOT NULL,
    title VARCHAR(220) NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS mission_events_mission_idx
    ON mission_events(mission_id, created_at DESC);

CREATE INDEX IF NOT EXISTS mission_events_workspace_idx
    ON mission_events(workspace_id, created_at DESC);
