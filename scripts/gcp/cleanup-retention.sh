#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$script_dir/common.sh"

[[ $# -eq 0 ]] || {
  production_error "usage: scripts/gcp/cleanup-retention.sh"
  exit 2
}

for required_command in basename chmod docker find flock realpath rm; do
  require_command "$required_command"
done

umask 077

readonly deployment_root="${GCP_DEPLOY_PATH:?GCP_DEPLOY_PATH is required}"
readonly releases_root="$deployment_root/releases"
readonly state_root="${PRODUCTION_STATE_DIR:?PRODUCTION_STATE_DIR is required}"
readonly backups_root="$state_root/backups"
readonly evidence_root="$state_root/evidence"
readonly current_release_file="$state_root/current-release"
readonly current_sha_file="$state_root/current-sha"
readonly previous_release_file="$state_root/previous-release"
readonly previous_sha_file="$state_root/previous-sha"
readonly last_backup_file="$state_root/last-predeploy-backup"
readonly operation_lock_file="$state_root/operation.lock"

[[ "$deployment_root" == /* && "$deployment_root" != / ]] || {
  production_error "GCP_DEPLOY_PATH must be an absolute non-root directory"
  exit 1
}
[[ "$state_root" == "$deployment_root/shared" ]] || {
  production_error "PRODUCTION_STATE_DIR must equal GCP_DEPLOY_PATH/shared"
  exit 1
}

for managed_root in \
  "$deployment_root" \
  "$releases_root" \
  "$state_root" \
  "$backups_root" \
  "$evidence_root"; do
  [[ -d "$managed_root" && ! -L "$managed_root" ]] || {
    production_error "managed retention directory is invalid: $managed_root"
    exit 1
  }
done

exec {operation_lock_fd}> "$operation_lock_file"
chmod 0600 -- "$operation_lock_file"
flock --exclusive --nonblock "$operation_lock_fd" || {
  production_error "another production deploy, rollback or cleanup operation is active"
  exit 1
}

read_state_value() {
  local state_file="$1"
  local -a lines=()

  [[ -f "$state_file" && ! -L "$state_file" ]] || {
    production_error "production state file is invalid: $state_file"
    return 1
  }
  mapfile -t lines < "$state_file"
  [[ "${#lines[@]}" -eq 1 && -n "${lines[0]}" ]] || {
    production_error "production state file must contain one non-empty line"
    return 1
  }
  printf '%s' "${lines[0]}"
}

validate_release_reference() {
  local release_path="$1"
  local release_sha="$2"
  local canonical_release
  local expected_release

  [[ "$release_sha" =~ ^[0-9a-f]{40}$ ]] || {
    production_error "retained release SHA is invalid"
    return 1
  }
  [[ -d "$release_path" && ! -L "$release_path" ]] || {
    production_error "retained release directory is invalid: $release_path"
    return 1
  }
  canonical_release="$(realpath -- "$release_path")"
  expected_release="$(realpath -m -- "$releases_root/$release_sha")"
  [[ "$canonical_release" == "$expected_release" ]] || {
    production_error "retained release path does not match its SHA"
    return 1
  }
}

current_release="$(read_state_value "$current_release_file")"
current_sha="$(read_state_value "$current_sha_file")"
readonly current_release
readonly current_sha
validate_release_reference "$current_release" "$current_sha"

previous_release=""
previous_sha=""
if [[ -e "$previous_release_file" || -e "$previous_sha_file" ]]; then
  [[ -e "$previous_release_file" && -e "$previous_sha_file" ]] || {
    production_error "previous production release state is incomplete"
    exit 1
  }
  previous_release="$(read_state_value "$previous_release_file")"
  previous_sha="$(read_state_value "$previous_sha_file")"
  validate_release_reference "$previous_release" "$previous_sha"
fi
readonly previous_release
readonly previous_sha

declare -A retained_shas=(
  ["$current_sha"]=true
)
if [[ -n "$previous_sha" ]]; then
  retained_shas["$previous_sha"]=true
fi

removed_releases=0
while IFS= read -r -d '' release_path; do
  [[ ! -L "$release_path" ]] || {
    production_error "refusing to process symbolic release entry: $release_path"
    exit 1
  }
  [[ -d "$release_path" ]] || continue
  release_sha="$(basename -- "$release_path")"
  if [[ ! "$release_sha" =~ ^[0-9a-f]{40}$ ]]; then
    production_error "leaving unmanaged release entry untouched: $release_path"
    continue
  fi
  [[ -z "${retained_shas[$release_sha]:-}" ]] || continue
  [[ "$(realpath -- "$release_path")" == "$(realpath -m -- "$releases_root/$release_sha")" ]] || {
    production_error "release cleanup target escapes the releases directory"
    exit 1
  }
  rm -rf -- "$release_path"
  removed_releases=$((removed_releases + 1))
done < <(find "$releases_root" -mindepth 1 -maxdepth 1 -print0)

removed_evidence=0
while IFS= read -r -d '' evidence_path; do
  [[ ! -L "$evidence_path" ]] || {
    production_error "refusing to process symbolic evidence entry: $evidence_path"
    exit 1
  }
  [[ -d "$evidence_path" ]] || continue
  evidence_sha="$(basename -- "$evidence_path")"
  if [[ ! "$evidence_sha" =~ ^[0-9a-f]{40}$ ]]; then
    production_error "leaving unmanaged evidence entry untouched: $evidence_path"
    continue
  fi
  [[ -z "${retained_shas[$evidence_sha]:-}" ]] || continue
  [[ "$(realpath -- "$evidence_path")" == "$(realpath -m -- "$evidence_root/$evidence_sha")" ]] || {
    production_error "evidence cleanup target escapes the evidence directory"
    exit 1
  }
  rm -rf -- "$evidence_path"
  removed_evidence=$((removed_evidence + 1))
done < <(find "$evidence_root" -mindepth 1 -maxdepth 1 -print0)

removed_backups=0
if [[ -e "$last_backup_file" ]]; then
  latest_backup="$(read_state_value "$last_backup_file")"
  [[ -d "$latest_backup" && ! -L "$latest_backup" ]] || {
    production_error "last predeploy backup directory is invalid"
    exit 1
  }
  canonical_latest_backup="$(realpath -- "$latest_backup")"
  canonical_backups_root="$(realpath -- "$backups_root")"
  [[ "$canonical_latest_backup" == "$canonical_backups_root"/* ]] || {
    production_error "last predeploy backup escapes the backup directory"
    exit 1
  }

  while IFS= read -r -d '' backup_path; do
    [[ ! -L "$backup_path" ]] || {
      production_error "refusing to process symbolic backup entry: $backup_path"
      exit 1
    }
    [[ -d "$backup_path" ]] || continue
    [[ "$(realpath -- "$backup_path")" != "$canonical_latest_backup" ]] || continue
    rm -rf -- "$backup_path"
    removed_backups=$((removed_backups + 1))
  done < <(find "$backups_root" -mindepth 1 -maxdepth 1 -print0)
else
  production_error "last backup pointer is absent; old backups were left untouched"
fi

image_listing="$(docker image ls --format '{{.Repository}} {{.Tag}}')"
removed_image_tags=0
while read -r image_repository image_tag; do
  case "$image_repository" in
    inventory-backend|inventory-frontend) ;;
    *) continue ;;
  esac
  [[ "$image_tag" =~ ^[0-9a-f]{40}$ ]] || continue
  [[ -z "${retained_shas[$image_tag]:-}" ]] || continue
  docker image rm "$image_repository:$image_tag"
  removed_image_tags=$((removed_image_tags + 1))
done <<< "$image_listing"

docker image prune --force
docker builder prune --force

while IFS= read -r -d '' temporary_file; do
  rm -f -- "$temporary_file"
done < <(
  find /tmp \
    -mindepth 1 \
    -maxdepth 1 \
    -type f \
    -mtime +0 \
    \( \
      -name 'inventory-*.bundle' \
      -o -name 'inventory-*.sha256' \
      -o -name 'bootstrap-*.sh' \
      -o -name 'runner-evidence-*.tar.gz' \
      -o -name 'production-evidence-*.tar.gz' \
      -o -name 'production-evidence-*.tar.gz.sha256' \
    \) \
    -print0
)

printf \
  'Production retention complete: releases=%s evidence=%s backups=%s image-tags=%s; retained=%s%s.\n' \
  "$removed_releases" \
  "$removed_evidence" \
  "$removed_backups" \
  "$removed_image_tags" \
  "$current_sha" \
  "${previous_sha:+,$previous_sha}"
