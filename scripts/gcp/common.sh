#!/usr/bin/env bash

set -Eeuo pipefail

readonly PRODUCTION_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PRODUCTION_REPOSITORY_ROOT="$(cd -- "$PRODUCTION_SCRIPT_DIR/../.." && pwd)"
readonly PRODUCTION_STATE_DIR="${PRODUCTION_STATE_DIR:-$PRODUCTION_REPOSITORY_ROOT/.production}"
readonly PRODUCTION_ENV_FILE="${PRODUCTION_ENV_FILE:-$PRODUCTION_STATE_DIR/production.env}"
readonly PRODUCTION_EVIDENCE_DIR="${PRODUCTION_EVIDENCE_DIR:-$PRODUCTION_STATE_DIR/evidence}"
readonly PRODUCTION_COMPOSE_FILE="$PRODUCTION_REPOSITORY_ROOT/docker-compose.yml"
readonly PRODUCTION_COMPOSE_OVERLAY="$PRODUCTION_REPOSITORY_ROOT/docker-compose.production.yml"

production_error() {
  printf 'production: %s\n' "$*" >&2
}

redact_production_secrets() {
  local encoded_value
  local line
  local secret
  local secrets=(
    "${POSTGRES_PASSWORD:-}"
    "${KEYCLOAK_DB_PASSWORD:-}"
    "${KEYCLOAK_ADMIN_PASSWORD:-}"
    "${KEYCLOAK_ADMIN_CLIENT_SECRET:-}"
    "${E2E_ADMIN_PASSWORD:-}"
    "${E2E_OPERATOR_PASSWORD:-}"
    "${E2E_VIEWER_PASSWORD:-}"
    "${E2E_AUDITOR_PASSWORD:-}"
    "${GRAFANA_ADMIN_PASSWORD:-}"
  )
  local credential_pairs=(
    "${E2E_ADMIN_USERNAME:-}:${E2E_ADMIN_PASSWORD:-}"
    "${E2E_OPERATOR_USERNAME:-}:${E2E_OPERATOR_PASSWORD:-}"
    "${E2E_VIEWER_USERNAME:-}:${E2E_VIEWER_PASSWORD:-}"
    "${E2E_AUDITOR_USERNAME:-}:${E2E_AUDITOR_PASSWORD:-}"
    "${GRAFANA_ADMIN_USER:-}:${GRAFANA_ADMIN_PASSWORD:-}"
  )

  while IFS= read -r line || [[ -n "$line" ]]; do
    for secret in "${secrets[@]}"; do
      if [[ -n "$secret" ]]; then
        line="${line//"$secret"/[REDACTED]}"
        if command -v base64 >/dev/null 2>&1; then
          encoded_value="$(printf '%s' "$secret" | base64 --wrap=0)"
          line="${line//"$encoded_value"/[REDACTED_BASE64]}"
        fi
      fi
    done
    if command -v base64 >/dev/null 2>&1; then
      for secret in "${credential_pairs[@]}"; do
        [[ "$secret" != : && "$secret" != *: ]] || continue
        encoded_value="$(printf '%s' "$secret" | base64 --wrap=0)"
        line="${line//"$encoded_value"/[REDACTED_BASIC]}"
      done
    fi
    while [[ "$line" =~ (eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}) ]]; do
      line="${line//"${BASH_REMATCH[1]}"/[REDACTED_JWT]}"
    done
    while [[ "$line" =~ (Bearer[[:space:]]+[A-Za-z0-9._-]{16,}) ]]; do
      line="${line//"${BASH_REMATCH[1]}"/Bearer [REDACTED]}"
    done
    while [[ "$line" =~ (Basic[[:space:]]+[A-Za-z0-9+/=]{16,}) ]]; do
      line="${line//"${BASH_REMATCH[1]}"/Basic [REDACTED]}"
    done
    printf '%s\n' "$line"
  done
}

require_command() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 || {
    production_error "required command not found: $command_name"
    return 1
  }
}

require_production_env() {
  [[ -f "$PRODUCTION_ENV_FILE" ]] || {
    production_error "environment file not found: $PRODUCTION_ENV_FILE"
    production_error "run scripts/gcp/init-env.sh first"
    return 1
  }
  [[ "$(stat -c '%a' "$PRODUCTION_ENV_FILE")" == 600 ]] || {
    production_error "environment file must have permissions 0600"
    return 1
  }
}

load_production_env() {
  require_production_env
  load_production_env_file "$PRODUCTION_ENV_FILE"
}

