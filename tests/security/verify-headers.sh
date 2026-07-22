#!/usr/bin/env bash

set -Eeuo pipefail

frontend_url="${FRONTEND_URL:-http://localhost:5173}"
expected_keycloak_origin="${KEYCLOAK_PUBLIC_URL:-http://localhost:8081}"
headers_file="$(mktemp)"

cleanup() {
  rm -f -- "$headers_file"
}

trap cleanup EXIT

curl --fail --silent --show-error --head "$frontend_url/" > "$headers_file"

require_header() {
  local expected_header="$1"

  if ! grep --ignore-case --quiet --fixed-strings "$expected_header" "$headers_file"; then
    echo "Missing expected header: $expected_header" >&2
    exit 1
  fi
}

require_header "Content-Security-Policy:"
require_header "connect-src 'self' $expected_keycloak_origin"
require_header "X-Content-Type-Options: nosniff"
require_header "Referrer-Policy: strict-origin-when-cross-origin"
require_header "Permissions-Policy: camera=(), geolocation=(), microphone=(), payment=()"

echo "Security headers verified for $frontend_url"
