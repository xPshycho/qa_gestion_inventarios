#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly repository_root="$(cd -- "$script_dir/../.." && pwd)"
readonly environment_file="$repository_root/.env"
readonly compose_project="${SECURITY_COMPOSE_PROJECT_NAME:-inventory-security-local}"
failed=0

source "$repository_root/scripts/testing/local_compose.sh"

cleanup() {
  local_compose "$repository_root" "$environment_file" "$compose_project" \
    down -v --remove-orphans
}

trap cleanup EXIT

command -v curl >/dev/null
command -v docker >/dev/null
command -v jq >/dev/null
docker version >/dev/null
docker compose version >/dev/null

"$repository_root/scripts/security/init-secret-env.sh" local
read_environment_value() {
  local key="$1"
  awk -F= -v key="$key" '
    $1 == key {
      sub(/^[^=]*=/, "")
      print
      exit
    }
  ' "$environment_file"
}

frontend_port="$(read_environment_value FRONTEND_PORT)"
keycloak_port="$(read_environment_value KEYCLOAK_PORT)"
test -n "$frontend_port"
test -n "$keycloak_port"

reset_test_result_directory "$repository_root" test-results/security/headers
reset_test_result_directory "$repository_root" test-results/security/zap

local_compose "$repository_root" "$environment_file" "$compose_project" \
  up --build --wait --wait-timeout 240 -d

wait_for_http_endpoint frontend "http://localhost:$frontend_port/" 120
wait_for_http_endpoint \
  keycloak \
  "http://localhost:$keycloak_port/realms/inventory/.well-known/openid-configuration" \
  120

set +e
FRONTEND_URL="http://localhost:$frontend_port" \
KEYCLOAK_PUBLIC_URL="http://localhost:$keycloak_port" \
SECURITY_HEADERS_REPORT_FILE="$repository_root/test-results/security/headers/evidence/headers.txt" \
  "$script_dir/verify-headers.sh"
headers_exit_code=$?
ZAP_TARGET_URL="http://localhost:$frontend_port" \
ZAP_DOCKER_NETWORK=host \
ZAP_REPORT_DIR="$repository_root/test-results/security/zap/evidence/reports" \
  "$script_dir/run-zap-baseline.sh"
zap_exit_code=$?
set -e

headers_status=failed
[[ "$headers_exit_code" -eq 0 ]] && headers_status=passed
python3 "$repository_root/scripts/testing/collect_test_results.py" \
  --suite security/headers \
  --status "$headers_status" \
  --output-root "$repository_root/test-results" \
  --metadata workflow=local

zap_status=failed
[[ "$zap_exit_code" -eq 0 ]] && zap_status=passed
python3 "$repository_root/scripts/testing/collect_test_results.py" \
  --suite security/zap \
  --status "$zap_status" \
  --output-root "$repository_root/test-results" \
  --metadata workflow=local \
  --metadata format=zap-json-markdown

[[ "$headers_exit_code" -eq 0 ]] || failed=1
[[ "$zap_exit_code" -eq 0 ]] || failed=1
exit "$failed"
