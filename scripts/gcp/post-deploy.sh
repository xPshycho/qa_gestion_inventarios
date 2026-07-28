#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$script_dir/common.sh"

[[ $# -eq 0 ]] || {
  production_error "usage: scripts/gcp/post-deploy.sh"
  exit 2
}

for required_command in curl docker git jq realpath tee; do
  require_command "$required_command"
done
load_production_env
validate_production_evidence_dir "$DEPLOYED_SHA"
ensure_production_evidence_dir
umask 077

readonly post_deploy_dir="$PRODUCTION_EVIDENCE_DIR/post-deploy"
readonly phase_log_dir="$post_deploy_dir/logs"
readonly current_release_file="$PRODUCTION_STATE_DIR/current-release"
readonly current_sha_file="$PRODUCTION_STATE_DIR/current-sha"
readonly started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

[[ "$post_deploy_dir" == "$PRODUCTION_STATE_DIR"/evidence/*/post-deploy ]] || {
  production_error "post-deploy evidence path is not deployment-scoped"
  exit 1
}
if [[ -e "$post_deploy_dir" ]]; then
  [[ -d "$post_deploy_dir" && ! -L "$post_deploy_dir" ]] || {
    production_error "post-deploy evidence path is unsafe"
    exit 1
  }
  rm -rf -- "$post_deploy_dir"
fi
mkdir -p -- "$phase_log_dir"
chmod 0700 -- "$post_deploy_dir" "$phase_log_dir"

phase_records=()
failed_phases=0

run_phase() {
  local phase_name="$1"
  shift
  local phase_started_at
  local phase_finished_at
  local exit_code
  local result
  local log_file="$phase_log_dir/$phase_name.log"

  phase_started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '==> Production post-deploy phase: %s\n' "$phase_name"

  set +e
  "$@" 2>&1 |
    redact_production_secrets |
    tee "$log_file"
  exit_code="${PIPESTATUS[0]}"
  set -e
  chmod 0600 -- "$log_file"

  phase_finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [[ "$exit_code" -eq 0 ]]; then
    result=PASS
  else
    result=FAIL
    failed_phases=$((failed_phases + 1))
  fi

  phase_records+=("$(
    jq --compact-output --null-input \
      --arg name "$phase_name" \
      --arg result "$result" \
      --arg startedAt "$phase_started_at" \
      --arg finishedAt "$phase_finished_at" \
      --arg log "logs/$phase_name.log" \
      --argjson exitCode "$exit_code" \
      '{
        name: $name,
        result: $result,
        exitCode: $exitCode,
        startedAt: $startedAt,
        finishedAt: $finishedAt,
        log: $log
      }'
  )")

  printf '<== %s: %s\n' "$phase_name" "$result"
}

read_state_value() {
  local state_file="$1"
  local -a lines=()

  [[ -f "$state_file" && ! -L "$state_file" ]] || {
    production_error "required production state file is unavailable"
    return 1
  }
  mapfile -t lines < "$state_file"
  [[ "${#lines[@]}" -eq 1 && -n "${lines[0]}" ]] || {
    production_error "production state file must contain exactly one non-empty line"
    return 1
  }
  printf '%s' "${lines[0]}"
}

release_state_phase() {
  local current_release
  local current_sha
  local canonical_current
  local canonical_repository

  current_release="$(read_state_value "$current_release_file")"
  current_sha="$(read_state_value "$current_sha_file")"
  canonical_current="$(realpath -- "$current_release")"
  canonical_repository="$(realpath -- "$PRODUCTION_REPOSITORY_ROOT")"

  [[ "$current_sha" == "$DEPLOYED_SHA" ]]
  [[ "$canonical_current" == "$canonical_repository" ]]
  [[ "$(git -C "$canonical_repository" rev-parse HEAD)" == "$DEPLOYED_SHA" ]]
  [[ -z "$(git -C "$canonical_repository" status --porcelain --untracked-files=all)" ]]
  docker image inspect "inventory-backend:$DEPLOYED_SHA" >/dev/null
  docker image inspect "inventory-frontend:$DEPLOYED_SHA" >/dev/null

  printf 'Release state matches deployed SHA %s.\n' "$DEPLOYED_SHA"
}

compose_health_phase() {
  local service
  local container_id
  local container_sha
  local state
  local health
  local flyway_id
  local -a running_services=(
    postgres
    keycloak-postgres
    keycloak
    backend
    frontend
    prometheus
    grafana
    alloy
    loki
    tempo
    alertmanager
    gateway
  )
  local -a healthy_services=(
    postgres
    keycloak-postgres
    keycloak
    backend
    frontend
    gateway
  )

  for service in "${running_services[@]}"; do
    container_id="$(production_compose ps --quiet "$service")"
    [[ -n "$container_id" ]]
    state="$(docker inspect --format '{{.State.Status}}' "$container_id")"
    [[ "$state" == running ]]
    container_sha="$(
      docker inspect \
        --format '{{index .Config.Labels "com.inventory.sha"}}' \
        "$container_id"
    )"
    [[ "$container_sha" == "$DEPLOYED_SHA" ]]
  done

  for service in "${healthy_services[@]}"; do
    container_id="$(production_compose ps --quiet "$service")"
    health="$(
      docker inspect \
        --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' \
        "$container_id"
    )"
    [[ "$health" == healthy ]]
  done

  flyway_id="$(production_compose ps --all --quiet flyway)"
  [[ -n "$flyway_id" ]]
  [[ "$(docker inspect --format '{{.State.ExitCode}}' "$flyway_id")" == 0 ]]
  [[ "$(
    docker inspect \
      --format '{{index .Config.Labels "com.inventory.sha"}}' \
      "$flyway_id"
  )" == "$DEPLOYED_SHA" ]]

  printf 'Compose services are running with the requested SHA and healthy core checks.\n'
}

public_endpoints_phase() {
  local frontend_health
  local backend_health
  local auth_config
  local discovery
  local unauthenticated_status
  local redirect_headers
  local expected_issuer="$PRODUCTION_KEYCLOAK_URL/realms/$KEYCLOAK_REALM"
  local -a curl_options=(
    --fail
    --silent
    --show-error
    --proto '=https'
    --tlsv1.2
    --connect-timeout "${PRODUCTION_CONNECT_TIMEOUT_SECONDS:-10}"
    --max-time "${PRODUCTION_REQUEST_TIMEOUT_SECONDS:-30}"
  )

  frontend_health="$(
    curl "${curl_options[@]}" "$PRODUCTION_FRONTEND_URL/health"
  )"
  [[ "${frontend_health//$'\n'/}" == ok ]]

  backend_health="$(
    curl "${curl_options[@]}" "$PRODUCTION_FRONTEND_URL/api/actuator/health"
  )"
  jq --exit-status '.status == "UP"' <<< "$backend_health" >/dev/null

  auth_config="$(
    curl "${curl_options[@]}" "$PRODUCTION_FRONTEND_URL/auth-config.json"
  )"
  jq --exit-status \
    --arg url "$PRODUCTION_KEYCLOAK_URL" \
    --arg realm "$KEYCLOAK_REALM" \
    --arg clientId "$KEYCLOAK_CLIENT_ID" \
    '.url == $url and .realm == $realm and .clientId == $clientId' \
    <<< "$auth_config" >/dev/null

  discovery="$(
    curl \
      "${curl_options[@]}" \
      "$expected_issuer/.well-known/openid-configuration"
  )"
  jq --exit-status \
    --arg issuer "$expected_issuer" \
    '.issuer == $issuer' \
    <<< "$discovery" >/dev/null

  unauthenticated_status="$(
    curl \
      --silent \
      --show-error \
      --output /dev/null \
      --write-out '%{http_code}' \
      --proto '=https' \
      --tlsv1.2 \
      --connect-timeout "${PRODUCTION_CONNECT_TIMEOUT_SECONDS:-10}" \
      --max-time "${PRODUCTION_REQUEST_TIMEOUT_SECONDS:-30}" \
      "$PRODUCTION_FRONTEND_URL/api/products"
  )"
  [[ "$unauthenticated_status" == 401 ]]

  redirect_headers="$(
    curl \
      --silent \
      --show-error \
      --head \
      --max-redirs 0 \
      --connect-timeout "${PRODUCTION_CONNECT_TIMEOUT_SECONDS:-10}" \
      --max-time "${PRODUCTION_REQUEST_TIMEOUT_SECONDS:-30}" \
      "http://$PRODUCTION_PUBLIC_IP/health"
  )"
  grep -Eq '^HTTP/[0-9.]+ 301 ' <<< "$redirect_headers"
  grep -Fqi "location: $PRODUCTION_FRONTEND_URL/health" <<< "$redirect_headers"

  printf 'Public frontend, API, OIDC issuer, authentication boundary and HTTPS redirect passed.\n'
}

run_phase release-state release_state_phase
run_phase compose-health compose_health_phase
run_phase public-endpoints public_endpoints_phase
run_phase evidence-collection "$script_dir/collect-evidence.sh"

readonly phases_json="$(
  printf '%s\n' "${phase_records[@]}" | jq --slurp '.'
)"
if [[ "$failed_phases" -eq 0 ]]; then
  readonly overall_result=PASS
else
  readonly overall_result=FAIL
fi
readonly finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
readonly summary_json="$post_deploy_dir/summary.json"
readonly summary_markdown="$post_deploy_dir/summary.md"

jq --null-input \
  --arg result "$overall_result" \
  --arg environment production \
  --arg deploymentId "$PRODUCTION_DEPLOYMENT_ID" \
  --arg sha "$DEPLOYED_SHA" \
  --arg url "$PRODUCTION_FRONTEND_URL" \
  --arg startedAt "$started_at" \
  --arg finishedAt "$finished_at" \
  --argjson phases "$phases_json" \
  '{
    result: $result,
    environment: $environment,
    deploymentId: $deploymentId,
    sha: $sha,
    url: $url,
    startedAt: $startedAt,
    finishedAt: $finishedAt,
    phases: $phases
  }' > "$summary_json"

{
  printf '# GCP production post-deploy gate\n\n'
  printf -- '- Result: **%s**\n' "$overall_result"
  printf -- '- Deployment: `%s`\n' "$PRODUCTION_DEPLOYMENT_ID"
  printf -- '- SHA: `%s`\n' "$DEPLOYED_SHA"
  printf -- '- URL: `%s`\n' "$PRODUCTION_FRONTEND_URL"
  printf -- '- Started: `%s`\n' "$started_at"
  printf -- '- Finished: `%s`\n\n' "$finished_at"
  printf '| Phase | Result | Exit code |\n'
  printf '|---|---:|---:|\n'
  printf '%s\n' "$phases_json" |
    jq --raw-output '.[] | "| \(.name) | \(.result) | \(.exitCode) |"'
  printf '\nSecrets, credentials, tokens and rendered runtime configuration are excluded.\n'
} > "$summary_markdown"
chmod 0600 -- "$summary_json" "$summary_markdown"

"$script_dir/verify-evidence-safety.sh"

if [[ "$overall_result" != PASS ]]; then
  production_error "post-deploy gate failed in $failed_phases phase(s)"
  exit 1
fi

printf 'Production post-deploy gate passed for %s at %s.\n' \
  "$DEPLOYED_SHA" \
  "$PRODUCTION_FRONTEND_URL"
