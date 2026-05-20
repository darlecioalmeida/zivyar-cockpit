ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS pilot_delivery_report TEXT NOT NULL DEFAULT '';

ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS pilot_delivery_report_status VARCHAR(60) NOT NULL DEFAULT 'not_captured';

ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS pilot_delivery_report_captured_at TIMESTAMPTZ NULL;
