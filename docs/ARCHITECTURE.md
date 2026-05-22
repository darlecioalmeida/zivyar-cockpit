# Arquitetura do Zivyar Cockpit

## 1. Visão geral

```text
Tauri Desktop
   ↓
Spider Local Backend
   ↓
PostgreSQL + Runtime Manager
   ↓
Docker Workspace Runtime
   ↓
OpenCode Server + Sessões
```

## 2. Blocos principais

### Tauri
- Janela desktop.
- Inicialização do backend local.
- Integração futura com diálogo de seleção de pasta, notificações e tray.

### Spider
- Rotas HTTP.
- SSR.
- WebSockets.
- Orquestração.
- CRUD de configuração.
- Mission Room.
- Context Engine.

### PostgreSQL
- Persistência de:
  - workspaces;
  - missões;
  - providers;
  - agentes;
  - squads;
  - eventos;
  - handoffs;
  - snapshots de contexto.

### Docker Runtime
- Isolamento por workspace.
- Um container por workspace.
- OpenCode Server iniciado dentro do runtime.
- Montagem do projeto local como volume.

## 3. Decisão de runtime

```text
1 workspace = 1 container = 1 opencode serve
```

No mesmo OpenCode Server, o Cockpit abrirá múltiplas sessões:
- Piloto;
- Planner;
- Scout;
- Builder;
- Reviewer;
- Executor.

## 4. Realtime

Canais WebSocket sugeridos:

```text
workspace:{id}
mission:{id}
pane:{id}
user:{id}
```

## 5. Context Orchestration

Camadas:
1. Global.
2. Workspace.
3. Mission.
4. Role.
5. Session.
6. Retrieval sob demanda.

## 6. Mission Engine

Ciclo:
1. Briefing.
2. Planejamento.
3. Mapeamento.
4. Execução.
5. Revisão.
6. Verificação.
7. Entrega.

## 7. Integrações planejadas

- Graphify → mapa de conhecimento do workspace, indexação de contexto e hub global de navegação.
- GSD → metodologia de execução, verificação e entrega por fase.
- UI UX Pro Max Skill → inteligência de design para o cockpit e seus estados.
- awesome-design-md → biblioteca de DESIGN.md para referências visuais e tokens.
- ECC → referência para skills, agentes, hooks, segurança e organização do harness.

Essas integrações entram como camadas de referência e padronização.
Elas não substituem a arquitetura do Zivyar Cockpit; apenas alimentam o
Context Engine, o Graphify e as decisões de UI/UX do projeto.

## 8. Riscos técnicos

- Streaming de terminal.
- Gestão de sessões OpenCode.
- Empacotamento Tauri + Spider.
- Compatibilidade Zig 0.17-dev.
- Consumo de recursos em múltiplos workspaces.
