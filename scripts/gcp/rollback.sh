#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$script_dir/common.sh"

[[ $# -eq 0 ]] || {
  production_error "usage: scripts/gcp/rollback.sh"
  exit 2
}

for required_command in \
  awk curl date docker env flock git jq mktemp realpath; do
  require_command "$required_command"
done
load_production_env
failed_release="$(realpath -- "$PRODUCTION_REPOSITORY_ROOT")"
readonly failed_release
failed_sha="$(git -C "$failed_release" rev-parse HEAD)"
readonly failed_sha
[[ "$failed_sha" =~ ^[0-9a-f]{40}$ ]] || {
  production_error "rollback checkout does not identify a full Git SHA"
  exit 1
}
[[ "$failed_release" == "$(
  realpath -m -- "${GCP_DEPLOY_PATH:?GCP_DEPLOY_PATH is required}/releases/$failed_sha"
)" ]] || {
  production_error "rollback must run from the exact failed release checkout"
  exit 1
}
validate_production_evidence_dir "$failed_sha"
ensure_production_evidence_dir
umask 077

readonly failed_deployment_id="$PRODUCTION_DEPLOYMENT_ID"
readonly rollback_timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
readonly rollback_deployment_id="$failed_deployment_id-rollback-$rollback_timestamp"
readonly rollback_started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
readonly current_release_file="$PRODUCTION_STATE_DIR/current-release"
readonly current_sha_file="$PRODUCTION_STATE_DIR/current-sha"
readonly previous_release_file="$PRODUCTION_STATE_DIR/previous-release"
readonly previous_sha_file="$PRODUCTION_STATE_DIR/previous-sha"
readonly blocked_release_file="$PRODUCTION_STATE_DIR/blocked-release.json"
readonly pending_deployment_file="$PRODUCTION_STATE_DIR/pending-deployment.json"
readonly last_backup_file="$PRODUCTION_STATE_DIR/last-predeploy-backup"
readonly rollback_evidence_file="$PRODUCTION_EVIDENCE_DIR/rollback.json"
readonly operation_lock_file="$PRODUCTION_STATE_DIR/operation.lock"

exec {operation_lock_fd}> "$operation_lock_file"
chmod 0600 -- "$operation_lock_file"
flock --exclusive --nonblock "$operation_lock_fd" || {
  production_error "another production deploy or rollback operation is active"
  exit 1
}

read_state_value() {
  local state_file="$1"
  local -a lines=()

  [[ -e "$state_file" ]] || return 1
  [[ -f "$state_file" && ! -L "$state_file" ]] || {
    production_error "invalid production state file: $state_file"
    return 2
  }
  mapfile -t lines < "$state_file"
  [[ "${#lines[@]}" -eq 1 && -n "${lines[0]}" ]] || {
    production_error "production state file must contain exactly one non-empty line"
    return 2
  }
  printf '%s' "${lines[0]}"
}

write_state_value() {
  local destination="$1"
  local value="$2"
  local temporary_file

  temporary_file="$(mktemp "$PRODUCTION_STATE_DIR/.state-value.XXXXXX")"
  printf '%s\n' "$value" > "$temporary_file"
  chmod 0600 -- "$temporary_file"
  mv -- "$temporary_file" "$destination"
}

write_json_atomically() {
  local destination="$1"
  shift
  local temporary_file

  temporary_file="$(mktemp "$(dirname -- "$destination")/.json.XXXXXX")"
  jq "$@" > "$temporary_file"
  chmod 0600 -- "$temporary_file"
  mv -- "$temporary_file" "$destination"
}

validate_release() {
  local release_path="$1"
  local expected_sha="$2"
  local expected_release
  local canonical_release

  [[ "$expected_sha" =~ ^[0-9a-f]{40}$ ]]
  [[ -d "$release_path/.git" && ! -L "$release_path" ]]
  canonical_release="$(realpath -- "$release_path")"
  expected_release="$(
    realpath -m -- "${GCP_DEPLOY_PATH:?GCP_DEPLOY_PATH is required}/releases/$expected_sha"
  )"
  [[ "$canonical_release" == "$expected_release" ]]
  [[ "$(git -C "$canonical_release" rev-parse HEAD)" == "$expected_sha" ]]
  [[ -z "$(git -C "$canonical_release" status --porcelain --untracked-files=all)" ]]
  [[ -f "$canonical_release/docker-compose.yml" ]]
  [[ -f "$canonical_release/docker-compose.production.yml" ]]
}

