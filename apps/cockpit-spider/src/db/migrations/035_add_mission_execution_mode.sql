ALTER TABLE missions
ADD COLUMN IF NOT EXISTS execution_mode TEXT NOT NULL DEFAULT 'manual';

ALTER TABLE missions
DROP CONSTRAINT IF EXISTS missions_execution_mode_check;

ALTER TABLE missions
ADD CONSTRAINT missions_execution_mode_check
CHECK (execution_mode IN ('manual', 'supervised_auto', 'autopilot'));
