# Copilot Instructions — Zivyar Cockpit

## Context

This repository contains the Zivyar Cockpit app stack, with the main backend in `apps/cockpit-spider`.

## Working Rules

- Prefer small, incremental changes.
- Preserve mission closure protections.
- Keep the Mission Engine in supervised execution unless the task explicitly asks for a broader mode change.
- When touching Zig code, prefer the current Spider/Zig APIs documented in `docs/reference/SKILL_ZIG_016_APIS.md`.
- Before editing mission flow, inspect `apps/cockpit-spider/src/main.zig` and the mission status docs in `docs/`.
- Do not remove validation gates unless the task explicitly requires it.

## Reference Docs

- `docs/reference/SKILL.md`
- `docs/reference/SKILL_ZIG_016_APIS.md`

## Formatting

- Keep changes focused and easy to validate.
- Prefer the existing project style over introducing new patterns.