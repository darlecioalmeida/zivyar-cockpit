ALTER TABLE workspaces
ADD COLUMN IF NOT EXISTS default_squad_id INTEGER NULL REFERENCES squads(id) ON DELETE SET NULL;

UPDATE workspaces w
SET default_squad_id = s.id
FROM squads s
WHERE w.default_squad_id IS NULL
  AND w.default_squad = s.name;
