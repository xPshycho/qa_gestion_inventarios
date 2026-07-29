#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$script_dir/common.sh"

require_command docker
require_command jq
require_command node
require_command pnpm
load_staging_env
ensure_evidence_dir

readonly post_deploy_dir="$STAGING_EVIDENCE_DIR/post-deploy"
readonly phase_log_dir="$post_deploy_dir/logs"
readonly phase_result_dir="$STAGING_STATE_DIR/.post-deploy-phase-results-$STAGING_DEPLOYMENT_ID"
readonly run_zap="${STAGING_RUN_ZAP:-true}"
if [[ "$run_zap" != true && "$run_zap" != false ]]; then
  staging_error "STAGING_RUN_ZAP must be either true or false"
  exit 2
fi

reset_post_deploy_evidence
mkdir -p -- "$phase_log_dir" "$phase_result_dir"
chmod 0700 -- "$post_deploy_dir" "$phase_log_dir" "$phase_result_dir"

cleanup_phase_results() {
  if [[ -d "$phase_result_dir" ]]; then
    find "$phase_result_dir" -type f -delete || true
    rmdir "$phase_result_dir" 2>/dev/null || true
  fi
}
trap cleanup_phase_results EXIT

phase_records=()
failed_phases=0
parallel_phase_names=()
parallel_phase_pids=()

execute_phase() {
  local phase_name="$1"
  shift
  local started_at
  local finished_at
  local exit_code
  local result
  local log_file="$phase_log_dir/$phase_name.log"

  started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '\n==> Staging post-deploy phase: %s\n' "$phase_name"

  set +e
  "$@" 2>&1 | redact_staging_secrets | tee "$log_file"
  exit_code="${PIPESTATUS[0]}"
  set -e

  finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [[ "$exit_code" -eq 0 ]]; then
    result=PASS
  else
    result=FAIL
  fi

  jq --compact-output --null-input \
    --arg name "$phase_name" \
    --arg result "$result" \
    --arg startedAt "$started_at" \
    --arg finishedAt "$finished_at" \
    --arg log "logs/$phase_name.log" \
    --argjson exitCode "$exit_code" \
    '{
      name: $name,
      result: $result,
      exitCode: $exitCode,
      startedAt: $startedAt,
      finishedAt: $finishedAt,
      log: $log
    }' > "$phase_result_dir/$phase_name.json"

  printf '<== %s: %s\n' "$phase_name" "$result"
}

record_phase_result() {
  local phase_name="$1"
  local result_file="$phase_result_dir/$phase_name.json"

  if [[ ! -s "$result_file" ]]; then
    jq --compact-output --null-input \
      --arg name "$phase_name" \
      '{
        name: $name,
        result: "FAIL",
        exitCode: 1,
        error: "phase result was not produced"
      }' > "$result_file"
  fi

  phase_records+=("$(<"$result_file")")
  if ! jq --exit-status '.exitCode == 0' "$result_file" >/dev/null; then
    failed_phases=$((failed_phases + 1))
  fi
}

run_phase() {
  local phase_name="$1"
  shift

  execute_phase "$phase_name" "$@"
  record_phase_result "$phase_name"
}

start_parallel_phase() {
  local phase_name="$1"
  shift

  execute_phase "$phase_name" "$@" &
  parallel_phase_names+=("$phase_name")
  parallel_phase_pids+=("$!")
}

wait_parallel_phases() {
  local index
  local wait_exit_code

  for index in "${!parallel_phase_pids[@]}"; do
    set +e
    wait "${parallel_phase_pids[$index]}"
    wait_exit_code=$?
    set -e

    if [[ "$wait_exit_code" -ne 0 ]]; then
      printf 'Parallel phase %s terminated unexpectedly with exit code %s.\n' \
        "${parallel_phase_names[$index]}" \
        "$wait_exit_code" >&2
    fi
    record_phase_result "${parallel_phase_names[$index]}"
  done
}

record_skipped_phase() {
  local phase_name="$1"
  local reason="$2"
  local recorded_at
  local log_file="$phase_log_dir/$phase_name.log"

  recorded_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s\n' "$reason" | tee "$log_file"
  jq --compact-output --null-input \
    --arg name "$phase_name" \
    --arg startedAt "$recorded_at" \
    --arg finishedAt "$recorded_at" \
    --arg log "logs/$phase_name.log" \
    --arg reason "$reason" \
    '{
      name: $name,
      result: "SKIP",
      exitCode: 0,
      startedAt: $startedAt,
      finishedAt: $finishedAt,
      log: $log,
      reason: $reason
    }' > "$phase_result_dir/$phase_name.json"
  record_phase_result "$phase_name"
}

