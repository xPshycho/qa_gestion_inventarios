#!/usr/bin/env bash

set -Eeuo pipefail

readonly report_dir="${ZAP_REPORT_DIR:-tests/security/reports}"
readonly zap_image="${ZAP_IMAGE:-zaproxy/zap-stable:2.17.0@sha256:c558ee87358911ab17278c70991e856f57793e115d9cd0f88ca475cf82907a1a}"
if [[ "$report_dir" == /* ]]; then
  readonly report_dir_absolute="$report_dir"
else
  readonly report_dir_absolute="$(pwd)/$report_dir"
fi

main() {
  : "${ZAP_OPENAPI_URL:?ZAP_OPENAPI_URL is required}"
  : "${ZAP_DOCKER_NETWORK:?ZAP_DOCKER_NETWORK is required}"
  : "${ZAP_ACCESS_TOKEN:?ZAP_ACCESS_TOKEN is required}"

  command -v docker >/dev/null
  command -v jq >/dev/null
  mkdir -p -- "$report_dir_absolute"
  chmod 0777 -- "$report_dir_absolute"

  local replacer_config
  replacer_config="-config replacer.full_list(0).description=inventory-jwt"
  replacer_config+=" -config replacer.full_list(0).enabled=true"
  replacer_config+=" -config replacer.full_list(0).matchtype=REQ_HEADER"
  replacer_config+=" -config replacer.full_list(0).matchstr=Authorization"
  replacer_config+=" -config replacer.full_list(0).replacement=Bearer%20${ZAP_ACCESS_TOKEN}"

  docker run --rm \
    --network "$ZAP_DOCKER_NETWORK" \
    --volume "$report_dir_absolute:/zap/wrk:rw" \
    "$zap_image" \
    zap-api-scan.py \
    -t "$ZAP_OPENAPI_URL" \
    -f openapi \
    -I \
    -w zap-api-report.md \
    -J zap-api-report.json \
    -z "$replacer_config"

  local report_json="$report_dir_absolute/zap-api-report.json"
  if [[ ! -s "$report_json" ]]; then
    echo "ZAP API scan did not generate the expected JSON report: $report_json" >&2
    exit 1
  fi

  local high_alerts
  high_alerts="$(jq '[.site[].alerts[]? | select((.riskcode | tonumber) >= 3)] | length' "$report_json")"
  if [[ "$high_alerts" -gt 0 ]]; then
    echo "ZAP API scan detected $high_alerts high-risk alert(s)." >&2
    exit 1
  fi

  echo "ZAP authenticated API active scan completed without high-risk alerts."
}

main "$@"
