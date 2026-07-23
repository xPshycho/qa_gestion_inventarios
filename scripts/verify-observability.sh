#!/usr/bin/env bash
set -Eeuo pipefail

readonly COMPOSE=(docker compose)

require_healthy() {
  local readonly_url="$1"
  local readonly_name="$2"
  printf 'Checking %s...\n' "$name"
  curl --fail --silent --show-error --retry 12 --retry-delay 2 "$url" >/dev/null
}

main() {
  "${COMPOSE[@]}" ps
  require_healthy "http://localhost:${PROMETHEUS_PORT:-9090}/-/ready" "Prometheus"
  require_healthy "http://localhost:${GRAFANA_PORT:-3000}/api/health" "Grafana"
  require_healthy "http://localhost:${LOKI_PORT:-3100}/ready" "Loki"
  require_healthy "http://localhost:${TEMPO_PORT:-3200}/ready" "Tempo"
  require_healthy "http://localhost:${ALERTMANAGER_PORT:-9093}/-/ready" "Alertmanager"
  curl --fail --silent --show-error "http://localhost:${PROMETHEUS_PORT:-9090}/api/v1/query?query=up" >/dev/null
  printf 'Observability stack is reachable. Generate backend traffic, then verify traces and logs in Grafana Explore.\n'
}

main "$@"