integration_phase() {
  "$script_dir/verify-integration.sh"
}

api_and_observability_phase() {
  local check_started_at
  local log_marker

  check_started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  log_marker="staging-observability-$STAGING_DEPLOYMENT_ID-$(date -u +%s)"

  # Produce a run-specific log in a Compose-labelled one-off container. Alloy
  # must ingest this marker from the current project for the Loki check to pass.
  staging_compose run \
    --rm \
    --no-deps \
    --entrypoint sh \
    postgres \
    -c 'printf "%s\n" "$1"; sleep 12' \
    staging-log-probe \
    "$log_marker"

  STAGING_CHECK_STARTED_AT="$check_started_at" \
  STAGING_OBSERVABILITY_LOG_MARKER="$log_marker" \
  STAGING_POST_DEPLOY_EVIDENCE_DIR="$post_deploy_dir/api-observability" \
    node "$STAGING_REPOSITORY_ROOT/tests/staging/post-deploy.mjs"
}

e2e_phase() {
  local e2e_directory="$STAGING_REPOSITORY_ROOT/tests/e2e"
  local chromium_executable="${PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH:-}"

  if [[ ! -x "$e2e_directory/node_modules/.bin/playwright" ]]; then
    pnpm --dir "$e2e_directory" install --frozen-lockfile
  fi
  if [[ -z "$chromium_executable" && -x /usr/bin/chromium ]]; then
    chromium_executable=/usr/bin/chromium
  fi

  E2E_MANAGE_STACK=false \
  E2E_BASE_URL="$STAGING_FRONTEND_URL" \
  E2E_BACKEND_URL="$STAGING_BACKEND_URL" \
  E2E_KEYCLOAK_URL="$STAGING_KEYCLOAK_URL" \
  E2E_KEYCLOAK_REALM="$KEYCLOAK_REALM" \
  PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH="$chromium_executable" \
  PLAYWRIGHT_OUTPUT_DIR="$post_deploy_dir/e2e/test-results" \
  PLAYWRIGHT_JUNIT_OUTPUT_NAME="$post_deploy_dir/e2e/junit.xml" \
  PLAYWRIGHT_SAFE_SCREENSHOT_DIR="$post_deploy_dir/e2e/screenshots" \
  PLAYWRIGHT_UX_EVIDENCE_DIR="$post_deploy_dir/e2e/ux-evidence" \
  PLAYWRIGHT_RETAIN_SENSITIVE_ARTIFACTS=false \
  PLAYWRIGHT_SAFE_REPORTING=true \
    pnpm --dir "$e2e_directory" test:smoke
}

security_headers_phase() {
  FRONTEND_URL="$STAGING_FRONTEND_URL" \
  KEYCLOAK_PUBLIC_URL="$STAGING_KEYCLOAK_URL" \
  SECURITY_HEADERS_REPORT_FILE="$post_deploy_dir/security/headers.txt" \
    "$STAGING_REPOSITORY_ROOT/tests/security/verify-headers.sh"
}

security_zap_phase() {
  ZAP_TARGET_URL="$STAGING_FRONTEND_URL" \
  ZAP_DOCKER_NETWORK=host \
  ZAP_REPORT_DIR="$post_deploy_dir/security/zap" \
    "$STAGING_REPOSITORY_ROOT/tests/security/run-zap-baseline.sh"
}

