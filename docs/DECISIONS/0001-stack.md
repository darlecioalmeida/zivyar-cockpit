# ADR 0001 — Stack principal do Zivyar Cockpit

## Status
Aceita.

## Contexto
Precisamos de um produto desktop-first, com backend local eficiente, interface em panes e runtime isolado para agentes de programação.

## Decisão
Adotar:
- Tauri para empacotamento desktop.
- Spider Framework em Zig para backend local.
- PostgreSQL local em Docker.
- Docker + OpenCode Server por workspace.
- Templates Spider + HTMX + JS pontual.

## Consequências positivas
- App leve.
- Arquitetura clara.
- Realtime nativo via WebSocket.
- Boa separação entre UI, backend e runtime.
- Isolamento de workspaces.

## Consequências negativas
- Dependência de ecossistema Zig/Spider em evolução.
- Integração Tauri + backend local precisa de empacotamento cuidadoso.
- Runtime Docker exige verificação de ambiente do usuário.