update_runtime_environment() {
  local runtime_target_sha="$1"
  local runtime_target_deployment_id="$2"
  local temporary_file

  [[ -f "$PRODUCTION_ENV_FILE" && ! -L "$PRODUCTION_ENV_FILE" ]] || {
    production_error "production environment file is unsafe"
    return 1
  }
  temporary_file="$(mktemp "$PRODUCTION_STATE_DIR/.rollback-env.XXXXXX")"

  if ! awk \
    -v app_version="$runtime_target_sha" \
    -v deployed_sha="$runtime_target_sha" \
    -v deployment_id="$runtime_target_deployment_id" \
    '
      BEGIN {
        app_seen = 0
        sha_seen = 0
        deployment_seen = 0
      }
      /^APP_VERSION=/ {
        print "APP_VERSION=" app_version
        app_seen += 1
        next
      }
      /^DEPLOYED_SHA=/ {
        print "DEPLOYED_SHA=" deployed_sha
        sha_seen += 1
        next
      }
      /^PRODUCTION_DEPLOYMENT_ID=/ {
        print "PRODUCTION_DEPLOYMENT_ID=" deployment_id
        deployment_seen += 1
        next
      }
      {
        print
      }
      END {
        if (app_seen != 1 || sha_seen != 1 || deployment_seen != 1) {
          exit 1
        }
      }
    ' "$PRODUCTION_ENV_FILE" > "$temporary_file"; then
    rm -f -- "$temporary_file"
    return 1
  fi

  chmod 0600 -- "$temporary_file"
  mv -- "$temporary_file" "$PRODUCTION_ENV_FILE"
}

rollback_abort() {
  production_error "$1"
  return 1
}

early_rollback_failed() {
  local exit_code=$?
  local public_stop_exit_code
  local service_state

  trap - ERR
  set +e
  production_compose stop gateway frontend backend keycloak
  public_stop_exit_code=$?
  if [[ "$public_stop_exit_code" -eq 0 ]]; then
    service_state=PUBLIC_SERVICES_STOPPED
  else
    service_state=PUBLIC_SERVICE_STOP_FAILED
  fi
  write_json_atomically "$blocked_release_file" \
    --null-input \
    --arg status BLOCKED_INVALID_RELEASE_STATE \
    --arg failedSha "$failed_sha" \
    --arg failedRelease "$failed_release" \
    --arg deploymentId "$rollback_deployment_id" \
    --arg serviceState "$service_state" \
    --arg blockedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson exitCode "$exit_code" \
    --argjson publicStopExitCode "$public_stop_exit_code" \
    '{
      status: $status,
      failedSha: $failedSha,
      failedRelease: $failedRelease,
      deploymentId: $deploymentId,
      databaseRestored: false,
      serviceState: $serviceState,
      blockedAt: $blockedAt,
      exitCode: $exitCode,
      publicStopExitCode: $publicStopExitCode
    }'
  cp -- "$blocked_release_file" "$rollback_evidence_file"
  chmod 0600 -- "$rollback_evidence_file"
  rm -f -- "$pending_deployment_file"
  production_error \
    "rollback state is invalid; public service stop result: $service_state"
  set -e
  exit "$exit_code"
}
trap early_rollback_failed ERR

current_release=""
current_sha=""
if [[ -e "$current_release_file" || -e "$current_sha_file" ]]; then
  if [[ ! -e "$current_release_file" || ! -e "$current_sha_file" ]]; then
    rollback_abort "current production release state is incomplete"
  fi
  current_release="$(read_state_value "$current_release_file")"
  current_sha="$(read_state_value "$current_sha_file")"
  validate_release "$current_release" "$current_sha"
fi
readonly current_release
readonly current_sha

previous_release=""
previous_sha=""
if [[ -e "$previous_release_file" || -e "$previous_sha_file" ]]; then
  if [[ ! -e "$previous_release_file" || ! -e "$previous_sha_file" ]]; then
    rollback_abort "previous production release state is incomplete"
  fi
  previous_release="$(read_state_value "$previous_release_file")"
  previous_sha="$(read_state_value "$previous_sha_file")"
  validate_release "$previous_release" "$previous_sha"
fi
readonly previous_release
readonly previous_sha

