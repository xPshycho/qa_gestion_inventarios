#!/usr/bin/env bash

set -Eeuo pipefail

readonly repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly cleanup_script="$repository_root/scripts/gcp/cleanup-retention.sh"
readonly test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT

readonly deployment_root="$test_root/opt/inventory"
readonly state_root="$deployment_root/shared"
readonly releases_root="$deployment_root/releases"
readonly backups_root="$state_root/backups"
readonly evidence_root="$state_root/evidence"
readonly fake_bin="$test_root/bin"
readonly docker_log="$test_root/docker.log"
readonly current_sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
readonly previous_sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
readonly obsolete_sha=cccccccccccccccccccccccccccccccccccccccc

mkdir -p \
  "$releases_root/$current_sha/.git" \
  "$releases_root/$previous_sha/.git" \
  "$releases_root/$obsolete_sha/.git" \
  "$releases_root/manual-entry" \
  "$backups_root/latest" \
  "$backups_root/obsolete" \
  "$evidence_root/$current_sha" \
  "$evidence_root/$previous_sha" \
  "$evidence_root/$obsolete_sha" \
  "$fake_bin"

printf '%s\n' "$releases_root/$current_sha" > "$state_root/current-release"
printf '%s\n' "$current_sha" > "$state_root/current-sha"
printf '%s\n' "$releases_root/$previous_sha" > "$state_root/previous-release"
printf '%s\n' "$previous_sha" > "$state_root/previous-sha"
printf '%s\n' "$backups_root/latest" > "$state_root/last-predeploy-backup"

cat > "$fake_bin/docker" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "${DOCKER_LOG:?}"
if [[ "$*" == "image ls --format {{.Repository}} {{.Tag}}" ]]; then
  printf '%s\n' "unrelated latest"
  printf 'inventory-backend %s\n' "${CURRENT_SHA:?}"
  printf 'inventory-frontend %s\n' "${CURRENT_SHA:?}"
  printf 'inventory-backend %s\n' "${PREVIOUS_SHA:?}"
  printf 'inventory-frontend %s\n' "${PREVIOUS_SHA:?}"
  printf 'inventory-backend %s\n' "${OBSOLETE_SHA:?}"
  printf 'inventory-frontend %s\n' "${OBSOLETE_SHA:?}"
fi
EOF
chmod 0700 "$fake_bin/docker"

export CURRENT_SHA="$current_sha"
export DOCKER_LOG="$docker_log"
export GCP_DEPLOY_PATH="$deployment_root"
export OBSOLETE_SHA="$obsolete_sha"
export PATH="$fake_bin:$PATH"
export PREVIOUS_SHA="$previous_sha"
export PRODUCTION_STATE_DIR="$state_root"

"$cleanup_script"

test -d "$releases_root/$current_sha"
test -d "$releases_root/$previous_sha"
test ! -e "$releases_root/$obsolete_sha"
test -d "$releases_root/manual-entry"

test -d "$evidence_root/$current_sha"
test -d "$evidence_root/$previous_sha"
test ! -e "$evidence_root/$obsolete_sha"

test -d "$backups_root/latest"
test ! -e "$backups_root/obsolete"

grep -Fx "image rm inventory-backend:$obsolete_sha" "$docker_log"
grep -Fx "image rm inventory-frontend:$obsolete_sha" "$docker_log"
grep -Fx "image prune --force" "$docker_log"
grep -Fx "builder prune --force" "$docker_log"
! grep -F "$current_sha" "$docker_log" | grep -F "image rm"
! grep -F "$previous_sha" "$docker_log" | grep -F "image rm"
! grep -F "volume" "$docker_log"

ln -s "$test_root/outside" \
  "$releases_root/dddddddddddddddddddddddddddddddddddddddd"
if "$cleanup_script"; then
  printf 'Retention cleanup accepted a symbolic release entry.\n' >&2
  exit 1
fi
test -L "$releases_root/dddddddddddddddddddddddddddddddddddddddd"

printf 'GCP production retention tests passed.\n'
