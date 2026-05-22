# SESSION CONTEXT — Zivyar Cockpit

## Project Overview

Zivyar Cockpit is a Zig (0.17.0-dev) web application using Spider Framework + PostgreSQL (port 55432) + Docker. It manages AI-agent squads executing missions via OpenCode Server sessions across 7 roles.

## Architecture: MVC by Feature

```
apps/cockpit-spider/src/
├── main.zig                  # 209 lines: imports + aliases + 88+ route registrations
├── features/
│   ├── mod.zig               # Barrel: re-exports all feature controllers
│   ├── dashboard/            # Single dashboard_controller.zig + views/
│   ├── agents/               # CRUD for agents (controller + model + repository + views/)
│   ├── squads/               # CRUD for squads
│   ├── providers/            # CRUD for providers + provider models
│   ├── stacks/               # CRUD for stacks
│   ├── graphify/             # Graph visualization
│   ├── workspaces/           # Workspace CRUD + runtime lifecycle + context panels
│   └── missions/             # Mission CRUD + dispatch + capture + autopilot
│       ├── mod.zig           # Barrel: re-exports model, repository, controller, dispatch, capture
│       ├── mission_model.zig  # Structs: MissionRow (56 fields), forms, trace rows, etc.
│       ├── mission_repository.zig  # SQL queries, mission_select_fields macro (56 cols)
│       ├── mission_controller.zig  # CRUD + runNextStep + finalize
│       ├── mission_dispatch_controller.zig  # 7 dispatch handlers (Pilot→Planner→…→PilotDelivery)
│       └── mission_capture_controller.zig  # 7 capture handlers (PilotBrief→…→PilotDeliveryReport)
└── shared/helpers.zig        # Utility functions (OpenCode message parsing, etc.)
```

## 7-Step Mission Cycle (Pipeline)

Piloto → Planner → Scout → Builder → Reviewer → Executor → Piloto (delivery) → Finalize

Each step has: dispatch (send prompt to agent) + capture (retrieve agent's response).

## Current State (this session)

### CRITICAL BUG FIXED: /missions 500 error (56-column query)

**Root cause**: The `++` operator for SQL string concatenation in `mission_repository.zig` produced invalid SQL. `\\SELECT ++ mission_select_fields ++ mission_from_join ++ \\ORDER BY ...` generated a malformed query that PostgreSQL rejected with `42601: syntax error at or near "missions"`.

**Fix**: Replaced all `++` concatenation with `std.fmt.allocPrint`:
- `listMissions` 
- `getActiveMissionForWorkspace`
- `getMissionById` (refactored from 70 lines of duplicated inline SQL)

**What we proved**: The error was NOT about:
  - Column count exceeding `result_state_size=32` (works fine with 56 columns)
  - A specific problematic column/expression type
  - PG driver memory management
  - NULL values in specific columns

It was purely a SQL string construction issue.

### GET routes verified working (all return HTTP 200)
- `/missions` (list, 4 rows, 56 columns)
- `/missions/1` through `/missions/4` (individual shows)

### PRE-EXISTING BUG: POST requests crash (SIGABRT)
Confirmed as a Spider framework threading bug:
- Stack: `app.zig:353` → `request.respond()` → `Io/Threaded.zig` → `_pthread_cond_broadcast`
- Affects ALL POST requests (not specific to our code)
- Pre-existing issue from before the refactoring
- Cannot be fixed at application level — needs Spider framework fix

### DONE (This session — continued from previous)

#### SQL concatenation fix
- Replaced `++` with `std.fmt.allocPrint` in all mission repository queries
- `getMissionById` now uses shared `mission_select_fields` and `mission_from_join` constants
- Removed 70 lines of duplicated inline SQL from `getMissionById`
- Added PG server error logging to `pg.zig`'s `execTyped` (logs actual PG error code + message)

### REMAINING / BLOCKED

#### POST routes (activate, dispatch, capture, create, update, delete)
All blocked by Spider framework threading crash. Requires Spider framework fix or workaround.

#### Autopilot E2E validation
Cannot proceed until POST crash is resolved (activate + dispatch + capture all use POST).

## Key Design Decisions

- **Autopilot chain**: Uses HTTP redirects between handlers (not polling/middleware). Each handler ends with redirect to `/missions/{id}/next-step`.
- **Capture polling**: All 7 capture handlers now use up to 8 attempts × 200ms sleep when agent hasn't responded yet. This makes autopilot more reliable.
- **`workspaceMissionActivate`**: Deduplicated — moved from workspace_controller to `missions_dispatch_controller.activate` (with proper validation + event logging).
- **3 execution modes**: `manual`, `supervised_auto`, `autopilot`
- **Spider PG driver**: Maps by position, not by name — struct field order must match SELECT column order exactly.

## Relevant Files

| File | Purpose |
|------|---------|
| `apps/cockpit-spider/src/main.zig` | 209 lines, imports + aliases + route registration |
| `apps/cockpit-spider/build.zig` | Build config with core_mod |
| `apps/cockpit-spider/src/features/mod.zig` | Barrel for all features |
| `apps/cockpit-spider/src/features/missions/mod.zig` | Barrel for mission submodules |
| `apps/cockpit-spider/src/features/missions/mission_model.zig` | MissionRow (56 fields), forms, trace structs |
| `apps/cockpit-spider/src/features/missions/mission_repository.zig` | SQL queries, mission_select_fields macro (56 cols) |
| `apps/cockpit-spider/src/features/missions/mission_controller.zig` | CRUD + runNextStep + finalize |
| `apps/cockpit-spider/src/features/missions/mission_dispatch_controller.zig` | 7 dispatch handlers + activate |
| `apps/cockpit-spider/src/features/missions/mission_capture_controller.zig` | 7 capture handlers |
| `apps/cockpit-spider/src/features/missions/views/show.html` | Mission show view with autopilot UI |
| `apps/cockpit-spider/src/features/workspaces/workspace_controller.zig` | workspaceMissionActivate (duplicated) |
| `apps/cockpit-spider/src/shared/helpers.zig` | Utility functions |

## Environment

- Zig 0.17.0-dev
- Spider Framework
- PostgreSQL (localhost:55432, db: zivyar_cockpit, user/pass: zivyar/zivyar_dev_password)
- Docker (for workspace runtimes)
- OpenCode Server (runs in Docker containers, port 43000+workspace_id)
- DB migrations 035-038 applied (next_step_detected_*, execution_mode columns exist)
