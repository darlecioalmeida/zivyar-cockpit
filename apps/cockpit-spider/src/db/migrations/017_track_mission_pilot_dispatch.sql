ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS pilot_dispatch_status VARCHAR(60) NOT NULL DEFAULT 'not_sent';

ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS pilot_session_external_id TEXT NOT NULL DEFAULT '';

ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS dispatched_to_pilot_at TIMESTAMPTZ NULL;
