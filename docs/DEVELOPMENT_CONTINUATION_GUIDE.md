# Guia de Continuidade de Desenvolvimento — Zivyar Cockpit

Este documento orienta a continuidade do desenvolvimento do **Zivyar Cockpit** usando:

- VS Code + GitHub Copilot;
- OpenCode local;
- ou qualquer agente de IA conectado ao repositório.

O objetivo é permitir que o projeto continue sem perder o estado atual do Mission Engine, das sprints já validadas e das próximas etapas planejadas.

---

# 1. Contexto geral do projeto

O **Zivyar Cockpit** é uma aplicação local para orquestração de workspaces, runtimes Docker/OpenCode, panes multiagente e missões operacionais.

O sistema está sendo desenvolvido com:

```text
Backend: Zig + Spider
Banco: PostgreSQL
Runtime de agentes: Docker + OpenCode Server
Interface: templates HTML + CSS próprio
Versionamento: Git + GitHub
```

A aplicação principal fica em:

```text
apps/cockpit-spider
```

O comando de execução local é:

```bash
cd ~/projetos/zivyar-cockpit/apps/cockpit-spider
zig build run
```

---

# 2. Estado atual validado

O Mission Engine está funcional em modo supervisionado.

Estado validado:

```text
Workspace ID: 3
Workspace: Zivyar Cockpit 2
Runtime container: zivyar_workspace_3
OpenCode Server: http://127.0.0.1:43003
Mission ID: 2
Execution mode: supervised_auto
Pane Piloto: active/current
Session Piloto: ses_1b85a2cdcffeZvp6YsQ2AYU8l7
```

Etapas reais já validadas:

```text
1. dispatch_pilot
2. capture_pilot_brief
3. dispatch_planner
4. capture_planner_plan
```

A missão já foi enviada ao Piloto, o briefing do Piloto foi capturado e o fluxo do Planner já está consolidado no código.

Estado esperado no banco:

```text
pilot_dispatch_status = sent
pilot_operational_brief_status = captured
```

---

# 3. Documentos importantes

Antes de continuar, leia estes arquivos:

```text
docs/CURRENT_STATE.md
docs/MISSION_ENGINE_STATUS.md
docs/DEVELOPMENT_CONTINUATION_GUIDE.md
```

Esses arquivos registram:

- estado atual do projeto;
- sprints validadas;
- próximas sprints;
- regras de avanço seguro;
- campos do banco adicionados;
- rotas operacionais do Mission Engine.

---

# 4. Arquivos principais do sistema

## Backend principal

```text
apps/cockpit-spider/src/main.zig
```

Este arquivo contém:

- rotas;
- structs de formulário;
- structs de query;
- handlers dos workspaces;
- handlers das missões;
- handlers de dispatch;
- handlers de capture;
- lógica do Mission Engine;
- lógica de runtime;
- lógica de panes.

## Views de missão

```text
apps/cockpit-spider/src/features/missions/views/index.html
apps/cockpit-spider/src/features/missions/views/new.html
apps/cockpit-spider/src/features/missions/views/edit.html
apps/cockpit-spider/src/features/missions/views/show.html
```

## Views de workspace

```text
apps/cockpit-spider/src/features/workspaces/views/show.html
apps/cockpit-spider/src/features/workspaces/views/index.html
apps/cockpit-spider/src/features/workspaces/views/new.html
apps/cockpit-spider/src/features/workspaces/views/edit.html
```

## CSS principal

```text
apps/cockpit-spider/public/css/app.css
```

## Migrations recentes

```text
apps/cockpit-spider/src/db/migrations/036_add_mission_next_step_detection.sql
apps/cockpit-spider/src/db/migrations/037_add_mission_next_step_code.sql
apps/cockpit-spider/src/db/migrations/038_add_mission_next_step_route.sql
```

---

# 5. Regras atuais do Mission Engine

O Mission Engine segue um ciclo supervisionado.

Fluxo padrão:

```text
1. Detectar próxima etapa.
2. Persistir diagnóstico.
3. Exibir diagnóstico na Mission Show e no Workspace.
4. Exibir botão supervisionado.
5. Executar rota real após confirmação do usuário.
6. Validar no banco.
7. Limpar diagnóstico antigo.
8. Avançar para a próxima etapa.
```

Etapas já cobertas no código:

```text
dispatch_pilot
capture_pilot_brief
dispatch_planner
capture_planner_plan
dispatch_scout
capture_scout_report
dispatch_builder
capture_builder_report
dispatch_reviewer
capture_reviewer_report
dispatch_executor
capture_executor_report
dispatch_pilot_delivery
capture_pilot_delivery_report
finalize_mission
```

A automação ainda não é totalmente autônoma.

O modo atual é:

```text
supervised_auto
```

Ou seja:

- o sistema detecta a próxima etapa;
- prepara a ação;
- mostra a rota/diagnóstico;
- o usuário confirma;
- então a rota real é executada.

---

# 6. Campos de diagnóstico de próxima etapa

A tabela `missions` possui:

