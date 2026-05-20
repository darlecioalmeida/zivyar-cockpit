ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS pilot_operational_brief TEXT NOT NULL DEFAULT '';

ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS pilot_operational_brief_status VARCHAR(60) NOT NULL DEFAULT 'not_captured';

ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS pilot_operational_brief_captured_at TIMESTAMPTZ NULL;