load_production_env_file() {
  local environment_file="$1"
  local allowed_variables=(
    COMPOSE_PROJECT_NAME
    APP_VERSION
    DEPLOYED_SHA
    PRODUCTION_DEPLOYMENT_ID
    PRODUCTION_PUBLIC_IP
    PRODUCTION_ORIGIN
    PRODUCTION_FRONTEND_URL
    PRODUCTION_BACKEND_URL
    PRODUCTION_KEYCLOAK_URL
    PRODUCTION_GRAFANA_URL
    TLS_CERTIFICATE_NAME
    POSTGRES_DB
    POSTGRES_USER
    POSTGRES_PASSWORD
    KEYCLOAK_DB
    KEYCLOAK_DB_USER
    KEYCLOAK_DB_PASSWORD
    KEYCLOAK_ADMIN
    KEYCLOAK_ADMIN_PASSWORD
    KEYCLOAK_REALM
    KEYCLOAK_CLIENT_ID
    KEYCLOAK_ADMIN_CLIENT_ID
    KEYCLOAK_ADMIN_CLIENT_SECRET
    KEYCLOAK_IMPORT_DIR
    E2E_ADMIN_USERNAME
    E2E_ADMIN_PASSWORD
    E2E_OPERATOR_USERNAME
    E2E_OPERATOR_PASSWORD
    E2E_VIEWER_USERNAME
    E2E_VIEWER_PASSWORD
    E2E_AUDITOR_USERNAME
    E2E_AUDITOR_PASSWORD
    GRAFANA_ADMIN_USER
    GRAFANA_ADMIN_PASSWORD
    INVENTORY_CORS_ALLOWED_ORIGINS
    OTEL_SDK_DISABLED
    OTEL_DEPLOYMENT_ENVIRONMENT
  )
  local line
  local variable_name
  local value
  local -A allowed_lookup=()
  local -A seen_variables=()

  for variable_name in "${allowed_variables[@]}"; do
    allowed_lookup["$variable_name"]=true
    unset "$variable_name"
  done

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue
    [[ "$line" =~ ^([A-Z][A-Z0-9_]*)=([A-Za-z0-9._:/@+-]+)$ ]] || {
      production_error "invalid entry in production environment file"
      return 1
    }
    variable_name="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"

    [[ -n "${allowed_lookup[$variable_name]:-}" ]] || {
      production_error "unsupported variable in production environment: $variable_name"
      return 1
    }
    [[ -z "${seen_variables[$variable_name]:-}" ]] || {
      production_error "duplicate variable in production environment: $variable_name"
      return 1
    }

    printf -v "$variable_name" '%s' "$value"
    export "$variable_name"
    seen_variables["$variable_name"]=true
  done < "$environment_file"

  for variable_name in "${allowed_variables[@]}"; do
    [[ -n "${seen_variables[$variable_name]:-}" && -n "${!variable_name:-}" ]] || {
      production_error "required variable is missing or empty: $variable_name"
      return 1
    }
  done

  validate_production_environment
}

