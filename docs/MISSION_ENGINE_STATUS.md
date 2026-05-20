# Zivyar Cockpit — Mission Engine Status

## Estado atual

O Mission Engine já possui uma base operacional supervisionada para condução de missões multiagente dentro de um workspace.

O fluxo atual permite:

1. Criar missão vinculada a um workspace.
2. Herdar automaticamente a squad padrão do workspace.
3. Ativar missão como foco operacional do workspace.
4. Controlar o ciclo operacional por etapas.
5. Enviar missão ao Piloto.
6. Capturar o Briefing Operacional do Piloto.
7. Detectar a próxima etapa supervisionada.
8. Persistir diagnóstico de próxima etapa:
   - ação legível;
   - código técnico;
   - rota alvo;
   - data/hora da detecção.
9. Exibir diagnóstico na Mission Show e no Workspace.
10. Executar etapas supervisionadas reais de forma progressiva.

---

## Missão ativa validada

Workspace validado:

```text
Workspace ID: 3
Nome: Zivyar Cockpit 2
Runtime container: zivyar_workspace_3
OpenCode Server: http://127.0.0.1:43003
```

Missão validada:

```text
Mission ID: 2
Título: contruindo um arquivo de documentacao do projeto
Execution mode: supervised_auto
```

---

## Runtime

O runtime do workspace 3 foi iniciado com sucesso.

Estado validado:

```text
Container: zivyar_workspace_3
Imagem: zivyar-opencode-runtime:latest
Porta local: 43003
Estado Docker: running
```

O painel runtime foi corrigido para renderizar corretamente:

```html
data-workspace-id="3"
```

---

## Panes

A squad do workspace possui os seguintes panes:

```text
Piloto
Planner
Scout
Builder
Reviewer
Executor
```

O pane Piloto foi ativado com sucesso:

```text
Pane: Piloto
Estado: active
Contexto: current
Session: ses_1b85a2cdcffeZvp6YsQ2AYU8l7
```

Também foi corrigido o problema de rotas vazias nos cards dos panes.

Antes:

```html
data-workspace-id=""
action="/workspaces//panes/745/session/close"
action="/workspaces//panes/745/session/recreate"
```

Depois:

```html
data-workspace-id="3"
action="/workspaces/3/panes/745/session/close"
action="/workspaces/3/panes/745/session/recreate"
```

---

## Ciclo operacional atual

O ciclo validado até agora chegou até a captura do briefing do Piloto.

### Etapa 1 — Enviar missão ao Piloto

Status: validado.

Rota real executada:

```text
POST /workspaces/3/missions/2/dispatch/pilot
```

Resultado:

```text
HTTP/1.1 302 Found
Location: http://127.0.0.1:43003/Lw/session/ses_1b85a2cdcffeZvp6YsQ2AYU8l7
```

Banco validado:

```text
pilot_dispatch_status = sent
pilot_session_external_id = ses_1b85a2cdcffeZvp6YsQ2AYU8l7
dispatched_to_pilot_at = preenchido
```

---

### Etapa 2 — Capturar briefing do Piloto

Status: validado.

Rota real executada:

```text
POST /missions/2/capture/pilot-brief
```

Banco validado:

```text
pilot_operational_brief_status = captured
pilot_operational_brief_captured_at = preenchido
```

Após a captura, o diagnóstico supervisionado foi limpo corretamente:

```text
next_step_detected_action = vazio
next_step_detected_code = vazio
next_step_detected_route = vazio
```

---

## Próxima etapa esperada

Após a captura do briefing do Piloto, a próxima etapa do ciclo é:

```text
Ação: Enviar briefing ao Planner
Código técnico: dispatch_planner
Rota alvo: /workspaces/3/missions/2/dispatch/planner
```

A próxima evolução planejada é liberar execução supervisionada real para:

```text
dispatch_planner
capture_planner_plan
```

---

## Códigos técnicos de próxima etapa

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

---

## Campos de diagnóstico supervisionado

A tabela `missions` possui os campos:

```text
next_step_detected_action
next_step_detected_code
next_step_detected_route
next_step_detected_at
```

Uso:

- `next_step_detected_action`: texto legível da próxima etapa.
- `next_step_detected_code`: código técnico interno.
- `next_step_detected_route`: rota operacional alvo.
- `next_step_detected_at`: data/hora da detecção.

---

## Execution mode

A missão possui modo de execução:

```text
manual
supervised_auto
```

Estado atual validado:

```text
Mission ID 2: supervised_auto
```

Interpretação:

- `manual`: usuário opera as etapas diretamente.
- `supervised_auto`: o Cockpit detecta a próxima etapa e oferece execução supervisionada.

Até o momento, a automação é supervisionada, ou seja, o sistema prepara a ação e o usuário confirma.

---

## Proteções operacionais

Missões encerradas operacionalmente não podem:

- ser editadas;
- ser excluídas;
- ser reativadas;
- executar novas ações do ciclo;
- capturar novos reports;
- realizar novos dispatches.

Também há bloqueios para impedir avanço sem pré-condições, por exemplo:

```text
O pane Piloto precisa estar ativo para receber a missão.
```

---

## Sprints concluídas neste bloco

### 4.58 + 4.59

Persistência e exibição do diagnóstico de próxima etapa.

### 4.60 + 4.61

Exibição do diagnóstico no Workspace e limpeza do diagnóstico quando etapas reais avançam.

### 4.62 + 4.63

Persistência do código técnico da próxima etapa.

### 4.64 + 4.65

Persistência da rota alvo da próxima etapa.

### 4.66 + 4.67

Preparação e validação da execução supervisionada real para `dispatch_pilot`.

### 4.68 + 4.69

Correção das rotas dos panes com `workspace_id` e limpeza do diagnóstico após dispatch real.

### 4.70 + 4.71

Correção do `data-workspace-id` do painel Runtime e liberação supervisionada real para `capture_pilot_brief`.

---

## Próximas sprints sugeridas

### Sprint 4.72

Liberar execução supervisionada real para:

```text
dispatch_planner
```

### Sprint 4.73

Liberar execução supervisionada real para:

```text
capture_planner_plan
```

### Sprint 4.74

Melhorar o botão `Executar próxima etapa` para executar automaticamente a ação pronta quando o código já for suportado.

### Sprint 4.75

Adicionar histórico específico de execuções supervisionadas.
