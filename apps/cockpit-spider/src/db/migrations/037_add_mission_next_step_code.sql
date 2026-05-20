ALTER TABLE missions
ADD COLUMN IF NOT EXISTS next_step_detected_code TEXT NOT NULL DEFAULT '';
