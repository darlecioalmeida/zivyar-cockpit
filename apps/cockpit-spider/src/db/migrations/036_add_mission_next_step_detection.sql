ALTER TABLE missions
ADD COLUMN IF NOT EXISTS next_step_detected_action TEXT NOT NULL DEFAULT '';

ALTER TABLE missions
ADD COLUMN IF NOT EXISTS next_step_detected_at TIMESTAMPTZ;
