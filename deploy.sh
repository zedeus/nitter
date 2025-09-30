#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-./docker-compose.yml}"
NETWORK_NAME="${NETWORK_NAME:-nitter_net}"
PORT="${PORT:-8080}"

# docker compose wrapper
compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose -f "$COMPOSE_FILE" "$@"
  else
    docker-compose -f "$COMPOSE_FILE" "$@"
  fi
}

MODE="${1:-}"
CMD="${2:-}"

case "$MODE" in
  Latest|Top)
    if [ "$CMD" != "up" ]; then
      echo "Usage: $0 {Latest|Top} up"
      exit 1
    fi
    # Update nitter.conf with the selected mode
    sed -i "s/^searchMode = \".*\"/searchMode = \"$MODE\"/" nitter.conf

    docker network inspect "$NETWORK_NAME" >/dev/null 2>&1 || docker network create "$NETWORK_NAME" || true
    compose build
    compose up -d
    echo "Nitter Running → http://localhost:${PORT} (Mode: $MODE)"
    ;;
  down)
    compose down --remove-orphans
    docker system prune -f
    echo "Nitter Stopped"
    ;;
  *)
    echo "Usage: $0 {Latest|Top} up"
    echo "       $0 down"
    exit 1
    ;;
esac