backup_manifest=""
if [[ -e "$last_backup_file" ]]; then
  backup_directory="$(read_state_value "$last_backup_file")"
  canonical_backup_directory="$(realpath -m -- "$backup_directory")"
  canonical_backup_root="$(realpath -m -- "$PRODUCTION_STATE_DIR/backups")"
  if [[ "$canonical_backup_directory" != "$canonical_backup_root"/* ]]; then
    rollback_abort "predeploy backup pointer escapes the backup root"
  fi
  if [[ -f "$canonical_backup_directory/manifest.json" \
    && ! -L "$canonical_backup_directory/manifest.json" ]]; then
    manifest_candidate_sha="$(
      jq --raw-output '.candidateSha // ""' \
        "$canonical_backup_directory/manifest.json"
    )"
    if [[ "$manifest_candidate_sha" == "$failed_sha" ]]; then
      backup_manifest="$canonical_backup_directory/manifest.json"
    fi
  fi
fi
readonly backup_manifest

if [[ "$current_sha" == "$failed_sha" ]]; then
  target_release="$previous_release"
  target_sha="$previous_sha"
elif [[ -n "$current_sha" ]]; then
  # deploy.sh failed before advancing the state pointers. Force the already
  # selected release back over any partially recreated candidate containers.
  target_release="$current_release"
  target_sha="$current_sha"
else
  target_release=""
  target_sha=""
fi
readonly target_release
readonly target_sha

if [[ -z "$target_sha" ]]; then
  trap - ERR
  set +e
  production_compose stop gateway frontend backend keycloak
  public_stop_exit_code=$?
  production_compose down --remove-orphans
  down_exit_code=$?
  set -e
  rm -f -- "$current_release_file" "$current_sha_file" "$pending_deployment_file"

  if [[ "$down_exit_code" -eq 0 || "$public_stop_exit_code" -eq 0 ]]; then
    no_target_status=BLOCKED_NO_PREVIOUS_RELEASE
    no_target_service_state=PUBLIC_SERVICES_STOPPED
  else
    no_target_status=BLOCKED_PUBLIC_SERVICE_STOP_FAILED
    no_target_service_state=PUBLIC_SERVICE_STOP_FAILED
  fi
  write_json_atomically "$blocked_release_file" \
    --null-input \
    --arg status "$no_target_status" \
    --arg failedSha "$failed_sha" \
    --arg failedRelease "$failed_release" \
    --arg deploymentId "$failed_deployment_id" \
    --arg backupManifest "$backup_manifest" \
    --arg serviceState "$no_target_service_state" \
    --arg blockedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson publicStopExitCode "$public_stop_exit_code" \
    --argjson downExitCode "$down_exit_code" \
    '{
      status: $status,
      failedSha: $failedSha,
      failedRelease: $failedRelease,
      deploymentId: $deploymentId,
      databaseRestored: false,
      backupManifest: (
        if $backupManifest == "" then null else $backupManifest end
      ),
      serviceState: $serviceState,
      publicStopExitCode: $publicStopExitCode,
      downExitCode: $downExitCode,
      blockedAt: $blockedAt
    }'
  cp -- "$blocked_release_file" "$rollback_evidence_file"
  chmod 0600 -- "$rollback_evidence_file"

  production_error \
    "no previous release exists; public service stop result: $no_target_service_state"
  if [[ "$no_target_service_state" == PUBLIC_SERVICES_STOPPED ]]; then
    exit 1
  fi
  exit "$((public_stop_exit_code != 0 ? public_stop_exit_code : down_exit_code))"
fi

validate_release "$target_release" "$target_sha"
canonical_target_release="$(realpath -- "$target_release")"
readonly canonical_target_release

target_compose() {
  APP_VERSION="$target_sha" \
  DEPLOYED_SHA="$target_sha" \
  PRODUCTION_DEPLOYMENT_ID="$rollback_deployment_id" \
    docker compose \
    --env-file "$PRODUCTION_ENV_FILE" \
    --project-name "$COMPOSE_PROJECT_NAME" \
    --file "$canonical_target_release/docker-compose.yml" \
    --file "$canonical_target_release/docker-compose.production.yml" \
    "$@"
}

runtime_env_switched=false
state_switched=false

switch_release_state() {
  if [[ "$current_sha" == "$failed_sha" ]]; then
    write_state_value "$previous_release_file" "$failed_release"
    write_state_value "$previous_sha_file" "$failed_sha"
  fi
  write_state_value "$current_release_file" "$canonical_target_release"
  write_state_value "$current_sha_file" "$target_sha"
  state_switched=true
}

rollback_failed() {
  local exit_code=$?
  local public_stop_exit_code
  local rollback_status
  local service_state

  trap - ERR
  set +e
  if [[ "$runtime_env_switched" == true && "$state_switched" != true ]]; then
    switch_release_state
  fi
  if [[ "$runtime_env_switched" == true ]]; then
    target_compose stop gateway frontend backend keycloak
  else
    production_compose stop gateway frontend backend keycloak
  fi
  public_stop_exit_code=$?
  if [[ "$public_stop_exit_code" -eq 0 ]]; then
    rollback_status=BLOCKED_ROLLBACK_FAILED
    service_state=PUBLIC_SERVICES_STOPPED
  else
    rollback_status=BLOCKED_ROLLBACK_AND_PUBLIC_STOP_FAILED
    service_state=PUBLIC_SERVICE_STOP_FAILED
  fi
  write_json_atomically "$blocked_release_file" \
    --null-input \
    --arg status "$rollback_status" \
    --arg failedSha "$failed_sha" \
    --arg targetSha "$target_sha" \
    --arg targetRelease "$canonical_target_release" \
    --arg deploymentId "$rollback_deployment_id" \
    --arg backupManifest "$backup_manifest" \
    --arg serviceState "$service_state" \
    --arg blockedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson exitCode "$exit_code" \
    --argjson publicStopExitCode "$public_stop_exit_code" \
    '{
      status: $status,
      failedSha: $failedSha,
      targetSha: $targetSha,
      targetRelease: $targetRelease,
      deploymentId: $deploymentId,
      databaseRestored: false,
      backupManifest: (
        if $backupManifest == "" then null else $backupManifest end
      ),
      serviceState: $serviceState,
      blockedAt: $blockedAt,
      exitCode: $exitCode,
      publicStopExitCode: $publicStopExitCode
    }'
  cp -- "$blocked_release_file" "$rollback_evidence_file"
  chmod 0600 -- "$rollback_evidence_file"
  rm -f -- "$pending_deployment_file"
  production_error \
    "rollback target failed validation; public service stop result: $service_state"
  set -e
  exit "$exit_code"
}
trap rollback_failed ERR

update_runtime_environment "$target_sha" "$rollback_deployment_id"
runtime_env_switched=true
load_production_env_file "$PRODUCTION_ENV_FILE"

env \
  PRODUCTION_STATE_DIR="$PRODUCTION_STATE_DIR" \
  PRODUCTION_ENV_FILE="$PRODUCTION_ENV_FILE" \
  PRODUCTION_EVIDENCE_DIR="$PRODUCTION_EVIDENCE_DIR" \
  GCP_DEPLOY_PATH="${GCP_DEPLOY_PATH:?GCP_DEPLOY_PATH is required}" \
  bash "$canonical_target_release/scripts/gcp/render-keycloak-realm.sh"
target_compose config --quiet

if ! docker image inspect "inventory-backend:$target_sha" >/dev/null 2>&1 \
  || ! docker image inspect "inventory-frontend:$target_sha" >/dev/null 2>&1; then
  target_compose build backend frontend
fi
docker image inspect "inventory-backend:$target_sha" >/dev/null
docker image inspect "inventory-frontend:$target_sha" >/dev/null

switch_release_state
target_compose stop gateway frontend backend keycloak || true

wait_timeout="${PRODUCTION_WAIT_TIMEOUT_SECONDS:-600}"
[[ "$wait_timeout" =~ ^[1-9][0-9]{1,3}$ ]]
readonly wait_timeout
target_compose up \
  --detach \
  --wait \
  --wait-timeout "$wait_timeout" \
  --no-build \
  --force-recreate \
  --remove-orphans

for service in \
  postgres keycloak-postgres keycloak backend frontend prometheus grafana alloy \
  loki tempo alertmanager gateway; do
  container_id="$(target_compose ps --quiet "$service")"
  [[ -n "$container_id" ]]
  [[ "$(docker inspect --format '{{.State.Status}}' "$container_id")" == running ]]
  [[ "$(
    docker inspect \
      --format '{{index .Config.Labels "com.inventory.sha"}}' \
      "$container_id"
  )" == "$target_sha" ]]
done
for service in postgres keycloak-postgres keycloak backend frontend gateway; do
  container_id="$(target_compose ps --quiet "$service")"
  [[ "$(
    docker inspect \
      --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' \
      "$container_id"
  )" == healthy ]]
done
flyway_id="$(target_compose ps --all --quiet flyway)"
[[ -n "$flyway_id" ]]
[[ "$(docker inspect --format '{{.State.ExitCode}}' "$flyway_id")" == 0 ]]
[[ "$(
  docker inspect \
    --format '{{index .Config.Labels "com.inventory.sha"}}' \
    "$flyway_id"
)" == "$target_sha" ]]

expected_issuer="$PRODUCTION_KEYCLOAK_URL/realms/$KEYCLOAK_REALM"
readonly expected_issuer
curl_options=(
  --fail
  --silent
  --show-error
  --proto '=https'
  --tlsv1.2
  --connect-timeout "${PRODUCTION_CONNECT_TIMEOUT_SECONDS:-10}"
  --max-time "${PRODUCTION_REQUEST_TIMEOUT_SECONDS:-30}"
)
readonly curl_options

frontend_health="$(curl "${curl_options[@]}" "$PRODUCTION_FRONTEND_URL/health")"
[[ "${frontend_health//$'\n'/}" == ok ]]
backend_health="$(
  curl "${curl_options[@]}" "$PRODUCTION_FRONTEND_URL/api/actuator/health"
)"
jq --exit-status '.status == "UP"' <<< "$backend_health" >/dev/null
discovery="$(
  curl \
    "${curl_options[@]}" \
    "$expected_issuer/.well-known/openid-configuration"
)"
jq --exit-status \
  --arg issuer "$expected_issuer" \
  '.issuer == $issuer' \
  <<< "$discovery" >/dev/null

token_response="$(
  {
    printf 'data-urlencode = "grant_type=password"\n'
    printf 'data-urlencode = "client_id=%s"\n' "$KEYCLOAK_CLIENT_ID"
    printf 'data-urlencode = "username=%s"\n' "$E2E_VIEWER_USERNAME"
    printf 'data-urlencode = "password=%s"\n' "$E2E_VIEWER_PASSWORD"
    printf 'data-urlencode = "scope=openid"\n'
  } |
    curl \
      "${curl_options[@]}" \
      --request POST \
      --header 'Content-Type: application/x-www-form-urlencoded' \
      --config - \
      "$expected_issuer/protocol/openid-connect/token"
)"
access_token="$(
  jq --exit-status --raw-output \
    '.access_token | select(type == "string" and length > 15)' \
    <<< "$token_response"
)"
authorization_header="Authorization: Bearer $access_token"
dashboard="$(
  curl \
    "${curl_options[@]}" \
    --header "$authorization_header" \
    "$PRODUCTION_FRONTEND_URL/api/reports/dashboard"
)"
jq --exit-status '
  (.metrics.totalProducts | type == "number" and . > 0)
  and (.criticalProducts | type == "array")
  and (.mostMovedProducts | type == "array")
  and (.recentMovements | type == "array")
' <<< "$dashboard" >/dev/null
products="$(
  curl \
    "${curl_options[@]}" \
    --header "$authorization_header" \
    "$PRODUCTION_FRONTEND_URL/api/products"
)"
jq --exit-status '
  (.totalElements | type == "number" and . > 0)
  and (.content | type == "array" and length > 0)
' <<< "$products" >/dev/null
unset access_token authorization_header token_response

readonly rollback_finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
write_json_atomically "$rollback_evidence_file" \
  --null-input \
  --arg result ROLLED_BACK \
  --arg environment production \
  --arg failedSha "$failed_sha" \
  --arg restoredSha "$target_sha" \
  --arg restoredRelease "$canonical_target_release" \
  --arg deploymentId "$rollback_deployment_id" \
  --arg backupManifest "$backup_manifest" \
  --arg startedAt "$rollback_started_at" \
  --arg finishedAt "$rollback_finished_at" \
  '{
    result: $result,
    environment: $environment,
    failedSha: $failedSha,
    restoredSha: $restoredSha,
    restoredRelease: $restoredRelease,
    deploymentId: $deploymentId,
    databaseRestored: false,
    predeployBackupForManualRestore: (
      if $backupManifest == "" then null else $backupManifest end
    ),
    startedAt: $startedAt,
    finishedAt: $finishedAt
  }'
rm -f -- "$blocked_release_file" "$pending_deployment_file"
trap - ERR

printf 'Production release rolled back from %s to %s.\n' \
  "$failed_sha" \
  "$target_sha"
printf 'Databases were preserved. Manual restore manifest: %s\n' \
  "${backup_manifest:-unavailable}"
