#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly repository_root="$(cd -- "$script_dir/../.." && pwd)"
readonly environment_file="$repository_root/.env"
readonly playwright_image="${PLAYWRIGHT_IMAGE:-mcr.microsoft.com/playwright:v1.60.0-noble}"
readonly k6_image="${K6_IMAGE:-grafana/k6:0.57.0@sha256:70af91f86cd8e142e0544a4edaf79835a80033f71974b92edd5ac36fd4442a7b}"
readonly compose_project="${LOCAL_TEST_COMPOSE_PROJECT_NAME:-inventory-e2e-local}"
declare -a phase_results=()
failed_phases=0

source "$repository_root/scripts/testing/local_compose.sh"

record_phase() {
  local name="$1"
  local exit_code="$2"
  local result=PASS
  if [[ "$exit_code" -ne 0 ]]; then
    result=FAIL
    failed_phases=$((failed_phases + 1))
  fi
  phase_results+=("$name:$result:$exit_code")
}

run_phase() {
  local name="$1"
  shift
  printf '\n==> %s\n' "$name"
  set +e
  "$@"
  local exit_code=$?
  set -e
  record_phase "$name" "$exit_code"
}

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

run_frontend_tests() {
  pnpm --dir "$repository_root/frontend" install --frozen-lockfile
  pnpm --dir "$repository_root/frontend" build
  pnpm --dir "$repository_root/frontend" test
}

run_performance_tests() {
  local viewer_password
  local backend_port
  local keycloak_port
  viewer_password="$(read_environment_value E2E_VIEWER_PASSWORD)"
  backend_port="$(read_environment_value BACKEND_PORT)"
  keycloak_port="$(read_environment_value KEYCLOAK_PORT)"
  test -n "$viewer_password"
  test -n "$backend_port"
  test -n "$keycloak_port"
  reset_test_result_directory "$repository_root" test-results/performance/k6

  local test_exit_code=0
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
    --env K6_PROFILE=smoke \
    --env K6_RESULTS_DIR=/work/test-results/performance/k6 \
    "$k6_image" \
    run tests/performance/performance.js || test_exit_code=$?

  local status=failed
  [[ "$test_exit_code" -eq 0 ]] && status=passed
  python3 "$repository_root/scripts/testing/collect_test_results.py" \
    --suite performance/k6 \
    --status "$status" \
    --output-root "$repository_root/test-results" \
    --metadata workflow=local \
    --metadata nativeSummary=k6-summary.json

  return "$test_exit_code"
}

run_security_tests() {
  local frontend_port
  local keycloak_port
  frontend_port="$(read_environment_value FRONTEND_PORT)"
  keycloak_port="$(read_environment_value KEYCLOAK_PORT)"
  test -n "$frontend_port"
  test -n "$keycloak_port"
  reset_test_result_directory "$repository_root" test-results/security/headers
  reset_test_result_directory "$repository_root" test-results/security/zap

  local headers_exit_code=0
  FRONTEND_URL="http://localhost:$frontend_port" \
  KEYCLOAK_PUBLIC_URL="http://localhost:$keycloak_port" \
  SECURITY_HEADERS_REPORT_FILE=test-results/security/headers/evidence/headers.txt \
    "$repository_root/tests/security/verify-headers.sh" || headers_exit_code=$?

  local zap_exit_code=0
  ZAP_TARGET_URL="http://localhost:$frontend_port" \
  ZAP_DOCKER_NETWORK=host \
  ZAP_REPORT_DIR=test-results/security/zap/evidence/reports \
    "$repository_root/tests/security/run-zap-baseline.sh" || zap_exit_code=$?

  local headers_status=failed
  [[ "$headers_exit_code" -eq 0 ]] && headers_status=passed
  python3 "$repository_root/scripts/testing/collect_test_results.py" \
    --suite security/headers \
    --status "$headers_status" \
    --output-root "$repository_root/test-results" \
    --metadata workflow=local

  local zap_status=failed
  [[ "$zap_exit_code" -eq 0 ]] && zap_status=passed
  python3 "$repository_root/scripts/testing/collect_test_results.py" \
    --suite security/zap \
    --status "$zap_status" \
    --output-root "$repository_root/test-results" \
    --metadata workflow=local \
    --metadata format=zap-json-markdown

  [[ "$headers_exit_code" -eq 0 && "$zap_exit_code" -eq 0 ]]
}

cleanup() {
  local_compose "$repository_root" "$environment_file" "$compose_project" \
    down -v --remove-orphans >/dev/null 2>&1 || true
}

trap cleanup EXIT
cd "$repository_root"

command -v awk >/dev/null
command -v docker >/dev/null
command -v java >/dev/null
command -v pnpm >/dev/null
docker version >/dev/null
docker compose version >/dev/null

./scripts/security/init-secret-env.sh local

run_phase backend-build \
  bash -c 'cd backend && ./gradlew clean assemble --no-daemon'
run_phase backend-unit \
  bash -c 'cd backend && ./gradlew test jacocoTestReport jacocoTestCoverageVerification --no-daemon'
run_phase backend-api \
  bash -c 'cd backend && ./gradlew apiTest --no-daemon'
run_phase backend-integration \
  bash -c 'cd backend && ./gradlew integrationTest --no-daemon'
run_phase frontend run_frontend_tests
run_phase e2e \
  env E2E_KEEP_STACK=true E2E_COMPOSE_PROJECT_NAME="$compose_project" \
    "$repository_root/tests/e2e/scripts/run-local.sh"
run_phase performance run_performance_tests
run_phase security run_security_tests
run_phase collect-results "$repository_root/scripts/testing/collect_local_test_results.sh"

printf '\nLocal test summary\n'
for phase_result in "${phase_results[@]}"; do
  IFS=: read -r phase result exit_code <<< "$phase_result"
  printf '%-22s %-4s (exit %s)\n' "$phase" "$result" "$exit_code"
done
printf '\nResults: %s/test-results\n' "$repository_root"

if [[ "$failed_phases" -ne 0 ]]; then
  printf '%d local test phase(s) failed.\n' "$failed_phases" >&2
  exit 1
fi
