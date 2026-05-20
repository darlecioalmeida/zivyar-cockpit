ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS reviewer_dispatch_status VARCHAR(60) NOT NULL DEFAULT 'not_sent';

ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS reviewer_session_external_id TEXT NOT NULL DEFAULT '';

ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS reviewer_dispatch_user_message_id TEXT NOT NULL DEFAULT '';

ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS dispatched_to_reviewer_at TIMESTAMPTZ NULL;