```text
next_step_detected_action
next_step_detected_code
next_step_detected_route
next_step_detected_at
```

Uso:

```text
next_step_detected_action = texto legível da próxima ação
next_step_detected_code   = código técnico interno
next_step_detected_route  = rota HTTP real que será chamada
next_step_detected_at     = data/hora da detecção
```

Exemplo:

```text
next_step_detected_action = Enviar briefing ao Planner
next_step_detected_code   = dispatch_planner
next_step_detected_route  = /workspaces/3/missions/2/dispatch/planner
```

---

# 7. Códigos técnicos do ciclo operacional

Lista completa prevista:

```text
dispatch_pilot
capture_pilot_brief
dispatch_planner
capture_planner_plan
dispatch_scout
capture_scout_report
dispatch_builder
capture_builder_report
dispatch_reviewer
capture_reviewer_report
dispatch_executor
capture_executor_report
dispatch_pilot_delivery
capture_pilot_delivery_report
finalize_mission
```

Já validados com execução real supervisionada:

```text
dispatch_pilot
capture_pilot_brief
```

Próximos a implementar:

```text
dispatch_planner
capture_planner_plan
```

---

# 8. Rotas operacionais do Mission Engine

Rotas de dispatch:

```text
POST /workspaces/:id/missions/:mission_id/dispatch/pilot
POST /workspaces/:id/missions/:mission_id/dispatch/planner
POST /workspaces/:id/missions/:mission_id/dispatch/scout
POST /workspaces/:id/missions/:mission_id/dispatch/builder
POST /workspaces/:id/missions/:mission_id/dispatch/reviewer
POST /workspaces/:id/missions/:mission_id/dispatch/executor
POST /workspaces/:id/missions/:mission_id/dispatch/pilot-delivery
```

Rotas de capture:

```text
POST /missions/:id/capture/pilot-brief
POST /missions/:id/capture/planner-plan
POST /missions/:id/capture/scout-report
POST /missions/:id/capture/builder-report
POST /missions/:id/capture/reviewer-report
POST /missions/:id/capture/executor-report
POST /missions/:id/capture/pilot-delivery-report
```

Rota de fechamento:

```text
POST /missions/:id/finalize
```

Rota de detecção da próxima etapa:

```text
POST /missions/:id/next-step
```

---

# 9. Proteções operacionais

Missões encerradas operacionalmente não podem:

- ser editadas;
- ser excluídas;
- ser reativadas;
- executar novas ações do ciclo;
- capturar novos reports;
- realizar novos dispatches.

Também existem bloqueios por pré-condição.

Exemplo validado:

```text
O pane Piloto precisa estar ativo para receber a missão.
```

Antes de executar dispatch para qualquer agente, o pane correspondente deve estar:

```text
pane_state = active
context_state = current
session_external_id preenchido
```

---

# 10. Como continuar usando VS Code + Copilot

## 10.1 Abrir o projeto

No terminal:

```bash
cd ~/projetos/zivyar-cockpit
code .
```

## 10.2 Instrução inicial para o Copilot Chat

Use este prompt no Copilot Chat:

```text
Leia os arquivos docs/CURRENT_STATE.md, docs/MISSION_ENGINE_STATUS.md e docs/DEVELOPMENT_CONTINUATION_GUIDE.md.

Contexto:
Estamos desenvolvendo o Zivyar Cockpit, uma aplicação Zig + Spider com PostgreSQL e runtime Docker/OpenCode.

O Mission Engine está em modo supervised_auto.
As etapas dispatch_pilot e capture_pilot_brief já foram validadas.
A próxima evolução deve implementar dispatch_planner e capture_planner_plan no mesmo padrão seguro.

Antes de alterar qualquer arquivo:
1. Localize os handlers existentes no apps/cockpit-spider/src/main.zig.
2. Verifique como dispatch_pilot e capture_pilot_brief foram implementados.
3. Não remova proteções de missão encerrada.
4. Não duplique lógica desnecessariamente.
5. Preserve o padrão atual de diagnóstico:
   - next_step_detected_action
   - next_step_detected_code
   - next_step_detected_route
   - next_step_detected_at
6. Mantenha execução supervisionada, não totalmente automática.
```

## 10.3 Prompt para pedir patch ao Copilot

```text
Gere um patch incremental para as próximas sprints:

Sprint 4.72:
Liberar execução supervisionada real para dispatch_planner.

Sprint 4.73:
Liberar execução supervisionada real para capture_planner_plan.

Regras:
- Seguir o mesmo padrão já usado em dispatch_pilot e capture_pilot_brief.
- O botão /missions/:id/next-step deve redirecionar com next_step_ready=dispatch_planner quando a próxima ação for dispatch_planner.
- A Mission Show deve exibir painel de execução supervisionada para dispatch_planner.
- O Workspace Show deve exibir painel de execução supervisionada para dispatch_planner.
- Depois implementar o mesmo para capture_planner_plan.
- Não quebrar as etapas anteriores.
- Não remover validações.
- Ao executar uma rota real com sucesso, limpar:
  next_step_detected_action
  next_step_detected_code
  next_step_detected_route
  next_step_detected_at
```

