#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$script_dir/common.sh"

force=false

usage() {
  cat <<'EOF'
Usage: scripts/staging/init-env.sh [--force]

Creates .staging/staging.env with permissions 0600. Existing environment
variables override generated values. Secrets that are not supplied are generated
with OpenSSL and are never printed. With --force, existing secrets are preserved
unless replacements are explicitly injected.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      force=true
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      staging_error "unknown option: $1"
      usage >&2
      exit 2
      ;;
  esac
  shift
done

require_command git
require_command mktemp
require_command openssl

if [[ -f "$STAGING_ENV_FILE" && "$force" != true ]]; then
  printf 'Reusing staging environment: %s\n' "$STAGING_ENV_FILE"
  exit 0
fi

umask 077
mkdir -p -- "$STAGING_STATE_DIR" "$STAGING_STATE_DIR/keycloak" "$STAGING_EVIDENCE_DIR"
chmod 0700 -- "$STAGING_STATE_DIR" "$STAGING_STATE_DIR/keycloak" "$STAGING_EVIDENCE_DIR"

random_secret() {
  openssl rand -hex 24
}

resolve_secret() {
  local variable_name="$1"
  local injected_value="${!variable_name:-}"
  local existing_value=""

  if [[ -n "$injected_value" ]]; then
    printf '%s' "$injected_value"
    return
  fi

  if [[ "$force" == true && -f "$STAGING_ENV_FILE" ]]; then
    existing_value="$(
      awk -F= -v key="$variable_name" '
        $1 == key {
          sub(/^[^=]*=/, "")
          print
          exit
        }
      ' "$STAGING_ENV_FILE"
    )"
  fi

  if [[ -n "$existing_value" ]]; then
    printf '%s' "$existing_value"
  else
    random_secret
  fi
}

validate_scalar() {
  local variable_name="$1"
  local value="$2"

  [[ "$value" =~ ^[A-Za-z0-9._:/@+-]+$ ]] || {
    staging_error "$variable_name contains unsupported characters"
    staging_error "allowed characters: letters, digits, . _ : / @ + -"
    return 1
  }
}

write_pair() {
  local variable_name="$1"
  local value="$2"
  validate_scalar "$variable_name" "$value"
  printf '%s=%s\n' "$variable_name" "$value" >> "$temporary_env_file"
}

readonly git_sha="$(git -C "$STAGING_REPOSITORY_ROOT" rev-parse --short=12 HEAD)"
readonly generated_at="$(date -u +%Y%m%dT%H%M%SZ)"

readonly app_version="${APP_VERSION:-$git_sha}"
readonly compose_project_name="${COMPOSE_PROJECT_NAME:-inventory-staging-${GITHUB_RUN_ID:-preview}}"
readonly deployment_id="${STAGING_DEPLOYMENT_ID:-$generated_at-$app_version}"
readonly bind_address="${STAGING_BIND_ADDRESS:-127.0.0.1}"
if [[ "${GITHUB_ACTIONS:-false}" == true ]]; then
  readonly default_lifecycle=ephemeral
  readonly default_visibility=runner-private
else
  readonly default_lifecycle=operator-managed
  readonly default_visibility=host-loopback
fi
readonly staging_lifecycle="${STAGING_LIFECYCLE:-$default_lifecycle}"
readonly staging_visibility="${STAGING_VISIBILITY:-$default_visibility}"

readonly frontend_port="${FRONTEND_PORT:-15173}"
readonly backend_port="${BACKEND_PORT:-18082}"
readonly keycloak_port="${KEYCLOAK_PORT:-18081}"
readonly keycloak_management_port="${KEYCLOAK_MANAGEMENT_PORT:-19000}"
readonly prometheus_port="${PROMETHEUS_PORT:-19090}"
readonly grafana_port="${GRAFANA_PORT:-13000}"
readonly alloy_http_port="${ALLOY_HTTP_PORT:-12346}"
readonly loki_port="${LOKI_PORT:-13100}"
readonly tempo_port="${TEMPO_PORT:-13200}"
readonly alertmanager_port="${ALERTMANAGER_PORT:-19093}"

