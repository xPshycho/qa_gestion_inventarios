#!/usr/bin/env bash

set -euo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly repository_root="$(cd -- "$script_dir/../.." && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/security/init-secret-env.sh <local|jenkins> [--rotate]

Creates or completes an ignored environment file with random secrets and mode
0600. Existing non-empty secrets are preserved unless --rotate is supplied.
Values passed through environment variables take precedence and are never
printed.
EOF
}

[[ $# -ge 1 && $# -le 2 ]] || {
  usage >&2
  exit 2
}

readonly mode="$1"
readonly rotation_option="${2:-}"
[[ -z "$rotation_option" || "$rotation_option" == "--rotate" ]] || {
  usage >&2
  exit 2
}
readonly rotate="$([[ "$rotation_option" == "--rotate" ]] && printf true || printf false)"

case "$mode" in
  local)
    readonly template="$repository_root/.env.example"
    readonly default_output="$repository_root/.env"
    secret_keys=(
      POSTGRES_PASSWORD
      KEYCLOAK_ADMIN_PASSWORD
      KEYCLOAK_ADMIN_CLIENT_SECRET
      E2E_ADMIN_PASSWORD
      E2E_OPERATOR_PASSWORD
      E2E_VIEWER_PASSWORD
      E2E_AUDITOR_PASSWORD
      GRAFANA_ADMIN_PASSWORD
    )
    ;;
  jenkins)
    readonly template="$repository_root/.env.jenkins.example"
    readonly default_output="$repository_root/.env.jenkins"
    secret_keys=(JENKINS_ADMIN_PASSWORD)
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

readonly output="${INVENTORY_SECRET_ENV_OUTPUT:-$default_output}"

command -v awk >/dev/null
command -v install >/dev/null
command -v mktemp >/dev/null
command -v openssl >/dev/null

[[ -f "$template" ]] || {
  printf 'Template not found: %s\n' "$template" >&2
  exit 1
}
[[ ! -L "$output" ]] || {
  printf 'Refusing to write through a symlink: %s\n' "$output" >&2
  exit 1
}

umask 077
if [[ ! -e "$output" ]]; then
  install -m 0600 "$template" "$output"
elif [[ ! -f "$output" ]]; then
  printf 'Output is not a regular file: %s\n' "$output" >&2
  exit 1
else
  chmod 0600 "$output"
fi

read_value() {
  local key="$1"
  awk -F= -v key="$key" '
    $1 == key {
      sub(/^[^=]*=/, "")
      print
      exit
    }
  ' "$output"
}

write_value() {
  local key="$1"
  local value="$2"
  local temporary_file
  temporary_file="$(mktemp "${output}.tmp.XXXXXX")"

  if ! awk -v key="$key" -v value="$value" '
    BEGIN {
      prefix = key "="
      found = 0
    }
    index($0, prefix) == 1 {
      print prefix value
      found = 1
      next
    }
    {
      print
    }
    END {
      if (!found) {
        print prefix value
      }
    }
  ' "$output" > "$temporary_file"; then
    rm -f -- "$temporary_file"
    return 1
  fi

  chmod 0600 "$temporary_file"
  mv -- "$temporary_file" "$output"
}

for key in "${secret_keys[@]}"; do
  provided_value="${!key-}"
  current_value="$(read_value "$key")"

  if [[ -n "$provided_value" ]]; then
    resolved_value="$provided_value"
  elif [[ "$rotate" == false && -n "$current_value" ]]; then
    resolved_value="$current_value"
  else
    resolved_value="$(openssl rand -hex 24)"
  fi

  write_value "$key" "$resolved_value"
done

chmod 0600 "$output"
printf 'Initialized %s secret contract at %s (mode 0600; values hidden).\n' "$mode" "$output"
