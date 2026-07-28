#!/usr/bin/env bash

set -Eeuo pipefail

readonly STAGING_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly STAGING_REPOSITORY_ROOT="$(cd -- "$STAGING_SCRIPT_DIR/../.." && pwd)"
readonly STAGING_STATE_DIR="$STAGING_REPOSITORY_ROOT/.staging"
readonly STAGING_ENV_FILE="$STAGING_STATE_DIR/staging.env"
readonly STAGING_EVIDENCE_DIR="$STAGING_STATE_DIR/evidence"
readonly STAGING_COMPOSE_FILE="$STAGING_REPOSITORY_ROOT/docker-compose.yml"
readonly STAGING_COMPOSE_OVERRIDE="$STAGING_REPOSITORY_ROOT/docker-compose.staging.yml"

staging_error() {
  printf 'staging: %s\n' "$*" >&2
}

redact_staging_secrets() {
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
    staging_error "required command not found: $command_name"
    return 1
  }
}

require_staging_env() {
  [[ -f "$STAGING_ENV_FILE" ]] || {
    staging_error "environment file not found: $STAGING_ENV_FILE"
    staging_error "run scripts/staging/init-env.sh first"
    return 1
  }
}

load_staging_env() {
  require_staging_env
  load_staging_env_file "$STAGING_ENV_FILE"
}

