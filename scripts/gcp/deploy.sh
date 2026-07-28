#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$script_dir/common.sh"

[[ $# -eq 0 ]] || {
  production_error "usage: scripts/gcp/deploy.sh"
  exit 2
}

for required_command in \
  awk date docker env find flock git gzip jq mktemp openssl realpath sha256sum; do
  require_command "$required_command"
done
load_production_env
validate_production_evidence_dir "$DEPLOYED_SHA"

umask 077

readonly deployment_root="${GCP_DEPLOY_PATH:?GCP_DEPLOY_PATH is required}"
readonly releases_root="$deployment_root/releases"
readonly state_deployments_dir="$PRODUCTION_STATE_DIR/deployments"
readonly state_backups_dir="$PRODUCTION_STATE_DIR/backups"
readonly current_release_file="$PRODUCTION_STATE_DIR/current-release"
readonly current_sha_file="$PRODUCTION_STATE_DIR/current-sha"
readonly previous_release_file="$PRODUCTION_STATE_DIR/previous-release"
readonly previous_sha_file="$PRODUCTION_STATE_DIR/previous-sha"
readonly pending_deployment_file="$PRODUCTION_STATE_DIR/pending-deployment.json"
readonly last_backup_file="$PRODUCTION_STATE_DIR/last-predeploy-backup"
readonly operation_lock_file="$PRODUCTION_STATE_DIR/operation.lock"
readonly transaction_file="$state_deployments_dir/$PRODUCTION_DEPLOYMENT_ID.json"
readonly deploy_evidence_file="$PRODUCTION_EVIDENCE_DIR/deploy.json"
readonly started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

[[ "$deployment_root" == /* && "$deployment_root" != / ]] || {
  production_error "GCP_DEPLOY_PATH must be an absolute non-root directory"
  exit 1
}
[[ "$PRODUCTION_STATE_DIR" == "$deployment_root"/shared ]] || {
  production_error "PRODUCTION_STATE_DIR must equal GCP_DEPLOY_PATH/shared"
  exit 1
}
[[ "$PRODUCTION_ENV_FILE" == "$PRODUCTION_STATE_DIR"/production.env ]] || {
  production_error "PRODUCTION_ENV_FILE must be stored in the shared state directory"
  exit 1
}
[[ "$PRODUCTION_EVIDENCE_DIR" == "$PRODUCTION_STATE_DIR"/evidence/* ]] || {
  production_error "PRODUCTION_EVIDENCE_DIR must identify one deployment evidence directory"
  exit 1
}
[[ ! -L "$PRODUCTION_STATE_DIR" && ! -L "$PRODUCTION_EVIDENCE_DIR" ]] || {
  production_error "production state and evidence directories cannot be symbolic links"
  exit 1
}

mkdir -p -- \
  "$PRODUCTION_STATE_DIR" \
  "$state_deployments_dir" \
  "$state_backups_dir"
ensure_production_evidence_dir
chmod 0700 -- \
  "$PRODUCTION_STATE_DIR" \
  "$state_deployments_dir" \
  "$state_backups_dir" \
  "$PRODUCTION_EVIDENCE_DIR"
find "$PRODUCTION_EVIDENCE_DIR" -mindepth 1 -maxdepth 1 \
  -exec rm -rf -- {} +

exec {operation_lock_fd}> "$operation_lock_file"
chmod 0600 -- "$operation_lock_file"
flock --exclusive --nonblock "$operation_lock_fd" || {
  production_error "another production deploy or rollback operation is active"
  exit 1
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

write_json_atomically() {
  local destination="$1"
  shift
  local destination_directory
  local temporary_file

  destination_directory="$(dirname -- "$destination")"
  temporary_file="$(mktemp "$destination_directory/.json.XXXXXX")"
  jq "$@" > "$temporary_file"
  chmod 0600 -- "$temporary_file"
  mv -- "$temporary_file" "$destination"
}

validate_release() {
  local release_path="$1"
  local expected_sha="$2"
  local canonical_release
  local expected_release

  [[ "$expected_sha" =~ ^[0-9a-f]{40}$ ]] || {
    production_error "release SHA is invalid"
    return 1
  }
  [[ -d "$release_path/.git" && ! -L "$release_path" ]] || {
    production_error "release is not a regular Git checkout: $release_path"
    return 1
  }

  canonical_release="$(realpath -- "$release_path")"
  expected_release="$(realpath -m -- "$releases_root/$expected_sha")"
  [[ "$canonical_release" == "$expected_release" ]] || {
    production_error "release path does not match its exact SHA"
    return 1
  }
  [[ "$(git -C "$canonical_release" rev-parse HEAD)" == "$expected_sha" ]] || {
    production_error "release checkout does not match the requested SHA"
    return 1
  }
  [[ -z "$(git -C "$canonical_release" status --porcelain --untracked-files=all)" ]] || {
    production_error "release checkout must be clean before deployment"
    return 1
  }
}

service_container_id() {
  local service="$1"

  docker ps \
    --filter "label=com.docker.compose.project=$COMPOSE_PROJECT_NAME" \
    --filter "label=com.docker.compose.service=$service" \
    --format '{{.ID}}' |
    head -n 1
}

backup_database() {
  local service="$1"
  local database_user="$2"
  local database_name="$3"
  local database_password="$4"
  local destination="$5"
  local temporary_file="$destination.partial"

  [[ ! -e "$destination" && ! -e "$temporary_file" ]] || {
    production_error "refusing to overwrite an existing database backup"
    return 1
  }

  production_compose exec -T \
    --env "PGPASSWORD=$database_password" \
    "$service" \
    pg_dump \
    --username "$database_user" \
    --dbname "$database_name" \
    --format custom |
    gzip --stdout > "$temporary_file"

  [[ -s "$temporary_file" ]] || {
    production_error "database backup is empty for service $service"
    return 1
  }
  gzip --test -- "$temporary_file"
  gzip --decompress --stdout -- "$temporary_file" |
    production_compose exec -T "$service" pg_restore --list >/dev/null

  chmod 0600 -- "$temporary_file"
  mv -- "$temporary_file" "$destination"
}

create_predeploy_backup() {
  local backup_directory="$state_backups_dir/$PRODUCTION_DEPLOYMENT_ID"
  local inventory_backup="$backup_directory/inventory.dump.gz"
  local keycloak_backup="$backup_directory/keycloak.dump.gz"
  local backup_manifest="$backup_directory/manifest.json"
  local inventory_container
  local keycloak_container
  local inventory_checksum=""
  local keycloak_checksum=""
  local backup_status

  [[ ! -e "$backup_directory" ]] || {
    production_error "backup directory already exists for this deployment"
    return 1
  }
  mkdir -p -- "$backup_directory"
  chmod 0700 -- "$backup_directory"

  inventory_container="$(service_container_id postgres)"
  keycloak_container="$(service_container_id keycloak-postgres)"

  if [[ -z "$active_sha" ]]; then
    [[ -z "$inventory_container" && -z "$keycloak_container" ]] || {
      production_error "an unmanaged production database stack is already running"
      return 1
    }
    if docker volume inspect \
      "$COMPOSE_PROJECT_NAME"_postgres-data >/dev/null 2>&1 \
      || docker volume inspect \
        "$COMPOSE_PROJECT_NAME"_keycloak-postgres-data >/dev/null 2>&1; then
      production_error \
        "database volumes exist without release state; manual recovery is required"
      return 1
    fi
    backup_status=NOT_REQUIRED_FIRST_DEPLOYMENT
  else
    [[ -n "$inventory_container" && -n "$keycloak_container" ]] || {
      production_error "both production databases must be running before deployment"
      return 1
    }

    backup_database \
      postgres \
      "$POSTGRES_USER" \
      "$POSTGRES_DB" \
      "$POSTGRES_PASSWORD" \
      "$inventory_backup"
    backup_database \
      keycloak-postgres \
      "$KEYCLOAK_DB_USER" \
      "$KEYCLOAK_DB" \
      "$KEYCLOAK_DB_PASSWORD" \
      "$keycloak_backup"
    inventory_checksum="$(sha256sum -- "$inventory_backup" | awk '{ print $1 }')"
    keycloak_checksum="$(sha256sum -- "$keycloak_backup" | awk '{ print $1 }')"
    backup_status=CREATED
  fi

  write_json_atomically "$backup_manifest" \
    --null-input \
    --arg status "$backup_status" \
    --arg createdAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg deploymentId "$PRODUCTION_DEPLOYMENT_ID" \
    --arg candidateSha "$DEPLOYED_SHA" \
    --arg sourceSha "$active_sha" \
    --arg inventoryFile "$([[ -f "$inventory_backup" ]] && basename -- "$inventory_backup" || true)" \
    --arg inventorySha256 "$inventory_checksum" \
    --arg keycloakFile "$([[ -f "$keycloak_backup" ]] && basename -- "$keycloak_backup" || true)" \
    --arg keycloakSha256 "$keycloak_checksum" \
    '{
      status: $status,
      createdAt: $createdAt,
      deploymentId: $deploymentId,
      candidateSha: $candidateSha,
      sourceSha: (if $sourceSha == "" then null else $sourceSha end),
      databases: {
        inventory: {
          file: (if $inventoryFile == "" then null else $inventoryFile end),
          sha256: (if $inventorySha256 == "" then null else $inventorySha256 end)
        },
        keycloak: {
          file: (if $keycloakFile == "" then null else $keycloakFile end),
          sha256: (if $keycloakSha256 == "" then null else $keycloakSha256 end)
        }
      }
    }'
  write_state_value "$last_backup_file" "$backup_directory"
  created_backup_manifest="$backup_manifest"
}

verify_certificates() {
  local certificate_root="${PRODUCTION_CERTIFICATE_ROOT:-/etc/letsencrypt/live}"
  local certificate_directory="$certificate_root/$TLS_CERTIFICATE_NAME"
  local certificate_file="$certificate_directory/fullchain.pem"
  local private_key_file="$certificate_directory/privkey.pem"
  local certificate_public_key
  local private_public_key

  [[ -s "$certificate_file" && -r "$certificate_file" ]] || {
    production_error "TLS full chain is missing or unreadable"
    return 1
  }
  [[ -s "$private_key_file" && -r "$private_key_file" ]] || {
    production_error "TLS private key is missing or unreadable"
    return 1
  }
  openssl x509 \
    -in "$certificate_file" \
    -noout \
    -checkend "${PRODUCTION_CERTIFICATE_MIN_VALIDITY_SECONDS:-86400}" >/dev/null
  openssl x509 \
    -in "$certificate_file" \
    -noout \
    -checkip "$PRODUCTION_PUBLIC_IP" >/dev/null
  openssl pkey -in "$private_key_file" -noout >/dev/null

  certificate_public_key="$(
    openssl x509 -in "$certificate_file" -pubkey -noout |
      openssl pkey -pubin -outform DER 2>/dev/null |
      sha256sum |
      awk '{ print $1 }'
  )"
  private_public_key="$(
    openssl pkey -in "$private_key_file" -pubout -outform DER 2>/dev/null |
      sha256sum |
      awk '{ print $1 }'
  )"
  [[ -n "$certificate_public_key" \
    && "$certificate_public_key" == "$private_public_key" ]] || {
    production_error "TLS certificate and private key do not match"
    return 1
  }
}

verify_deployed_containers() {
  local service
  local container_id
  local container_sha
  local container_state
  local health_status
  local flyway_id
  local flyway_exit_code
  local flyway_sha
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
    [[ -n "$container_id" ]] || {
      production_error "service has no container after deployment: $service"
      return 1
    }
    container_state="$(docker inspect --format '{{.State.Status}}' "$container_id")"
    [[ "$container_state" == running ]] || {
      production_error "service is not running after deployment: $service"
      return 1
    }
    container_sha="$(
      docker inspect \
        --format '{{index .Config.Labels "com.inventory.sha"}}' \
        "$container_id"
    )"
    [[ "$container_sha" == "$DEPLOYED_SHA" ]] || {
      production_error "service label does not match deployed SHA: $service"
      return 1
    }
  done

  for service in "${healthy_services[@]}"; do
    container_id="$(production_compose ps --quiet "$service")"
    health_status="$(
      docker inspect \
        --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' \
        "$container_id"
    )"
    [[ "$health_status" == healthy ]] || {
      production_error "service healthcheck did not pass: $service"
      return 1
    }
  done

  flyway_id="$(production_compose ps --all --quiet flyway)"
  [[ -n "$flyway_id" ]] || {
    production_error "Flyway migration container is missing"
    return 1
  }
  flyway_exit_code="$(docker inspect --format '{{.State.ExitCode}}' "$flyway_id")"
  [[ "$flyway_exit_code" == 0 ]] || {
    production_error "Flyway migration did not complete successfully"
    return 1
  }
  flyway_sha="$(
    docker inspect \
      --format '{{index .Config.Labels "com.inventory.sha"}}' \
      "$flyway_id"
  )"
  [[ "$flyway_sha" == "$DEPLOYED_SHA" ]] || {
    production_error "Flyway label does not match deployed SHA"
    return 1
  }
}

deployment_failed() {
  local exit_code=$?
  local automatic_rollback_exit_code

  trap - ERR
  set +e
  flock --unlock "$operation_lock_fd"
  env \
    GCP_DEPLOY_PATH="$GCP_DEPLOY_PATH" \
    PRODUCTION_STATE_DIR="$PRODUCTION_STATE_DIR" \
    PRODUCTION_ENV_FILE="$PRODUCTION_ENV_FILE" \
    PRODUCTION_EVIDENCE_DIR="$PRODUCTION_EVIDENCE_DIR" \
    bash "$script_dir/rollback.sh"
  automatic_rollback_exit_code=$?
  write_json_atomically "$deploy_evidence_file" \
    --null-input \
    --arg result FAILURE \
    --arg environment production \
    --arg deploymentId "$PRODUCTION_DEPLOYMENT_ID" \
    --arg requestedSha "$DEPLOYED_SHA" \
    --arg startedAt "$started_at" \
    --arg failedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson exitCode "$exit_code" \
    --argjson automaticRollbackExitCode "$automatic_rollback_exit_code" \
    '{
      result: $result,
      environment: $environment,
      deploymentId: $deploymentId,
      requestedSha: $requestedSha,
      startedAt: $startedAt,
      failedAt: $failedAt,
      exitCode: $exitCode,
      automaticRollbackExitCode: $automaticRollbackExitCode
    }'
  production_error \
    "deployment failed; automatic rollback exit code: $automatic_rollback_exit_code"
  set -e
  exit "$exit_code"
}
trap deployment_failed ERR

deployment_abort() {
  production_error "$1"
  return 1
}

canonical_repository="$(realpath -- "$PRODUCTION_REPOSITORY_ROOT")"
readonly canonical_repository
validate_release "$canonical_repository" "$DEPLOYED_SHA"

active_release=""
active_sha=""
if [[ -e "$current_release_file" || -e "$current_sha_file" ]]; then
  [[ -e "$current_release_file" && -e "$current_sha_file" ]] || {
    deployment_abort "current production release state is incomplete"
  }
  active_release="$(read_state_value "$current_release_file")"
  active_sha="$(read_state_value "$current_sha_file")"
  validate_release "$active_release" "$active_sha"
fi
readonly active_release
readonly active_sha

verify_certificates
"$script_dir/render-keycloak-realm.sh"
production_compose config --quiet
production_compose build backend frontend
docker image inspect "inventory-backend:$DEPLOYED_SHA" >/dev/null
docker image inspect "inventory-frontend:$DEPLOYED_SHA" >/dev/null

created_backup_manifest=""
create_predeploy_backup
readonly backup_manifest="$created_backup_manifest"
write_json_atomically "$pending_deployment_file" \
  --null-input \
  --arg status READY_TO_DEPLOY \
  --arg deploymentId "$PRODUCTION_DEPLOYMENT_ID" \
  --arg candidateRelease "$canonical_repository" \
  --arg candidateSha "$DEPLOYED_SHA" \
  --arg previousRelease "$active_release" \
  --arg previousSha "$active_sha" \
  --arg backupManifest "$backup_manifest" \
  --arg startedAt "$started_at" \
  '{
    status: $status,
    deploymentId: $deploymentId,
    candidate: {
      release: $candidateRelease,
      sha: $candidateSha
    },
    previous: (
      if $previousSha == "" then null
      else {release: $previousRelease, sha: $previousSha}
      end
    ),
    backupManifest: $backupManifest,
    startedAt: $startedAt
  }'

readonly wait_timeout="${PRODUCTION_WAIT_TIMEOUT_SECONDS:-600}"
[[ "$wait_timeout" =~ ^[1-9][0-9]{1,3}$ ]] || {
  deployment_abort \
    "PRODUCTION_WAIT_TIMEOUT_SECONDS must be between 10 and 9999"
}
production_compose up \
  --detach \
  --wait \
  --wait-timeout "$wait_timeout" \
  --no-build \
  --force-recreate \
  --remove-orphans
verify_deployed_containers

if [[ -n "$active_sha" && "$active_sha" != "$DEPLOYED_SHA" ]]; then
  write_state_value "$previous_release_file" "$active_release"
  write_state_value "$previous_sha_file" "$active_sha"
fi
write_state_value "$current_release_file" "$canonical_repository"
write_state_value "$current_sha_file" "$DEPLOYED_SHA"

readonly finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
write_json_atomically "$transaction_file" \
  --null-input \
  --arg result DEPLOYED \
  --arg environment production \
  --arg deploymentId "$PRODUCTION_DEPLOYMENT_ID" \
  --arg requestedSha "$DEPLOYED_SHA" \
  --arg release "$canonical_repository" \
  --arg previousSha "$active_sha" \
  --arg backupManifest "$backup_manifest" \
  --arg startedAt "$started_at" \
  --arg finishedAt "$finished_at" \
  '{
    result: $result,
    environment: $environment,
    deploymentId: $deploymentId,
    requestedSha: $requestedSha,
    release: $release,
    previousSha: (if $previousSha == "" then null else $previousSha end),
    backupManifest: $backupManifest,
    startedAt: $startedAt,
    finishedAt: $finishedAt
  }'
cp -- "$transaction_file" "$deploy_evidence_file"
chmod 0600 -- "$deploy_evidence_file"
rm -f -- "$pending_deployment_file"
trap - ERR

printf 'Production deployment %s is healthy at %s (SHA %s).\n' \
  "$PRODUCTION_DEPLOYMENT_ID" \
  "$PRODUCTION_FRONTEND_URL" \
  "$DEPLOYED_SHA"
