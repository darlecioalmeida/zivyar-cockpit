#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
COMPOSE_FILE="$REPO_ROOT/infra/compose/docker-compose.local.yml"
CONTAINER_NAME="zivyar_cockpit_postgres"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker não encontrado. Instale Docker Desktop ou Docker Engine para subir o Postgres local." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  if [ "$(uname -s)" = "Darwin" ] && [ -d "/Applications/Docker.app" ]; then
    echo "Docker não está ativo. Abrindo Docker Desktop..."
    open -a Docker >/dev/null 2>&1 || true
  else
    echo "Docker não está ativo. Inicie o Docker e execute o comando novamente." >&2
    exit 1
  fi

  attempts=0
  while ! docker info >/dev/null 2>&1; do
    attempts=$((attempts + 1))

    if [ "$attempts" -ge 60 ]; then
      echo "Docker não ficou pronto a tempo. Abra o Docker Desktop e tente novamente." >&2
      exit 1
    fi

    sleep 2
  done
fi

docker compose -f "$COMPOSE_FILE" up -d postgres

attempts=0
while [ "$(docker inspect -f '{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo starting)" != "healthy" ]; do
  attempts=$((attempts + 1))

  if [ "$attempts" -ge 60 ]; then
    echo "Postgres local não ficou healthy a tempo." >&2
    docker compose -f "$COMPOSE_FILE" ps postgres >&2 || true
    exit 1
  fi

  sleep 1
done

echo "Postgres local pronto em 127.0.0.1:55432."