performance_smoke_phase() {
  local results_directory="$post_deploy_dir/performance"
  local container_results_directory

  mkdir -p -- "$results_directory"
  export BASE_URL="$STAGING_BACKEND_URL"
  export KEYCLOAK_URL="$STAGING_KEYCLOAK_URL"
  export KEYCLOAK_REALM
  export KEYCLOAK_CLIENT_ID
  export K6_USERNAME="$E2E_VIEWER_USERNAME"
  export K6_PASSWORD="$E2E_VIEWER_PASSWORD"
  export K6_PROFILE=smoke
  export K6_RESULTS_DIR="$results_directory"

  if command -v k6 >/dev/null 2>&1; then
    export K6_RESULTS_DIR="$results_directory"
    k6 run "$STAGING_REPOSITORY_ROOT/tests/performance/performance.js"
    return
  fi

  container_results_directory="/work/${results_directory#"$STAGING_REPOSITORY_ROOT/"}"
  [[ "$container_results_directory" != "/work/$results_directory" ]] || {
    staging_error "k6 evidence directory must be inside the repository"
    return 1
  }
  export K6_RESULTS_DIR="$container_results_directory"

  docker run --rm \
    --network host \
    --user "$(id -u):$(id -g)" \
    --volume "$STAGING_REPOSITORY_ROOT:/work" \
    --workdir /work \
    --env BASE_URL \
    --env KEYCLOAK_URL \
    --env KEYCLOAK_REALM \
    --env KEYCLOAK_CLIENT_ID \
    --env K6_USERNAME \
    --env K6_PASSWORD \
    --env K6_PROFILE \
    --env K6_RESULTS_DIR \
    "${K6_IMAGE:-grafana/k6:0.57.0@sha256:70af91f86cd8e142e0544a4edaf79835a80033f71974b92edd5ac36fd4442a7b}" \
    run tests/performance/performance.js
}

run_phase integration integration_phase
start_parallel_phase api-and-observability api_and_observability_phase
start_parallel_phase e2e-smoke e2e_phase
start_parallel_phase security-headers security_headers_phase
start_parallel_phase performance-smoke performance_smoke_phase
if [[ "$run_zap" == true ]]; then
  start_parallel_phase security-zap security_zap_phase
fi
wait_parallel_phases
if [[ "$run_zap" == false ]]; then
  record_skipped_phase \
    security-zap \
    "ZAP is skipped in the PR staging preview because the dedicated Security Testing job already ran it."
fi

set +e
"$script_dir/collect-evidence.sh"
collect_exit_code=$?
set -e
if [[ "$collect_exit_code" -ne 0 ]]; then
  failed_phases=$((failed_phases + 1))
  phase_records+=("$(
    jq --compact-output --null-input \
      --argjson exitCode "$collect_exit_code" \
      '{
        name: "evidence-collection",
        result: "FAIL",
        exitCode: $exitCode
      }'
  )")
fi

run_phase evidence-safety "$script_dir/verify-evidence-safety.sh"

readonly phases_json="$(
  printf '%s\n' "${phase_records[@]}" | jq --slurp '.'
)"
readonly overall_result="$(
  if [[ "$failed_phases" -eq 0 ]]; then
    printf PASS
  else
    printf FAIL
  fi
)"
readonly finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq --null-input \
  --arg result "$overall_result" \
  --arg deploymentId "$STAGING_DEPLOYMENT_ID" \
  --arg version "$APP_VERSION" \
  --arg commit "$(git -C "$STAGING_REPOSITORY_ROOT" rev-parse HEAD)" \
  --arg lifecycle "$STAGING_LIFECYCLE" \
  --arg visibility "$STAGING_VISIBILITY" \
  --arg finishedAt "$finished_at" \
  --argjson phases "$phases_json" \
  '{
    result: $result,
    environment: "staging",
    lifecycle: $lifecycle,
    visibility: $visibility,
    deploymentId: $deploymentId,
    version: $version,
    commit: $commit,
    finishedAt: $finishedAt,
    phases: $phases
  }' > "$post_deploy_dir/summary.json"

{
  printf '# Staging post-deploy gate\n\n'
  printf -- '- Result: **%s**\n' "$overall_result"
  printf -- '- Deployment: `%s`\n' "$STAGING_DEPLOYMENT_ID"
  printf -- '- Version: `%s`\n' "$APP_VERSION"
  printf -- '- Finished: `%s`\n' "$finished_at"
  printf -- '- Lifecycle: `%s`\n' "$STAGING_LIFECYCLE"
  printf -- '- Visibility: `%s` (loopback only)\n\n' "$STAGING_VISIBILITY"
  printf '| Phase | Result | Exit code |\n'
  printf '|---|---:|---:|\n'
  printf '%s\n' "$phases_json" |
    jq --raw-output '.[] | "| \(.name) | \(.result) | \(.exitCode) |"'
  printf '\nSecrets, tokens, the runtime environment file and the rendered realm are excluded.\n'
} > "$post_deploy_dir/summary.md"

if [[ "$overall_result" != PASS ]]; then
  staging_error "post-deploy gate failed in $failed_phases phase(s)"
  exit 1
fi

printf '\nStaging post-deploy gate passed. Evidence: %s\n' "$post_deploy_dir"
