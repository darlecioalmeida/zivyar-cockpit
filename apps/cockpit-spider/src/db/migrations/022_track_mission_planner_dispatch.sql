ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS planner_dispatch_status VARCHAR(60) NOT NULL DEFAULT 'not_sent';

ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS planner_session_external_id TEXT NOT NULL DEFAULT '';

ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS planner_dispatch_user_message_id TEXT NOT NULL DEFAULT '';

ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS dispatched_to_planner_at TIMESTAMPTZ NULL;
