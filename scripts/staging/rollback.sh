#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$script_dir/common.sh"

usage() {
  cat <<'EOF'
Usage: scripts/staging/rollback.sh IMAGE_VERSION

Rolls the backend and frontend back to an image version already present on the
deployment host. A database backup is created before switching images.
EOF
}

[[ $# -eq 1 ]] || {
  usage >&2
  exit 2
}

readonly target_version="$1"
[[ "$target_version" =~ ^[A-Za-z0-9._-]+$ ]] || {
  staging_error "invalid image version: $target_version"
  exit 2
}

require_command docker
load_staging_env

docker image inspect "inventory-backend:$target_version" >/dev/null
docker image inspect "inventory-frontend:$target_version" >/dev/null

readonly current_version="$APP_VERSION"
readonly current_deployment_id="$STAGING_DEPLOYMENT_ID"
readonly rollback_timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
readonly rollback_deployment_id="$current_deployment_id-rollback-$rollback_timestamp"
readonly backup_file="$STAGING_STATE_DIR/backups/pre-rollback-$(date -u +%Y%m%dT%H%M%SZ).dump.gz"
"$script_dir/backup-database.sh" "$backup_file"

restore_current_version_on_error() {
  local original_exit_code=$?
  local failure_directory="$STAGING_EVIDENCE_DIR/rollback-failures/$rollback_timestamp-$target_version"

  trap - ERR
  set +e
  if [[ -d "$STAGING_EVIDENCE_DIR/post-deploy" ]]; then
    mkdir -p -- "$(dirname -- "$failure_directory")"
    mv -- "$STAGING_EVIDENCE_DIR/post-deploy" "$failure_directory"
  fi
  update_staging_env_value APP_VERSION "$current_version"
  update_staging_env_value STAGING_DEPLOYMENT_ID "$current_deployment_id"
  load_staging_env
  staging_compose up \
    --detach \
    --wait \
    --no-build \
    --no-deps \
    backend frontend
  reset_post_deploy_evidence
  "$script_dir/collect-evidence.sh"
  jq --null-input \
    --arg failedVersion "$target_version" \
    --arg restoredVersion "$current_version" \
    --arg failedEvidence "$failure_directory" \
    '{
      result: "ROLLBACK_VALIDATION_FAILED",
      failedVersion: $failedVersion,
      restoredVersion: $restoredVersion,
      failedEvidence: $failedEvidence
    }' > "$STAGING_EVIDENCE_DIR/rollback-failure.json"
  set -e
  exit "$original_exit_code"
}

trap restore_current_version_on_error ERR
reset_post_deploy_evidence
update_staging_env_value APP_VERSION "$target_version"
update_staging_env_value STAGING_DEPLOYMENT_ID "$rollback_deployment_id"
load_staging_env
staging_compose up \
  --detach \
  --wait \
  --no-build \
  --no-deps \
  backend frontend
"$script_dir/post-deploy.sh"
trap - ERR

printf '%s\n' "$current_version" > "$STAGING_STATE_DIR/previous-version"
printf '%s\n' "$target_version" > "$STAGING_STATE_DIR/current-version"
chmod 0600 -- "$STAGING_STATE_DIR/previous-version" "$STAGING_STATE_DIR/current-version"

"$script_dir/collect-evidence.sh"
printf 'Application rolled back from %s to %s\n' "$current_version" "$target_version"
printf 'Pre-rollback database backup: %s\n' "$backup_file"
