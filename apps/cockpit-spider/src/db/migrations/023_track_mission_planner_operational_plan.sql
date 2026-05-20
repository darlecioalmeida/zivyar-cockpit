ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS planner_operational_plan TEXT NOT NULL DEFAULT '';

ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS planner_operational_plan_status VARCHAR(60) NOT NULL DEFAULT 'not_captured';

ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS planner_operational_plan_captured_at TIMESTAMPTZ NULL;
