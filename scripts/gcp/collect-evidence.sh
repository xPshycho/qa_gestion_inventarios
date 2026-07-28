#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$script_dir/common.sh"

[[ $# -eq 0 ]] || {
  production_error "usage: scripts/gcp/collect-evidence.sh"
  exit 2
}

for required_command in awk cp date docker git jq mktemp realpath sha256sum; do
  require_command "$required_command"
done
load_production_env
validate_production_evidence_dir
ensure_production_evidence_dir
umask 077

readonly current_release_file="$PRODUCTION_STATE_DIR/current-release"
readonly current_sha_file="$PRODUCTION_STATE_DIR/current-sha"
readonly previous_release_file="$PRODUCTION_STATE_DIR/previous-release"
readonly previous_sha_file="$PRODUCTION_STATE_DIR/previous-sha"
readonly last_backup_file="$PRODUCTION_STATE_DIR/last-predeploy-backup"
readonly collected_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
readonly collections_dir="$PRODUCTION_EVIDENCE_DIR/collections"
mkdir -p -- "$collections_dir"
chmod 0700 -- "$collections_dir"
collection_dir="$(mktemp -d "$collections_dir/collection.XXXXXX")"
readonly collection_dir
chmod 0700 -- "$collection_dir"
readonly collection_id="$(basename -- "$collection_dir")"
readonly compose_ps_file="$collection_dir/compose-ps.txt"
readonly compose_images_file="$collection_dir/compose-images.txt"
readonly compose_log_file="$collection_dir/compose.log"
readonly deployment_file="$collection_dir/deployment.json"
readonly deployment_summary_file="$collection_dir/deployment-summary.md"

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

active_release="$PRODUCTION_REPOSITORY_ROOT"
active_sha="$DEPLOYED_SHA"
if [[ -e "$current_release_file" || -e "$current_sha_file" ]]; then
  [[ -e "$current_release_file" && -e "$current_sha_file" ]] || {
    production_error "current production release state is incomplete"
    exit 1
  }
  active_release="$(read_state_value "$current_release_file")"
  active_sha="$(read_state_value "$current_sha_file")"
fi
readonly active_release
readonly active_sha

[[ "$active_sha" =~ ^[0-9a-f]{40}$ ]] || {
  production_error "active production SHA is invalid"
  exit 1
}
[[ -d "$active_release/.git" && ! -L "$active_release" ]] || {
  production_error "active production release is unavailable"
  exit 1
}
readonly canonical_active_release="$(realpath -- "$active_release")"
[[ "$(git -C "$canonical_active_release" rev-parse HEAD)" == "$active_sha" ]] || {
  production_error "active release checkout does not match production state"
  exit 1
}
[[ -f "$canonical_active_release/docker-compose.yml" \
  && -f "$canonical_active_release/docker-compose.production.yml" ]] || {
  production_error "active release does not contain the production Compose model"
  exit 1
}

evidence_compose() {
  docker compose \
    --env-file "$PRODUCTION_ENV_FILE" \
    --project-name "$COMPOSE_PROJECT_NAME" \
    --file "$canonical_active_release/docker-compose.yml" \
    --file "$canonical_active_release/docker-compose.production.yml" \
    "$@"
}

previous_release=""
previous_sha=""
if [[ -e "$previous_release_file" || -e "$previous_sha_file" ]]; then
  [[ -e "$previous_release_file" && -e "$previous_sha_file" ]] || {
    production_error "previous production release state is incomplete"
    exit 1
  }
  previous_release="$(read_state_value "$previous_release_file")"
  previous_sha="$(read_state_value "$previous_sha_file")"
  [[ "$previous_sha" =~ ^[0-9a-f]{40}$ ]] || {
    production_error "previous production SHA is invalid"
    exit 1
  }
fi
readonly previous_release
readonly previous_sha

if [[ -n "$(git -C "$canonical_active_release" status --porcelain --untracked-files=all)" ]]; then
  readonly worktree_dirty=true
else
  readonly worktree_dirty=false
fi
readonly source_fingerprint="$(
  git -C "$canonical_active_release" archive --format=tar HEAD |
    sha256sum |
    awk '{ print $1 }'
)"
readonly backend_image_id="$(
  docker image inspect \
    --format '{{.Id}}' \
    "inventory-backend:$active_sha" \
    2>/dev/null || true
)"
readonly frontend_image_id="$(
  docker image inspect \
    --format '{{.Id}}' \
    "inventory-frontend:$active_sha" \
    2>/dev/null || true
)"