readonly frontend_url="${STAGING_FRONTEND_URL:-http://127.0.0.1:$frontend_port}"
readonly backend_url="${STAGING_BACKEND_URL:-http://127.0.0.1:$backend_port}"
readonly keycloak_url="${STAGING_KEYCLOAK_URL:-http://127.0.0.1:$keycloak_port}"

[[ "$compose_project_name" =~ ^inventory-staging-[a-z0-9][a-z0-9_-]*$ ]] || {
  staging_error "COMPOSE_PROJECT_NAME must start with inventory-staging- and use lowercase safe characters"
  exit 2
}
[[ "$bind_address" == 127.0.0.1 ]] || {
  staging_error "STAGING_BIND_ADDRESS must remain 127.0.0.1"
  exit 2
}
[[ "$frontend_url" == "http://127.0.0.1:$frontend_port" \
  && "$backend_url" == "http://127.0.0.1:$backend_port" \
  && "$keycloak_url" == "http://127.0.0.1:$keycloak_port" ]] || {
  staging_error "staging URLs must match their loopback ports"
  exit 2
}

readonly keycloak_realm="${KEYCLOAK_REALM:-inventory}"
readonly keycloak_client_id="${KEYCLOAK_CLIENT_ID:-inventory-frontend}"
readonly keycloak_admin_client_id="${KEYCLOAK_ADMIN_CLIENT_ID:-inventory-admin-service}"
readonly e2e_admin_username="${E2E_ADMIN_USERNAME:-carlos}"
readonly e2e_operator_username="${E2E_OPERATOR_USERNAME:-edwin}"
readonly e2e_viewer_username="${E2E_VIEWER_USERNAME:-viewer}"
readonly e2e_auditor_username="${E2E_AUDITOR_USERNAME:-auditor}"

[[ "$keycloak_realm" == inventory \
  && "$keycloak_client_id" == inventory-frontend \
  && "$keycloak_admin_client_id" == inventory-admin-service \
  && "$e2e_admin_username" == carlos \
  && "$e2e_operator_username" == edwin \
  && "$e2e_viewer_username" == viewer \
  && "$e2e_auditor_username" == auditor ]] || {
  staging_error "realm, client IDs and E2E usernames are fixed by the seed contract"
  exit 2
}

readonly postgres_password="$(resolve_secret POSTGRES_PASSWORD)"
readonly keycloak_db_password="$(resolve_secret KEYCLOAK_DB_PASSWORD)"
readonly keycloak_admin_password="$(resolve_secret KEYCLOAK_ADMIN_PASSWORD)"
readonly keycloak_admin_client_secret="$(resolve_secret KEYCLOAK_ADMIN_CLIENT_SECRET)"
readonly e2e_admin_password="$(resolve_secret E2E_ADMIN_PASSWORD)"
readonly e2e_operator_password="$(resolve_secret E2E_OPERATOR_PASSWORD)"
readonly e2e_viewer_password="$(resolve_secret E2E_VIEWER_PASSWORD)"
readonly e2e_auditor_password="$(resolve_secret E2E_AUDITOR_PASSWORD)"
readonly grafana_admin_password="$(resolve_secret GRAFANA_ADMIN_PASSWORD)"

temporary_env_file="$(mktemp "$STAGING_STATE_DIR/staging.env.XXXXXX")"
readonly temporary_env_file
cleanup_temporary_env() {
  rm -f -- "$temporary_env_file"
}
trap cleanup_temporary_env EXIT
: > "$temporary_env_file"

