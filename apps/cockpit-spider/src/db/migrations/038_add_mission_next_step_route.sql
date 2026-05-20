ALTER TABLE missions
ADD COLUMN IF NOT EXISTS next_step_detected_route TEXT NOT NULL DEFAULT '';