requested_sha="$(basename -- "$PRODUCTION_EVIDENCE_DIR")"
if [[ ! "$requested_sha" =~ ^[0-9a-f]{40}$ ]]; then
  requested_sha="$DEPLOYED_SHA"
fi
readonly requested_sha

run_url=""
if [[ -n "${GITHUB_SERVER_URL:-}" \
  && -n "${GITHUB_REPOSITORY:-}" \
  && -n "${GITHUB_RUN_ID:-}" ]]; then
  run_url="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
fi
readonly run_url

backup_manifest_path=""
backup_summary=null
if [[ -e "$last_backup_file" ]]; then
  backup_directory="$(read_state_value "$last_backup_file")"
  canonical_backup_directory="$(realpath -m -- "$backup_directory")"
  canonical_backups_root="$(realpath -m -- "$PRODUCTION_STATE_DIR/backups")"
  [[ "$canonical_backup_directory" == "$canonical_backups_root"/* ]] || {
    production_error "last backup pointer escapes the production backup directory"
    exit 1
  }
  backup_manifest_path="$canonical_backup_directory/manifest.json"
  [[ -f "$backup_manifest_path" && ! -L "$backup_manifest_path" ]] || {
    production_error "last predeploy backup manifest is unavailable"
    exit 1
  }
  backup_summary="$(
    jq --compact-output '
      {
        status,
        createdAt,
        deploymentId,
        candidateSha,
        sourceSha,
        databases
      }
    ' "$backup_manifest_path"
  )"
fi
readonly backup_manifest_path
readonly backup_summary

log_tail_lines="${PRODUCTION_LOG_TAIL_LINES:-2000}"
[[ "$log_tail_lines" =~ ^[1-9][0-9]{0,4}$ ]] || {
  production_error "PRODUCTION_LOG_TAIL_LINES must be between 1 and 99999"
  exit 1
}
readonly log_tail_lines

evidence_compose ps --all 2>&1 |
  redact_production_secrets > "$compose_ps_file" || true
evidence_compose images 2>&1 |
  redact_production_secrets > "$compose_images_file" || true
evidence_compose logs \
  --no-color \
  --timestamps \
  --tail "$log_tail_lines" 2>&1 |
  redact_production_secrets > "$compose_log_file" || true

running_services=null
if running_services_output="$(
  evidence_compose ps --services --status running 2>/dev/null
)"; then
  running_services="$(
    awk 'NF { count += 1 } END { print count + 0 }' \
      <<< "$running_services_output"
  )"
fi
readonly running_services

temporary_deployment_file="$(mktemp "$collection_dir/.deployment.XXXXXX")"
readonly temporary_deployment_file
cleanup_temporary_deployment() {
  rm -f -- "$temporary_deployment_file"
}
trap cleanup_temporary_deployment EXIT

jq --null-input \
  --arg collectedAt "$collected_at" \
  --arg collectionId "$collection_id" \
  --arg environment production \
  --arg deploymentId "$PRODUCTION_DEPLOYMENT_ID" \
  --arg requestedSha "$requested_sha" \
  --arg deployedSha "$active_sha" \
  --arg activeRelease "$canonical_active_release" \
  --arg previousSha "$previous_sha" \
  --arg previousRelease "$previous_release" \
  --arg sourceFingerprint "$source_fingerprint" \
  --arg composeProject "$COMPOSE_PROJECT_NAME" \
  --arg frontendUrl "$PRODUCTION_FRONTEND_URL" \
  --arg backendUrl "$PRODUCTION_BACKEND_URL" \
  --arg keycloakUrl "$PRODUCTION_KEYCLOAK_URL" \
  --arg grafanaUrl "$PRODUCTION_GRAFANA_URL" \
  --arg runUrl "$run_url" \
  --arg backendImageId "$backend_image_id" \
  --arg frontendImageId "$frontend_image_id" \
  --arg backupManifest "$backup_manifest_path" \
  --argjson backup "$backup_summary" \
  --argjson runningServices "$running_services" \
  --argjson worktreeDirty "$worktree_dirty" \
  '{
    collectedAt: $collectedAt,
    collectionId: $collectionId,
    environment: $environment,
    deploymentId: $deploymentId,
    requestedSha: $requestedSha,
    deployedSha: $deployedSha,
    activeRelease: $activeRelease,
    previous: (
      if $previousSha == "" then null
      else {sha: $previousSha, release: $previousRelease}
      end
    ),
    source: {
      worktreeDirty: $worktreeDirty,
      fingerprint: $sourceFingerprint
    },
    composeProject: $composeProject,
    runUrl: $runUrl,
    urls: {
      frontend: $frontendUrl,
      backend: $backendUrl,
      keycloak: $keycloakUrl,
      grafana: $grafanaUrl
    },
    images: {
      backend: {
        tag: ("inventory-backend:" + $deployedSha),
        id: $backendImageId
      },
      frontend: {
        tag: ("inventory-frontend:" + $deployedSha),
        id: $frontendImageId
      }
    },
    runningServices: $runningServices,
    predeployBackup: (
      if $backup == null then null
      else ($backup + {manifest: $backupManifest})
      end
    )
  }' > "$temporary_deployment_file"
chmod 0600 -- "$temporary_deployment_file"
mv -- "$temporary_deployment_file" "$deployment_file"
trap - EXIT

{
  printf '# GCP production deployment evidence\n\n'
  printf -- '- Collected at: `%s`\n' "$collected_at"
  printf -- '- Collection: `%s`\n' "$collection_id"
  printf -- '- Environment: `production`\n'
  printf -- '- Deployment ID: `%s`\n' "$PRODUCTION_DEPLOYMENT_ID"
  printf -- '- Requested SHA: `%s`\n' "$requested_sha"
  printf -- '- Active SHA: `%s`\n' "$active_sha"
  printf -- '- Previous SHA: `%s`\n' "${previous_sha:-none}"
  printf -- '- Source worktree dirty: `%s`\n' "$worktree_dirty"
  printf -- '- Source fingerprint: `%s`\n' "$source_fingerprint"
  printf -- '- Frontend URL: `%s`\n' "$PRODUCTION_FRONTEND_URL"
  printf -- '- Backend URL: `%s`\n' "$PRODUCTION_BACKEND_URL"
  printf -- '- Keycloak URL: `%s`\n' "$PRODUCTION_KEYCLOAK_URL"
  printf -- '- Grafana URL: `%s`\n' "$PRODUCTION_GRAFANA_URL"
  printf -- '- Backend image ID: `%s`\n' "${backend_image_id:-unavailable}"
  printf -- '- Frontend image ID: `%s`\n' "${frontend_image_id:-unavailable}"
  if [[ "$running_services" == null ]]; then
    printf -- '- Running services: `unavailable`\n'
  else
    printf -- '- Running services: `%s`\n' "$running_services"
  fi
  if [[ -n "$backup_manifest_path" ]]; then
    printf -- '- Predeploy backup manifest: `%s`\n' "$backup_manifest_path"
  else
    printf -- '- Predeploy backup manifest: `unavailable`\n'
  fi
  if [[ -n "$run_url" ]]; then
    printf -- '- GitHub Actions run: `%s`\n' "$run_url"
  fi
  printf '\nRuntime secrets, database dumps, tokens, rendered realms and Compose configuration are excluded.\n'
} > "$deployment_summary_file"

chmod 0600 -- \
  "$compose_ps_file" \
  "$compose_images_file" \
  "$compose_log_file" \
  "$deployment_file" \
  "$deployment_summary_file"

cp -- "$compose_ps_file" "$PRODUCTION_EVIDENCE_DIR/compose-ps.txt"
cp -- "$compose_images_file" "$PRODUCTION_EVIDENCE_DIR/compose-images.txt"
cp -- "$compose_log_file" "$PRODUCTION_EVIDENCE_DIR/compose.log"
cp -- "$deployment_file" "$PRODUCTION_EVIDENCE_DIR/deployment.json"
cp -- \
  "$deployment_summary_file" \
  "$PRODUCTION_EVIDENCE_DIR/deployment-summary.md"
chmod 0600 -- \
  "$PRODUCTION_EVIDENCE_DIR/compose-ps.txt" \
  "$PRODUCTION_EVIDENCE_DIR/compose-images.txt" \
  "$PRODUCTION_EVIDENCE_DIR/compose.log" \
  "$PRODUCTION_EVIDENCE_DIR/deployment.json" \
  "$PRODUCTION_EVIDENCE_DIR/deployment-summary.md"

printf 'Production evidence collected in %s (%s)\n' \
  "$PRODUCTION_EVIDENCE_DIR" \
  "$collection_id"
