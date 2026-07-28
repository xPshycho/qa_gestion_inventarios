#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$script_dir/common.sh"

usage() {
  cat <<'EOF'
Usage: scripts/staging/restore-database.sh BACKUP.dump.gz --confirm

Stops the application services, restores an explicit PostgreSQL backup and starts
the application again. This is destructive and requires the --confirm flag.
EOF
}

[[ $# -eq 2 && "$2" == "--confirm" ]] || {
  usage >&2
  exit 2
}

readonly backup_file="$1"
[[ -f "$backup_file" && -s "$backup_file" ]] || {
  staging_error "backup does not exist or is empty: $backup_file"
  exit 1
}

require_command gzip
load_staging_env

gzip --test -- "$backup_file"
gzip --decompress --stdout -- "$backup_file" |
  staging_compose exec -T postgres pg_restore --list >/dev/null

readonly safety_backup="$STAGING_STATE_DIR/backups/pre-restore-$(date -u +%Y%m%dT%H%M%SZ).dump.gz"
"$script_dir/backup-database.sh" "$safety_backup"

restart_application() {
  staging_compose up \
    --detach \
    --wait \
    --no-build \
    --no-deps \
    backend frontend
}

trap restart_application EXIT
staging_compose stop backend frontend

printf '%s\n' \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = :'database_name' AND pid <> pg_backend_pid();" \
  'DROP DATABASE :"database_name";' \
  'CREATE DATABASE :"database_name" OWNER :"database_owner";' |
  staging_compose exec -T \
    --env "PGPASSWORD=$POSTGRES_PASSWORD" \
    postgres \
    psql \
    --username "$POSTGRES_USER" \
    --dbname postgres \
    --set ON_ERROR_STOP=1 \
    --set "database_name=$POSTGRES_DB" \
    --set "database_owner=$POSTGRES_USER"

gzip --decompress --stdout -- "$backup_file" |
  staging_compose exec -T \
    --env "PGPASSWORD=$POSTGRES_PASSWORD" \
    postgres \
    pg_restore \
    --username "$POSTGRES_USER" \
    --dbname "$POSTGRES_DB" \
    --clean \
    --if-exists \
    --no-owner \
    --exit-on-error

restart_application
trap - EXIT
"$script_dir/verify-integration.sh"

printf 'Database restored from %s\n' "$backup_file"
