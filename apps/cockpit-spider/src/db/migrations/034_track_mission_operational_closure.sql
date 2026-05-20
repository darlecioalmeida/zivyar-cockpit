ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS mission_final_verdict VARCHAR(60) NOT NULL DEFAULT 'not_finalized';

ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS mission_operational_closure_status VARCHAR(60) NOT NULL DEFAULT 'open';

ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS mission_operational_closed_at TIMESTAMPTZ NULL;
