#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$script_dir/common.sh"

require_command gzip
require_command mktemp
load_staging_env

readonly backup_dir="$STAGING_STATE_DIR/backups"
readonly timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
readonly backup_file="${1:-$backup_dir/inventory-$timestamp.dump.gz}"

[[ $# -le 1 ]] || {
  staging_error "usage: scripts/staging/backup-database.sh [${backup_dir}/NAME.dump.gz]"
  exit 2
}
[[ "$(dirname -- "$backup_file")" == "$backup_dir" \
  && "$(basename -- "$backup_file")" == *.dump.gz ]] || {
  staging_error "backup destination must be a .dump.gz file directly inside $backup_dir"
  exit 2
}
[[ ! -e "$backup_file" ]] || {
  staging_error "refusing to overwrite an existing backup: $backup_file"
  exit 1
}

mkdir -p -- "$backup_dir"
chmod 0700 -- "$backup_dir"
umask 077
temporary_file="$(mktemp "$backup_dir/.inventory-backup.XXXXXX")"
readonly temporary_file
cleanup_temporary_backup() {
  rm -f -- "$temporary_file"
}
trap cleanup_temporary_backup EXIT

staging_compose exec -T \
  --env "PGPASSWORD=$POSTGRES_PASSWORD" \
  postgres \
  pg_dump \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --format custom |
  gzip --stdout > "$temporary_file"

[[ -s "$temporary_file" ]] || {
  staging_error "database backup is empty"
  exit 1
}
gzip --test -- "$temporary_file"

chmod 0600 -- "$temporary_file"
mv -- "$temporary_file" "$backup_file"
trap - EXIT
printf 'Database backup created: %s\n' "$backup_file"
