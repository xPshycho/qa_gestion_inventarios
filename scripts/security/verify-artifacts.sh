#!/usr/bin/env bash

set -euo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly repository_root="$(cd -- "$script_dir/../.." && pwd)"
readonly environment_file="${INVENTORY_SECRET_ENV_FILE:-$repository_root/.env}"
readonly artifact_scanner="$script_dir/scan-artifacts.py"

[[ $# -ge 1 ]] || {
  printf 'Usage: %s ARTIFACT_PATH [ARTIFACT_PATH ...]\n' "$0" >&2
  exit 2
}

command -v find >/dev/null
command -v python3 >/dev/null

[[ -f "$environment_file" && ! -L "$environment_file" ]] || {
  printf 'Artifact safety requires a regular ignored environment file: %s\n' \
    "$environment_file" >&2
  exit 1
}
[[ -f "$artifact_scanner" ]] || {
  printf 'Artifact scanner not found: %s\n' "$artifact_scanner" >&2
  exit 1
}

secret_names=(
  POSTGRES_PASSWORD
  KEYCLOAK_ADMIN_PASSWORD
  KEYCLOAK_ADMIN_CLIENT_SECRET
  E2E_ADMIN_PASSWORD
  E2E_OPERATOR_PASSWORD
  E2E_VIEWER_PASSWORD
  E2E_AUDITOR_PASSWORD
  GRAFANA_ADMIN_PASSWORD
)
username_names=(
  E2E_ADMIN_USERNAME
  E2E_OPERATOR_USERNAME
  E2E_VIEWER_USERNAME
  E2E_AUDITOR_USERNAME
  GRAFANA_ADMIN_USER
)
allowed_names=("${secret_names[@]}" "${username_names[@]}")
declare -A configured_values=()

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  [[ "$line" =~ ^([A-Z][A-Z0-9_]*)=([A-Za-z0-9._:/@+-]*)$ ]] || {
    printf 'Invalid entry in artifact safety environment file.\n' >&2
    exit 1
  }

  name="${BASH_REMATCH[1]}"
  value="${BASH_REMATCH[2]}"
  for allowed_name in "${allowed_names[@]}"; do
    if [[ "$name" == "$allowed_name" ]]; then
      configured_values["$name"]="$value"
      break
    fi
  done
done < "$environment_file"

for name in "${secret_names[@]}"; do
  [[ -n "${configured_values[$name]:-}" ]] || {
    printf 'Required secret is missing from artifact safety environment: %s\n' \
      "$name" >&2
    exit 1
  }
  printf -v "$name" '%s' "${configured_values[$name]}"
  export "$name"
done

E2E_ADMIN_USERNAME="${configured_values[E2E_ADMIN_USERNAME]:-carlos}"
E2E_OPERATOR_USERNAME="${configured_values[E2E_OPERATOR_USERNAME]:-edwin}"
E2E_VIEWER_USERNAME="${configured_values[E2E_VIEWER_USERNAME]:-viewer}"
E2E_AUDITOR_USERNAME="${configured_values[E2E_AUDITOR_USERNAME]:-auditor}"
GRAFANA_ADMIN_USER="${configured_values[GRAFANA_ADMIN_USER]:-admin}"
export \
  E2E_ADMIN_USERNAME \
  E2E_OPERATOR_USERNAME \
  E2E_VIEWER_USERNAME \
  E2E_AUDITOR_USERNAME \
  GRAFANA_ADMIN_USER

inspected_paths=0
for artifact_path in "$@"; do
  if [[ "$artifact_path" != /* ]]; then
    artifact_path="$repository_root/$artifact_path"
  fi
  [[ -e "$artifact_path" && ! -L "$artifact_path" ]] || continue

  if [[ -f "$artifact_path" ]]; then
    scan_root="$artifact_path"
    unsafe_file="$(
      find "$artifact_path" -type f \
        \( -name 'trace.zip' -o -name '*.webm' -o -name '*.har' \
          -o -name '*.html' \) \
        -print -quit
    )"
  elif [[ -d "$artifact_path" ]]; then
    scan_root="$artifact_path"
    unsafe_file="$(
      find "$artifact_path" -type f \
        \( -name 'trace.zip' -o -name '*.webm' -o -name '*.har' \
          -o -name '*.html' \) \
        -print -quit
    )"
  else
    printf 'Unsupported artifact path type.\n' >&2
    exit 1
  fi

  if [[ -n "$unsafe_file" ]]; then
    printf 'Artifact safety rejected a trace, video, HAR or HTML report.\n' >&2
    exit 1
  fi

  python3 "$artifact_scanner" "$scan_root"
  inspected_paths=$((inspected_paths + 1))
done

((inspected_paths > 0)) || {
  printf 'No artifact paths were available for safety verification.\n' >&2
  exit 1
}

printf 'Artifact safety verification passed (%d path(s); values hidden).\n' \
  "$inspected_paths"
