# Estado Atual — Zivyar Cockpit

## Resumo executivo

O Zivyar Cockpit está com o Mission Engine funcional em modo supervisionado.

A aplicação já consegue criar missões, vincular missões a workspaces, ativar uma missão no Cockpit, iniciar runtime Docker/OpenCode, abrir sessão do pane Piloto, enviar a missão ao Piloto e capturar o briefing retornado.

O sistema também já calcula e persiste a próxima etapa operacional com:

```text
ação legível
código técnico
rota alvo
timestamp
```

---

## Estado validado em produção local

```text
Workspace: 3
Container: zivyar_workspace_3
OpenCode Server: http://127.0.0.1:43003
Missão ativa: 2
Modo da missão: supervised_auto
Pane Piloto: active/current
Sessão Piloto: ses_1b85a2cdcffeZvp6YsQ2AYU8l7
```

---

## Última etapa validada

```text
pilot_operational_brief_status = captured
```

Isso significa que o briefing do Piloto já foi capturado e persistido.

---

## Próxima etapa técnica

```text
dispatch_planner
```

Rota esperada:

```text
POST /workspaces/3/missions/2/dispatch/planner
```

---

## Arquivos principais alterados recentemente

```text
apps/cockpit-spider/src/main.zig
apps/cockpit-spider/src/features/missions/views/show.html
apps/cockpit-spider/src/features/workspaces/views/show.html
apps/cockpit-spider/public/css/app.css
apps/cockpit-spider/src/db/migrations/036_add_mission_next_step_detection.sql
apps/cockpit-spider/src/db/migrations/037_add_mission_next_step_code.sql
apps/cockpit-spider/src/db/migrations/038_add_mission_next_step_route.sql
```

---

## Migrations recentes

### 036

Adiciona:

```text
next_step_detected_action
next_step_detected_at
```

### 037

Adiciona:

```text
next_step_detected_code
```

### 038

Adiciona:

```text
next_step_detected_route
```

---

## Critério atual de avanço

O sistema está sendo evoluído de forma incremental e seguro.

Cada etapa segue este padrão:

1. Detectar próxima etapa.
2. Persistir diagnóstico.
3. Exibir diagnóstico.
4. Exibir botão supervisionado.
5. Executar rota real.
6. Validar no banco.
7. Limpar diagnóstico antigo.
8. Avançar para a próxima etapa.

---

## Próximo bloco de desenvolvimento

Próximo bloco recomendado:

```text
Sprint 4.72 + 4.73
```

Objetivo:

```text
Liberar execução supervisionada real para Planner.
```

Escopo:

```text
dispatch_planner
capture_planner_plan
```
