#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly repository_root="$(cd -- "$script_dir/../.." && pwd)"
readonly environment_file="$repository_root/.env"
readonly compose_project="${SECURITY_COMPOSE_PROJECT_NAME:-inventory-security-local}"
readonly zap_image="${ZAP_IMAGE:-zaproxy/zap-stable:2.17.0@sha256:c558ee87358911ab17278c70991e856f57793e115d9cd0f88ca475cf82907a1a}"
readonly trivy_image="${TRIVY_IMAGE:-ghcr.io/aquasecurity/trivy:0.70.0@sha256:be1190afcb28352bfddc4ddeb71470835d16462af68d310f9f4bca710961a41e}"
failed=0
results_initialized=false

source "$repository_root/scripts/testing/local_compose.sh"

cleanup() {
  local exit_code=$?
  trap - EXIT
  set +e

  if [[ "$results_initialized" == true ]]; then
    capture_local_compose_diagnostics \
      "$repository_root" \
      "$environment_file" \
      "$compose_project" \
      "$repository_root/test-results/security/zap/evidence/docker"
    for suite in headers zap trivy; do
      if [[ ! -f "$repository_root/test-results/security/$suite/summary.json" ]]; then
        python3 "$repository_root/scripts/testing/collect_test_results.py" \
          --suite "security/$suite" \
          --status failed \
          --output-root "$repository_root/test-results" \
          --metadata workflow=local \
          --metadata failureStage=setup
      fi
    done
  fi

  local_compose "$repository_root" "$environment_file" "$compose_project" \
    down -v --remove-orphans
  exit "$exit_code"
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

run_trivy() {
  local report_directory="$repository_root/test-results/security/trivy/evidence/reports"
  local cache_directory="${LOCAL_TRIVY_CACHE_DIR:-/tmp/qa-gestion-inventarios-trivy-$(id -u)}"
  local docker_socket_group
  local trivy_exit_code=0
  mkdir -p "$report_directory" "$cache_directory"
  docker_socket_group="$(stat -c '%g' /var/run/docker.sock)"

  docker run --rm \
    --user "$(id -u):$(id -g)" \
    --group-add "$docker_socket_group" \
    --volume "$repository_root:/workspace:ro" \
    --volume "$report_directory:/reports" \
    --volume "$cache_directory:/cache" \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    --env TRIVY_CACHE_DIR=/cache \
    "$trivy_image" \
    fs \
    --db-repository ghcr.io/aquasecurity/trivy-db:2 \
    --java-db-repository ghcr.io/aquasecurity/trivy-java-db:1 \
    --scanners vuln,misconfig \
    --severity HIGH,CRITICAL \
    --ignore-unfixed \
    --exit-code 1 \
    --format json \
    --output /reports/repository.json \
    /workspace || trivy_exit_code=1

  docker run --rm \
    --user "$(id -u):$(id -g)" \
    --group-add "$docker_socket_group" \
    --volume "$report_directory:/reports" \
    --volume "$cache_directory:/cache" \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    --env TRIVY_CACHE_DIR=/cache \
    "$trivy_image" \
    image \
    --db-repository ghcr.io/aquasecurity/trivy-db:2 \
    --java-db-repository ghcr.io/aquasecurity/trivy-java-db:1 \
    --severity HIGH,CRITICAL \
    --ignore-unfixed \
    --exit-code 1 \
    --format json \
    --output /reports/backend-image.json \
    "$compose_project-backend:latest" || trivy_exit_code=1

  docker run --rm \
    --user "$(id -u):$(id -g)" \
    --group-add "$docker_socket_group" \
    --volume "$report_directory:/reports" \
    --volume "$cache_directory:/cache" \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    --env TRIVY_CACHE_DIR=/cache \
    "$trivy_image" \
    image \
    --db-repository ghcr.io/aquasecurity/trivy-db:2 \
    --java-db-repository ghcr.io/aquasecurity/trivy-java-db:1 \
    --severity HIGH,CRITICAL \
    --ignore-unfixed \
    --exit-code 1 \
    --format json \
    --output /reports/frontend-image.json \
    "$compose_project-frontend:latest" || trivy_exit_code=1

  return "$trivy_exit_code"
}

frontend_port="$(read_environment_value FRONTEND_PORT)"
keycloak_port="$(read_environment_value KEYCLOAK_PORT)"
test -n "$frontend_port"
test -n "$keycloak_port"

reset_test_result_directory "$repository_root" test-results/security/headers
reset_test_result_directory "$repository_root" test-results/security/zap
reset_test_result_directory "$repository_root" test-results/security/trivy
results_initialized=true
docker_pull_public_image "$zap_image"
docker_pull_public_image "$trivy_image"

local_compose "$repository_root" "$environment_file" "$compose_project" \
  up --build --wait --wait-timeout 240 -d

wait_for_http_endpoint frontend "http://localhost:$frontend_port/" 120
wait_for_http_endpoint \
  keycloak \
  "http://localhost:$keycloak_port/realms/inventory/.well-known/openid-configuration" \
  120

set +e
run_trivy
trivy_exit_code=$?
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

trivy_status=failed
[[ "$trivy_exit_code" -eq 0 ]] && trivy_status=passed
python3 "$repository_root/scripts/testing/collect_test_results.py" \
  --suite security/trivy \
  --status "$trivy_status" \
  --output-root "$repository_root/test-results" \
  --metadata workflow=local \
  --metadata format=trivy-json

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
[[ "$trivy_exit_code" -eq 0 ]] || failed=1
exit "$failed"
