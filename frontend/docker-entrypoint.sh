#!/bin/sh

set -eu

auth_config_path="/usr/share/nginx/html/auth-config.json"
keycloak_public_url="${KEYCLOAK_PUBLIC_URL:-http://localhost:8081}"
keycloak_realm="${KEYCLOAK_REALM:-inventory}"
keycloak_client_id="${KEYCLOAK_CLIENT_ID:-inventory-frontend}"

printf '{\n  "url": "%s",\n  "realm": "%s",\n  "clientId": "%s"\n}\n' \
  "$keycloak_public_url" \
  "$keycloak_realm" \
  "$keycloak_client_id" \
  > "$auth_config_path"

exec nginx -g "daemon off;"
