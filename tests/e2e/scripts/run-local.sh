#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly repository_root="$(cd -- "$script_dir/../../.." && pwd)"
readonly e2e_directory="$repository_root/tests/e2e"
readonly environment_file="$repository_root/.env"
readonly playwright_image="${PLAYWRIGHT_IMAGE:-mcr.microsoft.com/playwright:v1.60.0-noble}"
readonly compose_project="${E2E_COMPOSE_PROJECT_NAME:-inventory-e2e-local}"
readonly keep_stack="${E2E_KEEP_STACK:-false}"

source "$repository_root/scripts/testing/local_compose.sh"

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

cleanup() {
  if [[ "$keep_stack" == true ]]; then
    printf 'E2E stack preserved as project %s.\n' "$compose_project"
    return
  fi
  local_compose "$repository_root" "$environment_file" "$compose_project" \
    down -v --remove-orphans
}

trap cleanup EXIT

command -v docker >/dev/null
command -v pnpm >/dev/null
command -v curl >/dev/null
docker version >/dev/null
docker compose version >/dev/null

"$repository_root/scripts/security/init-secret-env.sh" local
pnpm --dir "$e2e_directory" install --frozen-lockfile
docker pull "$playwright_image"
reset_test_result_directory "$repository_root" test-results/e2e/playwright

readonly frontend_port="$(read_environment_value FRONTEND_PORT)"
readonly backend_port="$(read_environment_value BACKEND_PORT)"
readonly keycloak_port="$(read_environment_value KEYCLOAK_PORT)"
test -n "$frontend_port"
test -n "$backend_port"
test -n "$keycloak_port"

local_compose "$repository_root" "$environment_file" "$compose_project" \
  up --build --wait --wait-timeout 240 -d

wait_for_http_endpoint frontend "http://localhost:$frontend_port/" 120
wait_for_http_endpoint backend "http://localhost:$backend_port/actuator/health" 120
wait_for_http_endpoint \
  keycloak \
  "http://localhost:$keycloak_port/realms/inventory/.well-known/openid-configuration" \
  120

set +e
docker run --rm --init --ipc=host --network=host \
  --name inventory-playwright-local \
  --user "$(id -u):$(id -g)" \
  --volume "$repository_root:/work" \
  --workdir /work/tests/e2e \
  --env-file "$environment_file" \
  --env CI=true \
  --env E2E_MANAGE_STACK=false \
  --env E2E_BASE_URL="http://localhost:$frontend_port" \
  --env E2E_BACKEND_URL="http://localhost:$backend_port" \
  --env E2E_KEYCLOAK_URL="http://localhost:$keycloak_port" \
  --env PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
  --env PLAYWRIGHT_JUNIT_OUTPUT_NAME=/work/test-results/e2e/playwright/evidence/junit/playwright-results.xml \
  --env PLAYWRIGHT_OUTPUT_DIR=/work/test-results/e2e/playwright/evidence/artifacts \
  --env PLAYWRIGHT_SAFE_SCREENSHOT_DIR=/work/test-results/e2e/playwright/evidence/screenshots \
  --env PLAYWRIGHT_UX_EVIDENCE_DIR=/work/test-results/e2e/playwright/evidence/ux \
  --env PLAYWRIGHT_RETAIN_SENSITIVE_ARTIFACTS=false \
  --env PLAYWRIGHT_SAFE_REPORTING=true \
  "$playwright_image" \
  /work/tests/e2e/node_modules/.bin/playwright test "$@"
test_exit_code=$?
set -e

mkdir -p "$repository_root/test-results/e2e/playwright/evidence/docker"
local_compose "$repository_root" "$environment_file" "$compose_project" \
  ps > "$repository_root/test-results/e2e/playwright/evidence/docker/compose-ps.txt" || true
local_compose "$repository_root" "$environment_file" "$compose_project" \
  logs --no-color > "$repository_root/test-results/e2e/playwright/evidence/docker/compose.log" || true

status=failed
[[ "$test_exit_code" -eq 0 ]] && status=passed
python3 "$repository_root/scripts/testing/collect_test_results.py" \
  --suite e2e/playwright \
  --status "$status" \
  --output-root "$repository_root/test-results" \
  --junit "$repository_root/test-results/e2e/playwright/evidence/junit" \
  --metadata workflow=local \
  --metadata browser=playwright-docker

exit "$test_exit_code"
