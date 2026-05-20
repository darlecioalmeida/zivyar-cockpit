# Zivyar Cockpit

**Desktop Multi-Agent Engineering Cockpit**

Zivyar Cockpit é uma plataforma desktop-first para coordenar squads de agentes de desenvolvimento em múltiplos workspaces locais.

## Arquitetura escolhida

- **Desktop shell:** Tauri
- **Backend local:** Spider Framework em Zig
- **Runtime de agentes:** Docker + OpenCode Server por workspace
- **Banco local:** PostgreSQL em Docker
- **UI:** Spider Templates + HTMX + JavaScript pontual
- **Realtime:** WebSocket do Spider

## Conceito central

```text
1 Workspace
└── 1 Runtime Docker
    └── 1 OpenCode Server
        ├── Sessão Piloto
        ├── Sessão Planner
        ├── Sessão Scout
        ├── Sessão Builder
        ├── Sessão Reviewer
        └── Sessão Executor
```

## Objetivo da primeira fundação

Este repositório inicial prepara:

1. Monorepo.
2. App Spider.
3. Shell Tauri.
4. Infra PostgreSQL local.
5. Runtime Docker do OpenCode como base.
6. Documentação de arquitetura e roadmap.
7. Primeiras telas HTML de cockpit.

## Estrutura

```text
zivyar-cockpit/
├── apps/
│   ├── cockpit-spider/
│   └── desktop-tauri/
├── docs/
├── infra/
├── scripts/
├── DESIGN.md
└── README.md
```

## Requisitos de desenvolvimento

- Zig compatível com o Spider em uso.
- Docker Desktop ou Docker Engine.
- Node.js para o shell Tauri.
- Rust toolchain para Tauri.
- Git.

## Próximos passos sugeridos

1. Subir PostgreSQL local:
   ```bash
   docker compose -f infra/compose/docker-compose.local.yml up -d
   ```

2. Entrar no app Spider:
   ```bash
   cd apps/cockpit-spider
   ```

3. Adicionar a dependência Spider ao `build.zig.zon` via:
   ```bash
   zig fetch --save git+https://github.com/llllOllOOll/spider#main
   ```

4. Evoluir o scaffold para a primeira versão navegável:
   - dashboard;
   - workspaces;
   - missions;
   - agents;
   - squads;
   - providers.

## Estado do projeto

**Sprint 0 iniciada.**  
Esta base é um scaffold arquitetural consistente, ainda não é um app completo pronto para produção.


---

## Mission Engine — Estado atual

A documentação atual do Mission Engine está em:

```text
docs/MISSION_ENGINE_STATUS.md
docs/CURRENT_STATE.md
```

Resumo:

- Mission Engine em modo `supervised_auto`.
- Runtime Docker/OpenCode validado.
- Pane Piloto ativo.
- Dispatch ao Piloto validado.
- Captura do briefing do Piloto validada.
- Próxima etapa esperada: `dispatch_planner`.