write_pair COMPOSE_PROJECT_NAME "$compose_project_name"
write_pair APP_VERSION "$app_version"
write_pair STAGING_DEPLOYMENT_ID "$deployment_id"
write_pair STAGING_LIFECYCLE "$staging_lifecycle"
write_pair STAGING_VISIBILITY "$staging_visibility"
write_pair STAGING_BIND_ADDRESS "$bind_address"
write_pair FRONTEND_PORT "$frontend_port"
write_pair BACKEND_PORT "$backend_port"
write_pair KEYCLOAK_PORT "$keycloak_port"
write_pair KEYCLOAK_MANAGEMENT_PORT "$keycloak_management_port"
write_pair PROMETHEUS_PORT "$prometheus_port"
write_pair GRAFANA_PORT "$grafana_port"
write_pair ALLOY_HTTP_PORT "$alloy_http_port"
write_pair LOKI_PORT "$loki_port"
write_pair TEMPO_PORT "$tempo_port"
write_pair ALERTMANAGER_PORT "$alertmanager_port"
write_pair STAGING_FRONTEND_URL "$frontend_url"
write_pair STAGING_BACKEND_URL "$backend_url"
write_pair STAGING_KEYCLOAK_URL "$keycloak_url"
write_pair POSTGRES_DB "${POSTGRES_DB:-inventory}"
write_pair POSTGRES_USER "${POSTGRES_USER:-inventory_staging}"
write_pair POSTGRES_PASSWORD "$postgres_password"
write_pair KEYCLOAK_DB "${KEYCLOAK_DB:-keycloak}"
write_pair KEYCLOAK_DB_USER "${KEYCLOAK_DB_USER:-keycloak_staging}"
write_pair KEYCLOAK_DB_PASSWORD "$keycloak_db_password"
write_pair KEYCLOAK_ADMIN "${KEYCLOAK_ADMIN:-staging-admin}"
write_pair KEYCLOAK_ADMIN_PASSWORD "$keycloak_admin_password"
write_pair KEYCLOAK_REALM "$keycloak_realm"
write_pair KEYCLOAK_CLIENT_ID "$keycloak_client_id"
write_pair KEYCLOAK_ADMIN_CLIENT_ID "$keycloak_admin_client_id"
write_pair KEYCLOAK_ADMIN_CLIENT_SECRET "$keycloak_admin_client_secret"
write_pair KEYCLOAK_IMPORT_DIR .staging/keycloak
write_pair E2E_ADMIN_USERNAME "$e2e_admin_username"
write_pair E2E_ADMIN_PASSWORD "$e2e_admin_password"
write_pair E2E_OPERATOR_USERNAME "$e2e_operator_username"
write_pair E2E_OPERATOR_PASSWORD "$e2e_operator_password"
write_pair E2E_VIEWER_USERNAME "$e2e_viewer_username"
write_pair E2E_VIEWER_PASSWORD "$e2e_viewer_password"
write_pair E2E_AUDITOR_USERNAME "$e2e_auditor_username"
write_pair E2E_AUDITOR_PASSWORD "$e2e_auditor_password"
write_pair GRAFANA_ADMIN_USER "${GRAFANA_ADMIN_USER:-staging-admin}"
write_pair GRAFANA_ADMIN_PASSWORD "$grafana_admin_password"
write_pair INVENTORY_CORS_ALLOWED_ORIGINS "${INVENTORY_CORS_ALLOWED_ORIGINS:-$frontend_url}"
write_pair OTEL_SDK_DISABLED "${OTEL_SDK_DISABLED:-false}"
write_pair OTEL_DEPLOYMENT_ENVIRONMENT staging

chmod 0600 -- "$temporary_env_file"
load_staging_env_file "$temporary_env_file"
mv -- "$temporary_env_file" "$STAGING_ENV_FILE"
trap - EXIT

printf 'Staging environment created: %s\n' "$STAGING_ENV_FILE"
printf 'Version: %s\n' "$app_version"
printf 'Frontend: %s\n' "$frontend_url"
printf 'Backend diagnostics: %s\n' "$backend_url"
printf 'Keycloak: %s\n' "$keycloak_url"
