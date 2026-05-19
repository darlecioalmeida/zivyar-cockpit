# Zivyar OpenCode Runtime

Imagem Docker própria do Zivyar Cockpit, construída como uma camada fina sobre a imagem oficial do OpenCode.

## Responsabilidades

- 1 container por workspace.
- Montagem da pasta local do projeto em /workspace.
- Inicialização automática do OpenCode Server.
- Porta interna padrão: 4096.
- Healthcheck feito pelo Zivyar via /global/health.

## Base da imagem

    ghcr.io/anomalyco/opencode:latest

## Comando executado

    opencode serve --hostname 0.0.0.0 --port 4096

## Tag gerenciada pelo Cockpit

    zivyar-opencode-runtime:latest
