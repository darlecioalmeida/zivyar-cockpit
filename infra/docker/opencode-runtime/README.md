# OpenCode Runtime

Este diretório será a base do runtime Docker dos agentes.

## Papel
- Isolar o workspace.
- Executar OpenCode Server.
- Permitir sessões de agentes por workspace.
- Expor porta interna apenas para o Cockpit local.

## Próxima evolução
Na Sprint 2:
- instalar OpenCode;
- criar entrypoint;
- iniciar `opencode serve`;
- parametrizar workspace e porta;
- habilitar healthcheck.