validate_production_environment() {
  [[ "$COMPOSE_PROJECT_NAME" == inventory-production ]] || {
    production_error "COMPOSE_PROJECT_NAME must be exactly inventory-production"
    return 1
  }
  [[ "$APP_VERSION" =~ ^[0-9a-f]{40}$ ]] || {
    production_error "APP_VERSION must be a full lowercase Git SHA"
    return 1
  }
  [[ "$DEPLOYED_SHA" == "$APP_VERSION" ]] || {
    production_error "DEPLOYED_SHA must equal APP_VERSION"
    return 1
  }
  [[ "$PRODUCTION_PUBLIC_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || {
    production_error "PRODUCTION_PUBLIC_IP must be an IPv4 address"
    return 1
  }

  local octet
  local -a ip_octets
  IFS=. read -r -a ip_octets <<< "$PRODUCTION_PUBLIC_IP"
  for octet in "${ip_octets[@]}"; do
    ((10#$octet >= 0 && 10#$octet <= 255)) || {
      production_error "PRODUCTION_PUBLIC_IP contains an invalid IPv4 octet"
      return 1
    }
  done

  local expected_origin="https://$PRODUCTION_PUBLIC_IP"
  [[ "$PRODUCTION_ORIGIN" == "$expected_origin" ]] || {
    production_error "PRODUCTION_ORIGIN must equal $expected_origin"
    return 1
  }
  [[ "$PRODUCTION_FRONTEND_URL" == "$expected_origin" ]] || {
    production_error "PRODUCTION_FRONTEND_URL must equal PRODUCTION_ORIGIN"
    return 1
  }
  [[ "$PRODUCTION_BACKEND_URL" == "$expected_origin/api" ]] || {
    production_error "PRODUCTION_BACKEND_URL must equal PRODUCTION_ORIGIN/api"
    return 1
  }
  [[ "$PRODUCTION_KEYCLOAK_URL" == "$expected_origin/auth" ]] || {
    production_error "PRODUCTION_KEYCLOAK_URL must equal PRODUCTION_ORIGIN/auth"
    return 1
  }
  [[ "$PRODUCTION_GRAFANA_URL" == "$expected_origin/grafana" ]] || {
    production_error "PRODUCTION_GRAFANA_URL must equal PRODUCTION_ORIGIN/grafana"
    return 1
  }
  [[ "$INVENTORY_CORS_ALLOWED_ORIGINS" == "$expected_origin" ]] || {
    production_error "INVENTORY_CORS_ALLOWED_ORIGINS must equal PRODUCTION_ORIGIN"
    return 1
  }
  [[ "$TLS_CERTIFICATE_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]] || {
    production_error "TLS_CERTIFICATE_NAME contains unsupported characters"
    return 1
  }

  local expected_import_dir="$PRODUCTION_STATE_DIR/keycloak"
  if [[ "$PRODUCTION_STATE_DIR" == "$PRODUCTION_REPOSITORY_ROOT/.production" ]]; then
    expected_import_dir=.production/keycloak
  fi
  [[ "$KEYCLOAK_IMPORT_DIR" == "$expected_import_dir" ]] || {
    production_error "KEYCLOAK_IMPORT_DIR must equal $expected_import_dir"
    return 1
  }
  [[ "$KEYCLOAK_REALM" == inventory ]] || {
    production_error "KEYCLOAK_REALM is fixed to inventory"
    return 1
  }
  [[ "$KEYCLOAK_CLIENT_ID" == inventory-frontend ]] || {
    production_error "KEYCLOAK_CLIENT_ID is fixed to inventory-frontend"
    return 1
  }
  [[ "$KEYCLOAK_ADMIN_CLIENT_ID" == inventory-admin-service ]] || {
    production_error "KEYCLOAK_ADMIN_CLIENT_ID is fixed to inventory-admin-service"
    return 1
  }
  [[ "$E2E_ADMIN_USERNAME" == carlos \
    && "$E2E_OPERATOR_USERNAME" == edwin \
    && "$E2E_VIEWER_USERNAME" == viewer \
    && "$E2E_AUDITOR_USERNAME" == auditor ]] || {
    production_error "E2E usernames are fixed by the database and Keycloak seed contract"
    return 1
  }
  [[ "$OTEL_DEPLOYMENT_ENVIRONMENT" == production ]] || {
    production_error "OTEL_DEPLOYMENT_ENVIRONMENT must be production"
    return 1
  }
  [[ "$OTEL_SDK_DISABLED" == true || "$OTEL_SDK_DISABLED" == false ]] || {
    production_error "OTEL_SDK_DISABLED must be true or false"
    return 1
  }
}

production_compose() {
  : "${COMPOSE_PROJECT_NAME:?load_production_env must be called first}"

  docker compose \
    --env-file "$PRODUCTION_ENV_FILE" \
    --project-name "$COMPOSE_PROJECT_NAME" \
    --file "$PRODUCTION_COMPOSE_FILE" \
    --file "$PRODUCTION_COMPOSE_OVERLAY" \
    "$@"
}

ensure_production_evidence_dir() {
  mkdir -p -- "$PRODUCTION_EVIDENCE_DIR"
  chmod 0700 -- "$PRODUCTION_EVIDENCE_DIR"
}

validate_production_evidence_dir() {
  local expected_sha="${1:-}"
  local canonical_state
  local canonical_evidence
  local canonical_evidence_root
  local evidence_sha

  canonical_state="$(realpath -m -- "$PRODUCTION_STATE_DIR")"
  canonical_evidence="$(realpath -m -- "$PRODUCTION_EVIDENCE_DIR")"
  canonical_evidence_root="$canonical_state/evidence"
  evidence_sha="$(basename -- "$canonical_evidence")"

  [[ "$evidence_sha" =~ ^[0-9a-f]{40}$ ]] || {
    production_error "production evidence directory must end in a full Git SHA"
    return 1
  }
  [[ "$(dirname -- "$canonical_evidence")" == "$canonical_evidence_root" ]] || {
    production_error "production evidence directory escapes the shared evidence root"
    return 1
  }
  if [[ -n "$expected_sha" && "$evidence_sha" != "$expected_sha" ]]; then
    production_error "production evidence directory does not match the requested SHA"
    return 1
  fi
  [[ ! -L "$PRODUCTION_EVIDENCE_DIR" ]] || {
    production_error "production evidence directory cannot be a symbolic link"
    return 1
  }
}
