#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly repository_root="$(cd -- "$script_dir/../.." && pwd)"
readonly environment_file="$repository_root/.env"
readonly compose_project="${PERFORMANCE_COMPOSE_PROJECT_NAME:-inventory-performance-local}"
readonly k6_image="${K6_IMAGE:-grafana/k6:0.57.0@sha256:70af91f86cd8e142e0544a4edaf79835a80033f71974b92edd5ac36fd4442a7b}"

source "$repository_root/scripts/testing/local_compose.sh"

cleanup() {
  local_compose "$repository_root" "$environment_file" "$compose_project" \
    down -v --remove-orphans
}

trap cleanup EXIT

command -v awk >/dev/null
command -v curl >/dev/null
command -v docker >/dev/null
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

viewer_password="$(
  read_environment_value E2E_VIEWER_PASSWORD
)"
backend_port="$(read_environment_value BACKEND_PORT)"
keycloak_port="$(read_environment_value KEYCLOAK_PORT)"
test -n "$viewer_password"
test -n "$backend_port"
test -n "$keycloak_port"

reset_test_result_directory "$repository_root" test-results/performance/k6

local_compose "$repository_root" "$environment_file" "$compose_project" \
  up --build --wait --wait-timeout 240 -d

wait_for_http_endpoint backend "http://localhost:$backend_port/actuator/health" 120
wait_for_http_endpoint \
  keycloak \
  "http://localhost:$keycloak_port/realms/inventory/.well-known/openid-configuration" \
  120

set +e
docker run --rm --network host \
  --user "$(id -u):$(id -g)" \
  --volume "$repository_root:/work" \
  --workdir /work \
  --env BASE_URL="http://localhost:$backend_port" \
  --env KEYCLOAK_URL="http://localhost:$keycloak_port" \
  --env KEYCLOAK_REALM=inventory \
  --env KEYCLOAK_CLIENT_ID=inventory-frontend \
  --env K6_USERNAME=viewer \
  --env K6_PASSWORD="$viewer_password" \
  --env K6_PROFILE="${K6_PROFILE:-smoke}" \
  --env K6_RESULTS_DIR=/work/test-results/performance/k6 \
  "$k6_image" \
  run tests/performance/performance.js
test_exit_code=$?
set -e

status=failed
[[ "$test_exit_code" -eq 0 ]] && status=passed
python3 "$repository_root/scripts/testing/collect_test_results.py" \
  --suite performance/k6 \
  --status "$status" \
  --output-root "$repository_root/test-results" \
  --metadata workflow=local \
  --metadata nativeSummary=k6-summary.json

exit "$test_exit_code"
