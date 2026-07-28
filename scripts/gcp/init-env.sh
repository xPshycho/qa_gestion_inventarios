#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$script_dir/common.sh"

force=false

usage() {
  cat <<'EOF'
Usage: scripts/gcp/init-env.sh [--force]

Creates the production environment with permissions 0600. Existing environment
variables override generated values. Secrets that are not supplied are generated
with OpenSSL and are never printed. With --force, existing secrets are preserved
unless replacements are explicitly injected.

Set PRODUCTION_STATE_DIR, PRODUCTION_ENV_FILE and PRODUCTION_EVIDENCE_DIR before
running the script when production state must live outside the current release.
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
      production_error "unknown option: $1"
      usage >&2
      exit 2
      ;;
  esac
  shift
done

require_command date
require_command git
require_command mktemp
require_command openssl

if [[ -f "$PRODUCTION_ENV_FILE" && "$force" != true ]]; then
  chmod 0600 -- "$PRODUCTION_ENV_FILE"
  load_production_env
  printf 'Reusing production environment: %s\n' "$PRODUCTION_ENV_FILE"
  exit 0
fi

umask 077
mkdir -p -- "$PRODUCTION_STATE_DIR" "$PRODUCTION_STATE_DIR/keycloak" "$PRODUCTION_EVIDENCE_DIR"
chmod 0700 -- "$PRODUCTION_STATE_DIR" "$PRODUCTION_STATE_DIR/keycloak" "$PRODUCTION_EVIDENCE_DIR"

random_secret() {
  openssl rand -hex 32
}

resolve_secret() {
  local variable_name="$1"
  local injected_value="${!variable_name:-}"
  local existing_value=""

  if [[ -n "$injected_value" ]]; then
    printf '%s' "$injected_value"
    return
  fi

  if [[ "$force" == true && -f "$PRODUCTION_ENV_FILE" ]]; then
    existing_value="$(
      awk -F= -v key="$variable_name" '
        $1 == key {
          sub(/^[^=]*=/, "")
          print
          exit
        }
      ' "$PRODUCTION_ENV_FILE"
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
    production_error "$variable_name contains unsupported characters"
    production_error "allowed characters: letters, digits, . _ : / @ + -"
    return 1
  }
}

write_pair() {
  local variable_name="$1"
  local value="$2"
  validate_scalar "$variable_name" "$value"
  printf '%s=%s\n' "$variable_name" "$value" >> "$temporary_env_file"
}

readonly git_sha="$(git -C "$PRODUCTION_REPOSITORY_ROOT" rev-parse HEAD)"
readonly generated_at="$(date -u +%Y%m%dT%H%M%SZ)"
readonly app_version="${APP_VERSION:-$git_sha}"
readonly deployed_sha="${DEPLOYED_SHA:-$app_version}"
readonly deployment_id="${PRODUCTION_DEPLOYMENT_ID:-${GITHUB_RUN_ID:-manual}-${GITHUB_RUN_ATTEMPT:-1}-$generated_at}"
readonly public_ip="${PRODUCTION_PUBLIC_IP:-34.123.136.144}"
readonly origin="${PRODUCTION_ORIGIN:-https://$public_ip}"
readonly frontend_url="${PRODUCTION_FRONTEND_URL:-$origin}"
readonly backend_url="${PRODUCTION_BACKEND_URL:-$origin/api}"
readonly keycloak_url="${PRODUCTION_KEYCLOAK_URL:-$origin/auth}"
readonly grafana_url="${PRODUCTION_GRAFANA_URL:-$origin/grafana}"
readonly tls_certificate_name="${TLS_CERTIFICATE_NAME:-$public_ip}"

readonly keycloak_realm="${KEYCLOAK_REALM:-inventory}"
readonly keycloak_client_id="${KEYCLOAK_CLIENT_ID:-inventory-frontend}"
readonly keycloak_admin_client_id="${KEYCLOAK_ADMIN_CLIENT_ID:-inventory-admin-service}"
readonly e2e_admin_username="${E2E_ADMIN_USERNAME:-carlos}"
readonly e2e_operator_username="${E2E_OPERATOR_USERNAME:-edwin}"
readonly e2e_viewer_username="${E2E_VIEWER_USERNAME:-viewer}"
readonly e2e_auditor_username="${E2E_AUDITOR_USERNAME:-auditor}"

readonly postgres_password="$(resolve_secret POSTGRES_PASSWORD)"
readonly keycloak_db_password="$(resolve_secret KEYCLOAK_DB_PASSWORD)"
readonly keycloak_admin_password="$(resolve_secret KEYCLOAK_ADMIN_PASSWORD)"
readonly keycloak_admin_client_secret="$(resolve_secret KEYCLOAK_ADMIN_CLIENT_SECRET)"
readonly e2e_admin_password="$(resolve_secret E2E_ADMIN_PASSWORD)"
readonly e2e_operator_password="$(resolve_secret E2E_OPERATOR_PASSWORD)"
readonly e2e_viewer_password="$(resolve_secret E2E_VIEWER_PASSWORD)"
readonly e2e_auditor_password="$(resolve_secret E2E_AUDITOR_PASSWORD)"
readonly grafana_admin_password="$(resolve_secret GRAFANA_ADMIN_PASSWORD)"

