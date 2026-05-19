# Base inicial do runtime de agentes.
# Evoluiremos este Dockerfile na Sprint 2 para instalar e inicializar o OpenCode Server.

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /workspace

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    git \
    jq \
    bash \
    unzip \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Usuário não-root
RUN useradd -m -u 10001 agent
USER agent

CMD ["bash", "-lc", "sleep infinity"]
