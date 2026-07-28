#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$script_dir/common.sh"

require_command docker
require_command jq
load_staging_env
ensure_evidence_dir

readonly output_dir="$STAGING_EVIDENCE_DIR/post-deploy/integration"
mkdir -p -- "$output_dir"
chmod 0700 -- "$output_dir"

readonly expected_running_services=(
  alertmanager
  alloy
  backend
  frontend
  grafana
  keycloak
  keycloak-postgres
  loki
  postgres
  prometheus
  tempo
)

mapfile -t running_services < <(
  staging_compose ps --services --status running | sort
)

if [[ "${running_services[*]}" != "${expected_running_services[*]}" ]]; then
  staging_error "unexpected running service set"
  staging_error "expected: ${expected_running_services[*]}"
  staging_error "actual:   ${running_services[*]}"
  exit 1
fi

readonly flyway_container_id="$(staging_compose ps --all --quiet flyway)"
[[ -n "$flyway_container_id" ]] || {
  staging_error "Flyway container was not found"
  exit 1
}

readonly flyway_exit_code="$(
  docker inspect --format '{{.State.ExitCode}}' "$flyway_container_id"
)"
[[ "$flyway_exit_code" == 0 ]] || {
  staging_error "Flyway exited with code $flyway_exit_code"
  exit 1
}

database_scalar() {
  local query="$1"
  staging_compose exec --no-TTY \
    --env "PGPASSWORD=$POSTGRES_PASSWORD" \
    postgres \
    psql \
    --username "$POSTGRES_USER" \
    --dbname "$POSTGRES_DB" \
    --tuples-only \
    --no-align \
    --command "$query"
}

readonly migration_failures="$(
  database_scalar \
    'SELECT COUNT(*) FROM flyway_schema_history WHERE success = FALSE;'
)"
readonly latest_migration="$(
  database_scalar \
    "SELECT COALESCE(version, 'none') FROM flyway_schema_history WHERE success = TRUE ORDER BY installed_rank DESC LIMIT 1;"
)"
readonly product_count="$(database_scalar 'SELECT COUNT(*) FROM products;')"
readonly user_count="$(database_scalar 'SELECT COUNT(*) FROM inventory_users;')"

[[ "$migration_failures" == 0 ]] || {
  staging_error "Flyway schema history contains failed migrations"
  exit 1
}
[[ "$latest_migration" != none ]] || {
  staging_error "No successful Flyway migration was found"
  exit 1
}
(( product_count >= 4 )) || {
  staging_error "Expected seeded products, found $product_count"
  exit 1
}
(( user_count >= 4 )) || {
  staging_error "Expected seeded users, found $user_count"
  exit 1
}

staging_compose ps --all > "$output_dir/compose-ps.txt"

jq --null-input \
  --arg checkedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg deploymentId "$STAGING_DEPLOYMENT_ID" \
  --arg version "$APP_VERSION" \
  --arg lifecycle "$STAGING_LIFECYCLE" \
  --arg visibility "$STAGING_VISIBILITY" \
  --arg latestMigration "$latest_migration" \
  --argjson flywayExitCode "$flyway_exit_code" \
  --argjson migrationFailures "$migration_failures" \
  --argjson products "$product_count" \
  --argjson users "$user_count" \
  --argjson runningServices "${#running_services[@]}" \
  '{
    result: "PASS",
    checkedAt: $checkedAt,
    environment: "staging",
    lifecycle: $lifecycle,
    visibility: $visibility,
    deploymentId: $deploymentId,
    version: $version,
    compose: {
      runningServices: $runningServices,
      flywayExitCode: $flywayExitCode
    },
    database: {
      latestMigration: $latestMigration,
      failedMigrations: $migrationFailures,
      seededProducts: $products,
      seededUsers: $users
    }
  }' > "$output_dir/results.json"

printf 'Staging integration verification passed (%s services, migration %s).\n' \
  "${#running_services[@]}" \
  "$latest_migration"
