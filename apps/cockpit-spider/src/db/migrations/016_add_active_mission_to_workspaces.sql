ALTER TABLE workspaces
    ADD COLUMN IF NOT EXISTS active_mission_id INTEGER NULL REFERENCES missions(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS workspaces_active_mission_idx
    ON workspaces(active_mission_id);
