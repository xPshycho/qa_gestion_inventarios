#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$script_dir/common.sh"

require_command find
require_command jq
require_command python3
load_staging_env
ensure_evidence_dir

readonly safety_report="$STAGING_EVIDENCE_DIR/evidence-safety.json"
readonly checked_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
readonly unsafe_artifact="$(
  find "$STAGING_EVIDENCE_DIR" -type f \
    \( -name 'trace.zip' -o -name '*.webm' -o -name '*.har' \) \
    -print -quit
)"
readonly e2e_evidence_directory="$STAGING_EVIDENCE_DIR/post-deploy/e2e"

if [[ -n "$unsafe_artifact" ]]; then
  staging_error "evidence contains a trace, video or HAR artifact that can retain credentials"
  exit 1
fi

if [[ -d "$e2e_evidence_directory" ]]; then
  readonly unexpected_e2e_image="$(
    find "$e2e_evidence_directory" -type f \
      \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) \
      ! -path "$e2e_evidence_directory/screenshots/*.png" \
      -print -quit
  )"
  if [[ -n "$unexpected_e2e_image" ]]; then
    staging_error "evidence contains an E2E image outside the controlled screenshot directory"
    exit 1
  fi
fi

python3 "$STAGING_REPOSITORY_ROOT/scripts/staging/scan-evidence.py" \
  "$STAGING_EVIDENCE_DIR"

jq --null-input \
  --arg checkedAt "$checked_at" \
  '{
    result: "PASS",
    checkedAt: $checkedAt,
    checks: [
      "no-playwright-trace-video-or-har",
      "no-uncontrolled-e2e-images",
      "no-configured-secret-values",
      "no-jwt-like-values",
      "recursive-archive-and-base64-scan"
    ]
  }' > "$safety_report"
chmod 0600 -- "$safety_report"

printf 'Evidence safety verification passed: %s\n' "$safety_report"