---

# 11. Como continuar usando OpenCode

## 11.1 Entrar no projeto

```bash
cd ~/projetos/zivyar-cockpit
```

## 11.2 Abrir o OpenCode no workspace

Se estiver usando o runtime do Cockpit, abra a sessão pelo navegador:

```text
http://127.0.0.1:43003/Lw/session/ses_1b85a2cdcffeZvp6YsQ2AYU8l7
```

Ou use o OpenCode direto se estiver configurado no terminal.

## 11.3 Prompt inicial para o OpenCode

```text
Você está trabalhando no projeto Zivyar Cockpit.

Leia primeiro:
- docs/CURRENT_STATE.md
- docs/MISSION_ENGINE_STATUS.md
- docs/DEVELOPMENT_CONTINUATION_GUIDE.md

Estado atual:
- Mission Engine em modo supervised_auto.
- dispatch_pilot validado.
- capture_pilot_brief validado.
- Próxima etapa técnica: dispatch_planner.
- Próxima rota esperada: POST /workspaces/3/missions/2/dispatch/planner.

Objetivo:
Continuar o desenvolvimento de forma incremental e segura, implementando Sprint 4.72 + 4.73.

Regras:
- Não remover proteções de missão encerrada.
- Não transformar em automação total ainda.
- Manter confirmação supervisionada.
- Seguir o padrão já usado para dispatch_pilot e capture_pilot_brief.
- Gerar patch pequeno e validável.
```

---

# 12. Próximas sprints recomendadas

## Sprint 4.72 — dispatch_planner supervisionado

Objetivo:

```text
Permitir que /missions/:id/next-step marque dispatch_planner como pronto para execução supervisionada.
```

Resultado esperado:

```text
Location: /missions/2?next_step_ready=dispatch_planner
```

A Mission Show e o Workspace Show devem exibir botão:

```text
Enviar briefing ao Planner agora
```

Esse botão deve chamar:

```text
POST /workspaces/3/missions/2/dispatch/planner
```

## Sprint 4.73 — capture_planner_plan supervisionado

Objetivo:

```text
Permitir captura supervisionada real do plano operacional do Planner.
```

Resultado esperado:

```text
POST /missions/2/capture/planner-plan
```

Banco esperado após sucesso:

```text
planner_operational_plan_status = captured
planner_operational_plan_captured_at = preenchido
```

---

# 13. Comandos de validação úteis

## Rodar aplicação

```bash
cd ~/projetos/zivyar-cockpit/apps/cockpit-spider
zig build run
```

## Ver runtime Docker

```bash
docker ps | grep zivyar_workspace_3
```

## Ver missão atual

```bash
docker exec -it zivyar_cockpit_postgres \
  psql -U zivyar -d zivyar_cockpit \
  -c "
SELECT
  id,
  title,
  execution_mode,
  pilot_dispatch_status,
  pilot_operational_brief_status,
  planner_dispatch_status,
  planner_operational_plan_status,
  next_step_detected_action,
  next_step_detected_code,
  next_step_detected_route,
  next_step_detected_at
FROM missions
WHERE id = 2;
"
```

## Detectar próxima etapa

```bash
curl -i -X POST \
  -H 'Content-Length: 0' \
  http://127.0.0.1:3000/missions/2/next-step
```

## Testar dispatch ao Planner

```bash
curl -i -X POST \
  -H 'Content-Length: 0' \
  http://127.0.0.1:3000/workspaces/3/missions/2/dispatch/planner
```

## Testar captura do plano do Planner

```bash
curl -i -X POST \
  -H 'Content-Length: 0' \
  http://127.0.0.1:3000/missions/2/capture/planner-plan
```

---

# 14. Padrão de commit

Depois de cada sprint validada:

```bash
cd ~/projetos/zivyar-cockpit

git status

git add .
git commit -m "feat: prepare supervised planner mission steps"

git push origin main

git status
```

Para correções:

```bash
git commit -m "fix: correct supervised mission step state"
```

Para documentação:

```bash
git commit -m "docs: update mission engine continuation guide"
```

---

# 15. Cuidados importantes

1. Sempre validar no banco depois de executar uma etapa real.
2. Não avançar para a próxima etapa sem confirmar que o status anterior mudou.
3. Não chamar dispatch se o pane correspondente não estiver ativo.
4. Não chamar capture se não existir rastreio do dispatch anterior.
5. Não remover validações de missão encerrada.
6. Não limpar diagnóstico antes da rota real ser executada com sucesso.
7. Não misturar duas grandes mudanças no mesmo patch sem validação intermediária.

---

# 16. Estado final deste documento

Este guia foi gerado para permitir continuidade do desenvolvimento sem depender do histórico completo da conversa.

O próximo desenvolvimento recomendado é:

```text
Sprint 4.72 + 4.73
Implementar dispatch_planner e capture_planner_plan em modo supervised_auto.
```
