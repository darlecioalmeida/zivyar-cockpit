ALTER TABLE workspace_panes
    ADD COLUMN IF NOT EXISTS session_agent_id INTEGER NULL REFERENCES agents(id) ON DELETE SET NULL;

ALTER TABLE workspace_panes
    ADD COLUMN IF NOT EXISTS session_agent_handle TEXT NOT NULL DEFAULT '';

ALTER TABLE workspace_panes
    ADD COLUMN IF NOT EXISTS context_state VARCHAR(60) NOT NULL DEFAULT 'unbound';

-- Sessões criadas antes desta migration não possuem snapshot confiável do agente.
-- Para evitar falso "contexto atual", marcamos como outdated e oferecemos recriação segura.
UPDATE workspace_panes
SET context_state = CASE
    WHEN session_external_id <> '' THEN 'outdated'
    ELSE 'unbound'
END
WHERE context_state = 'unbound';
