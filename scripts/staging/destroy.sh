#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$script_dir/common.sh"

remove_volumes=false

usage() {
  cat <<'EOF'
Usage: scripts/staging/destroy.sh [--volumes]

Stops the staging stack. Named volumes are preserved by default. --volumes is
intended for disposable CI previews after all evidence has been uploaded.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --volumes)
      remove_volumes=true
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

load_staging_env

if [[ "$remove_volumes" == true ]]; then
  staging_compose down --volumes --remove-orphans
else
  staging_compose down --remove-orphans
fi