if [[ "$PRODUCTION_STATE_DIR" == "$PRODUCTION_REPOSITORY_ROOT/.production" ]]; then
  readonly default_keycloak_import_dir=.production/keycloak
else
  readonly default_keycloak_import_dir="$PRODUCTION_STATE_DIR/keycloak"
fi
readonly keycloak_import_dir="${KEYCLOAK_IMPORT_DIR:-$default_keycloak_import_dir}"

temporary_env_file="$(mktemp "$PRODUCTION_STATE_DIR/production.env.XXXXXX")"
readonly temporary_env_file
cleanup_temporary_env() {
  rm -f -- "$temporary_env_file"
}
trap cleanup_temporary_env EXIT
: > "$temporary_env_file"

write_pair COMPOSE_PROJECT_NAME inventory-production
write_pair APP_VERSION "$app_version"
write_pair DEPLOYED_SHA "$deployed_sha"
write_pair PRODUCTION_DEPLOYMENT_ID "$deployment_id"
write_pair PRODUCTION_PUBLIC_IP "$public_ip"
write_pair PRODUCTION_ORIGIN "$origin"
write_pair PRODUCTION_FRONTEND_URL "$frontend_url"
write_pair PRODUCTION_BACKEND_URL "$backend_url"
write_pair PRODUCTION_KEYCLOAK_URL "$keycloak_url"
write_pair PRODUCTION_GRAFANA_URL "$grafana_url"
write_pair TLS_CERTIFICATE_NAME "$tls_certificate_name"
write_pair POSTGRES_DB "${POSTGRES_DB:-inventory}"
write_pair POSTGRES_USER "${POSTGRES_USER:-inventory_production}"
write_pair POSTGRES_PASSWORD "$postgres_password"
write_pair KEYCLOAK_DB "${KEYCLOAK_DB:-keycloak}"
write_pair KEYCLOAK_DB_USER "${KEYCLOAK_DB_USER:-keycloak_production}"
write_pair KEYCLOAK_DB_PASSWORD "$keycloak_db_password"
write_pair KEYCLOAK_ADMIN "${KEYCLOAK_ADMIN:-production-admin}"
write_pair KEYCLOAK_ADMIN_PASSWORD "$keycloak_admin_password"
write_pair KEYCLOAK_REALM "$keycloak_realm"
write_pair KEYCLOAK_CLIENT_ID "$keycloak_client_id"
write_pair KEYCLOAK_ADMIN_CLIENT_ID "$keycloak_admin_client_id"
write_pair KEYCLOAK_ADMIN_CLIENT_SECRET "$keycloak_admin_client_secret"
write_pair KEYCLOAK_IMPORT_DIR "$keycloak_import_dir"
write_pair E2E_ADMIN_USERNAME "$e2e_admin_username"
write_pair E2E_ADMIN_PASSWORD "$e2e_admin_password"
write_pair E2E_OPERATOR_USERNAME "$e2e_operator_username"
write_pair E2E_OPERATOR_PASSWORD "$e2e_operator_password"
write_pair E2E_VIEWER_USERNAME "$e2e_viewer_username"
write_pair E2E_VIEWER_PASSWORD "$e2e_viewer_password"
write_pair E2E_AUDITOR_USERNAME "$e2e_auditor_username"
write_pair E2E_AUDITOR_PASSWORD "$e2e_auditor_password"
write_pair GRAFANA_ADMIN_USER "${GRAFANA_ADMIN_USER:-production-admin}"
write_pair GRAFANA_ADMIN_PASSWORD "$grafana_admin_password"
write_pair INVENTORY_CORS_ALLOWED_ORIGINS "${INVENTORY_CORS_ALLOWED_ORIGINS:-$origin}"
write_pair OTEL_SDK_DISABLED "${OTEL_SDK_DISABLED:-false}"
write_pair OTEL_DEPLOYMENT_ENVIRONMENT production

chmod 0600 -- "$temporary_env_file"
load_production_env_file "$temporary_env_file"
mv -- "$temporary_env_file" "$PRODUCTION_ENV_FILE"
trap - EXIT

printf 'Production environment created: %s\n' "$PRODUCTION_ENV_FILE"
printf 'Deployment: %s\n' "$deployment_id"
printf 'SHA: %s\n' "$deployed_sha"
printf 'Application: %s\n' "$frontend_url"
printf 'Backend: %s\n' "$backend_url"
printf 'Keycloak: %s\n' "$keycloak_url"
printf 'Grafana: %s\n' "$grafana_url"
