ALTER TABLE missions
    ADD COLUMN IF NOT EXISTS pilot_dispatch_user_message_id TEXT NOT NULL DEFAULT '';
