#!/usr/bin/env bash

set -Eeuo pipefail

readonly report_dir="${ZAP_REPORT_DIR:-tests/security/reports}"
readonly zap_image="${ZAP_IMAGE:-zaproxy/zap-stable}"

main() {
  : "${ZAP_TARGET_URL:?ZAP_TARGET_URL is required}"
  : "${ZAP_DOCKER_NETWORK:?ZAP_DOCKER_NETWORK is required}"

  command -v docker >/dev/null || {
    echo "docker is required to run the ZAP baseline." >&2
    exit 1
  }
  command -v jq >/dev/null || {
    echo "jq is required to evaluate the ZAP report." >&2
    exit 1
  }

  mkdir -p -- "$report_dir"

  docker run --rm \
    --network "$ZAP_DOCKER_NETWORK" \
    --volume "$(pwd)/$report_dir:/zap/wrk:rw" \
    "$zap_image" \
    zap-baseline.py \
    -t "$ZAP_TARGET_URL" \
    -m 2 \
    -I \
    -r zap-baseline-report.html \
    -w zap-baseline-report.md \
    -J zap-baseline-report.json

  local high_alerts
  high_alerts="$(jq '[.site[].alerts[]? | select((.riskcode | tonumber) >= 3)] | length' "$report_dir/zap-baseline-report.json")"

  if [[ "$high_alerts" -gt 0 ]]; then
    echo "ZAP detected $high_alerts high-risk alert(s)." >&2
    exit 1
  fi

  echo "ZAP baseline completed without high-risk alerts."
}

main "$@"
