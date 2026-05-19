# ADR 0002 — Um runtime OpenCode por workspace

## Status
Aceita.

## Contexto
O cockpit deve suportar vários panes/agentes no mesmo workspace sem multiplicar excessivamente o consumo de memória.

## Decisão
Usar:

```text
1 workspace = 1 container Docker = 1 OpenCode Server
```

As funções Piloto, Planner, Scout, Builder, Reviewer e Executor serão sessões lógicas sob demanda dentro do mesmo servidor OpenCode do workspace.

## Motivos
- Menor consumo do que 6 processos independentes.
- Isolamento por workspace.
- Reaproveitamento de cache/configuração.
- Melhor gestão de ciclo de vida.

## Consequências
- Precisaremos de um serviço de sessão.
- O cockpit gerenciará criação, retomada e hibernação de sessões.
