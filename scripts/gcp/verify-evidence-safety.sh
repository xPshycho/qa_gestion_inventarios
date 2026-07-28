#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$script_dir/common.sh"

[[ $# -eq 0 ]] || {
  production_error "usage: scripts/gcp/verify-evidence-safety.sh"
  exit 2
}

for required_command in find jq mktemp python3 realpath; do
  require_command "$required_command"
done
load_production_env
validate_production_evidence_dir
ensure_production_evidence_dir

readonly artifact_verifier="$PRODUCTION_REPOSITORY_ROOT/scripts/security/verify-artifacts.sh"
readonly safety_report="$PRODUCTION_EVIDENCE_DIR/evidence-safety.json"
readonly checked_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

[[ "$PRODUCTION_EVIDENCE_DIR" == "$PRODUCTION_STATE_DIR"/evidence/* ]] || {
  production_error "evidence directory must be scoped to one production deployment"
  exit 1
}
[[ -x "$artifact_verifier" ]] || {
  production_error "artifact safety verifier is unavailable"
  exit 1
}
[[ ! -L "$PRODUCTION_EVIDENCE_DIR" ]] || {
  production_error "production evidence directory cannot be a symbolic link"
  exit 1
}

rm -f -- "$safety_report"

readonly symbolic_link="$(
  find "$PRODUCTION_EVIDENCE_DIR" -type l -print -quit
)"
[[ -z "$symbolic_link" ]] || {
  production_error "symbolic links are not allowed in production evidence"
  exit 1
}

readonly prohibited_artifact="$(
  find "$PRODUCTION_EVIDENCE_DIR" -type f \
    \( \
      -name 'trace.zip' \
      -o -name '*.webm' \
      -o -name '*.har' \
      -o -name '*.pem' \
      -o -name '*.key' \
      -o -name '*.p12' \
      -o -name '*.pfx' \
      -o -name '*.sql' \
      -o -name '*.dump' \
      -o -name '*.dump.gz' \
      -o -name '*.env' \
      -o -name 'inventory-realm.json' \
    \) \
    -print -quit
)"
[[ -z "$prohibited_artifact" ]] || {
  production_error "production evidence contains a prohibited sensitive artifact type"
  exit 1
}

readonly unexpected_image="$(
  find "$PRODUCTION_EVIDENCE_DIR" -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) \
    ! -path "$PRODUCTION_EVIDENCE_DIR/runner/playwright/screenshots/*.png" \
    ! -path "$PRODUCTION_EVIDENCE_DIR/post-deploy/screenshots/*.png" \
    -print -quit
)"
[[ -z "$unexpected_image" ]] || {
  production_error "production evidence contains an uncontrolled image"
  exit 1
}

INVENTORY_SECRET_ENV_FILE="$PRODUCTION_ENV_FILE" \
  "$artifact_verifier" "$PRODUCTION_EVIDENCE_DIR"

temporary_report="$(mktemp "$PRODUCTION_EVIDENCE_DIR/.safety.XXXXXX")"
readonly temporary_report
cleanup_temporary_report() {
  rm -f -- "$temporary_report"
}
trap cleanup_temporary_report EXIT

jq --null-input \
  --arg result PASS \
  --arg environment production \
  --arg checkedAt "$checked_at" \
  --arg deployedSha "$DEPLOYED_SHA" \
  '{
    result: $result,
    environment: $environment,
    checkedAt: $checkedAt,
    deployedSha: $deployedSha,
    checks: [
      "deployment-scoped-directory",
      "no-symbolic-links",
      "no-trace-video-har-html-or-database-artifacts",
      "no-uncontrolled-images",
      "no-configured-secret-values",
      "no-base64-basic-auth-or-jwt-values",
      "recursive-archive-and-compressed-payload-scan"
    ]
  }' > "$temporary_report"
chmod 0600 -- "$temporary_report"
mv -- "$temporary_report" "$safety_report"
trap - EXIT

printf 'Production evidence safety verification passed: %s\n' "$safety_report"
