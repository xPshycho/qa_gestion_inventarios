#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$script_dir/common.sh"

build_images=true

usage() {
  cat <<'EOF'
Usage: scripts/staging/deploy.sh [--no-build]

Creates the runtime environment when needed, renders the Keycloak realm, validates
the merged Compose model and deploys the staging stack. The stack remains running
until scripts/staging/destroy.sh is called.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-build)
      build_images=false
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

if [[ ! -f "$STAGING_ENV_FILE" ]]; then
  "$script_dir/init-env.sh"
fi

load_staging_env
reset_post_deploy_evidence
"$script_dir/render-keycloak-realm.sh"

staging_compose config --quiet

if [[ "$build_images" == true ]]; then
  staging_compose build backend frontend
fi

if [[ -f "$STAGING_STATE_DIR/current-version" ]]; then
  cp -- "$STAGING_STATE_DIR/current-version" "$STAGING_STATE_DIR/previous-version"
fi

readonly wait_timeout="${STAGING_WAIT_TIMEOUT_SECONDS:-480}"
up_arguments=(
  --detach
  --wait
  --wait-timeout "$wait_timeout"
  --no-build
  --force-recreate
)
staging_compose up "${up_arguments[@]}"

printf '%s\n' "$APP_VERSION" > "$STAGING_STATE_DIR/current-version"
chmod 0600 -- "$STAGING_STATE_DIR/current-version"

"$script_dir/collect-evidence.sh"
printf 'Staging deployment %s is running at %s\n' \
  "$STAGING_DEPLOYMENT_ID" \
  "$STAGING_FRONTEND_URL"
