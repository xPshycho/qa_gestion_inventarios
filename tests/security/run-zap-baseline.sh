#!/usr/bin/env bash

set -Eeuo pipefail

readonly report_dir="${ZAP_REPORT_DIR:-tests/security/reports}"
readonly zap_image="${ZAP_IMAGE:-zaproxy/zap-stable:2.16.1@sha256:7840969c7c9fead565bf9734b12f49f6886db90b1d35b1f74d79710bbd081dab}"
if [[ "$report_dir" == /* ]]; then
  readonly report_dir_absolute="$report_dir"
else
  readonly report_dir_absolute="$(pwd)/$report_dir"
fi

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

  mkdir -p -- "$report_dir_absolute"
  # ZAP runs as an unprivileged container user, whose UID differs from the
  # GitHub Actions runner.  The directory is a short-lived CI report volume.
  chmod 0777 -- "$report_dir_absolute"

  docker run --rm \
    --network "$ZAP_DOCKER_NETWORK" \
    --volume "$report_dir_absolute:/zap/wrk:rw" \
    "$zap_image" \
    zap-baseline.py \
    -t "$ZAP_TARGET_URL" \
    -m 2 \
    -I \
    -r zap-baseline-report.html \
    -w zap-baseline-report.md \
    -J zap-baseline-report.json

  local report_json="$report_dir_absolute/zap-baseline-report.json"
  if [[ ! -s "$report_json" ]]; then
    echo "ZAP did not generate the expected JSON report: $report_json" >&2
    exit 1
  fi

  local high_alerts
  high_alerts="$(jq '[.site[].alerts[]? | select((.riskcode | tonumber) >= 3)] | length' "$report_json")"

  if [[ "$high_alerts" -gt 0 ]]; then
    echo "ZAP detected $high_alerts high-risk alert(s)." >&2
    exit 1
  fi

  echo "ZAP baseline completed without high-risk alerts."
}

main "$@"