load_staging_env_file() {
  local environment_file="$1"
  local allowed_variables=(
    COMPOSE_PROJECT_NAME
    APP_VERSION
    STAGING_DEPLOYMENT_ID
    STAGING_LIFECYCLE
    STAGING_VISIBILITY
    STAGING_BIND_ADDRESS
    FRONTEND_PORT
    BACKEND_PORT
    KEYCLOAK_PORT
    KEYCLOAK_MANAGEMENT_PORT
    PROMETHEUS_PORT
    GRAFANA_PORT
    ALLOY_HTTP_PORT
    LOKI_PORT
    TEMPO_PORT
    ALERTMANAGER_PORT
    STAGING_FRONTEND_URL
    STAGING_BACKEND_URL
    STAGING_KEYCLOAK_URL
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
  local -A seen_variables=()

  for variable_name in "${allowed_variables[@]}"; do
    unset "$variable_name"
  done

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue
    [[ "$line" =~ ^([A-Z][A-Z0-9_]*)=([A-Za-z0-9._:/@+-]+)$ ]] || {
      staging_error "invalid entry in staging environment file"
      return 1
    }
    variable_name="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"

    [[ " ${allowed_variables[*]} " == *" $variable_name "* ]] || {
      staging_error "unsupported variable in staging environment: $variable_name"
      return 1
    }
    [[ -z "${seen_variables[$variable_name]:-}" ]] || {
      staging_error "duplicate variable in staging environment: $variable_name"
      return 1
    }

    printf -v "$variable_name" '%s' "$value"
    export "$variable_name"
    seen_variables[$variable_name]=true
  done < "$environment_file"

  local required_variables=("${allowed_variables[@]}")

  for variable_name in "${required_variables[@]}"; do
    [[ -n "${seen_variables[$variable_name]:-}" && -n "${!variable_name:-}" ]] || {
      staging_error "required variable is missing or empty: $variable_name"
      return 1
    }
  done

  validate_staging_isolation
}

validate_staging_isolation() {
  [[ "$COMPOSE_PROJECT_NAME" =~ ^inventory-staging-[a-z0-9][a-z0-9_-]*$ ]] || {
    staging_error "COMPOSE_PROJECT_NAME must start with inventory-staging- and use lowercase safe characters"
    return 1
  }
  [[ "$STAGING_BIND_ADDRESS" == "127.0.0.1" ]] || {
    staging_error "STAGING_BIND_ADDRESS must be 127.0.0.1; public binding requires a separate TLS deployment design"
    return 1
  }

  local port_variable
  local port_value
  local numeric_port
  local -A seen_ports=()
  for port_variable in \
    FRONTEND_PORT BACKEND_PORT KEYCLOAK_PORT KEYCLOAK_MANAGEMENT_PORT \
    PROMETHEUS_PORT GRAFANA_PORT ALLOY_HTTP_PORT LOKI_PORT TEMPO_PORT \
    ALERTMANAGER_PORT; do
    port_value="${!port_variable}"
    [[ "$port_value" =~ ^[0-9]+$ ]] || {
      staging_error "$port_variable must be a numeric TCP port"
      return 1
    }
    numeric_port=$((10#$port_value))
    ((numeric_port >= 1 && numeric_port <= 65535)) || {
      staging_error "$port_variable is outside the TCP port range"
      return 1
    }
    [[ -z "${seen_ports[$numeric_port]:-}" ]] || {
      staging_error "$port_variable duplicates the port used by ${seen_ports[$numeric_port]}"
      return 1
    }
    seen_ports[$numeric_port]="$port_variable"
  done

  [[ "$STAGING_FRONTEND_URL" == "http://127.0.0.1:$FRONTEND_PORT" ]] || {
    staging_error "STAGING_FRONTEND_URL must match the loopback frontend port"
    return 1
  }
  [[ "$STAGING_BACKEND_URL" == "http://127.0.0.1:$BACKEND_PORT" ]] || {
    staging_error "STAGING_BACKEND_URL must match the loopback backend port"
    return 1
  }
  [[ "$STAGING_KEYCLOAK_URL" == "http://127.0.0.1:$KEYCLOAK_PORT" ]] || {
    staging_error "STAGING_KEYCLOAK_URL must match the loopback Keycloak port"
    return 1
  }
  [[ "$INVENTORY_CORS_ALLOWED_ORIGINS" == "$STAGING_FRONTEND_URL" ]] || {
    staging_error "INVENTORY_CORS_ALLOWED_ORIGINS must equal STAGING_FRONTEND_URL"
    return 1
  }
  [[ "$KEYCLOAK_IMPORT_DIR" == .staging/keycloak ]] || {
    staging_error "KEYCLOAK_IMPORT_DIR must remain inside the isolated staging state"
    return 1
  }

  [[ "$KEYCLOAK_REALM" == inventory ]] || {
    staging_error "KEYCLOAK_REALM is fixed to inventory by the application seed contract"
    return 1
  }
  [[ "$KEYCLOAK_CLIENT_ID" == inventory-frontend ]] || {
    staging_error "KEYCLOAK_CLIENT_ID is fixed to inventory-frontend"
    return 1
  }
  [[ "$KEYCLOAK_ADMIN_CLIENT_ID" == inventory-admin-service ]] || {
    staging_error "KEYCLOAK_ADMIN_CLIENT_ID is fixed to inventory-admin-service"
    return 1
  }
  [[ "$E2E_ADMIN_USERNAME" == carlos \
    && "$E2E_OPERATOR_USERNAME" == edwin \
    && "$E2E_VIEWER_USERNAME" == viewer \
    && "$E2E_AUDITOR_USERNAME" == auditor ]] || {
    staging_error "E2E usernames are fixed by the database and Keycloak seed contract"
    return 1
  }
  [[ "$OTEL_DEPLOYMENT_ENVIRONMENT" == staging ]] || {
    staging_error "OTEL_DEPLOYMENT_ENVIRONMENT must be staging"
    return 1
  }
  [[ "$OTEL_SDK_DISABLED" == true || "$OTEL_SDK_DISABLED" == false ]] || {
    staging_error "OTEL_SDK_DISABLED must be true or false"
    return 1
  }

  case "$STAGING_LIFECYCLE:$STAGING_VISIBILITY" in
    operator-managed:host-loopback|ephemeral:runner-private)
      ;;
    *)
      staging_error "unsupported staging lifecycle/visibility combination"
      return 1
      ;;
  esac
}

staging_compose() {
  : "${COMPOSE_PROJECT_NAME:?load_staging_env must be called first}"

  docker compose \
    --env-file "$STAGING_ENV_FILE" \
    --project-name "$COMPOSE_PROJECT_NAME" \
    --file "$STAGING_COMPOSE_FILE" \
    --file "$STAGING_COMPOSE_OVERRIDE" \
    "$@"
}

ensure_evidence_dir() {
  mkdir -p -- "$STAGING_EVIDENCE_DIR"
  chmod 0700 -- "$STAGING_EVIDENCE_DIR"
}

reset_post_deploy_evidence() {
  local post_deploy_directory="$STAGING_EVIDENCE_DIR/post-deploy"

  [[ "$post_deploy_directory" == "$STAGING_REPOSITORY_ROOT/.staging/evidence/post-deploy" ]] || {
    staging_error "refusing to clear an unexpected post-deploy evidence path"
    return 1
  }

  if [[ -d "$post_deploy_directory" ]]; then
    find "$post_deploy_directory" -mindepth 1 -delete
  fi
  mkdir -p -- "$post_deploy_directory"
  chmod 0700 -- "$post_deploy_directory"
}

update_staging_env_value() {
  local variable_name="$1"
  local value="$2"
  local temporary_file

  [[ "$variable_name" =~ ^[A-Z][A-Z0-9_]*$ ]] || {
    staging_error "invalid environment variable name: $variable_name"
    return 1
  }
  [[ "$value" =~ ^[A-Za-z0-9._:/@+-]+$ ]] || {
    staging_error "unsupported characters in value for $variable_name"
    return 1
  }

  temporary_file="$(mktemp "$STAGING_STATE_DIR/staging.env.XXXXXX")"
  if ! awk -F= -v key="$variable_name" -v replacement="$value" '
    BEGIN { replaced = 0 }
    $1 == key {
      print key "=" replacement
      replaced = 1
      next
    }
    { print }
    END {
      if (!replaced) {
        print key "=" replacement
      }
    }
  ' "$STAGING_ENV_FILE" > "$temporary_file"; then
    rm -f -- "$temporary_file"
    return 1
  fi
  if ! chmod 0600 -- "$temporary_file"; then
    rm -f -- "$temporary_file"
    return 1
  fi
  if ! load_staging_env_file "$temporary_file"; then
    rm -f -- "$temporary_file"
    return 1
  fi
  if ! mv -- "$temporary_file" "$STAGING_ENV_FILE"; then
    rm -f -- "$temporary_file"
    return 1
  fi
}
