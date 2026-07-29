#!/bin/sh

set -eu

auth_config_path="/usr/share/nginx/html/auth-config.json"
nginx_template_dir="/etc/nginx/templates"
nginx_config_dir="/etc/nginx/conf.d"
keycloak_public_url="${KEYCLOAK_PUBLIC_URL:-http://localhost:8081}"
keycloak_realm="${KEYCLOAK_REALM:-inventory}"
keycloak_client_id="${KEYCLOAK_CLIENT_ID:-inventory-frontend}"
backend_upstream="${BACKEND_UPSTREAM:-backend:8080}"

export KEYCLOAK_PUBLIC_URL="$keycloak_public_url"
export BACKEND_UPSTREAM="$backend_upstream"

case "$keycloak_public_url" in
  http://*|https://*) ;;
  *)
    echo "KEYCLOAK_PUBLIC_URL must be an HTTP(S) origin" >&2
    exit 1
    ;;
esac

backend_host="${backend_upstream%:*}"
backend_port="${backend_upstream##*:}"

case "$backend_upstream" in
  *:*) ;;
  *)
    echo "BACKEND_UPSTREAM must be a host:port value" >&2
    exit 1
    ;;
esac

case "$backend_host" in
  ""|*[!A-Za-z0-9._-]*)
    echo "BACKEND_UPSTREAM must be a host:port value" >&2
    exit 1
    ;;
esac

case "$backend_port" in
  ""|*[!0-9]*)
    echo "BACKEND_UPSTREAM must be a host:port value" >&2
    exit 1
    ;;
esac

if [ "$backend_port" -lt 1 ] || [ "$backend_port" -gt 65535 ]; then
  echo "BACKEND_UPSTREAM port must be between 1 and 65535" >&2
  exit 1
fi

printf '{\n  "url": "%s",\n  "realm": "%s",\n  "clientId": "%s"\n}\n' \
  "$keycloak_public_url" \
  "$keycloak_realm" \
  "$keycloak_client_id" \
  > "$auth_config_path"

envsubst '${KEYCLOAK_PUBLIC_URL} ${BACKEND_UPSTREAM}' \
  < "$nginx_template_dir/default.conf.template" \
  > "$nginx_config_dir/default.conf"
envsubst '${KEYCLOAK_PUBLIC_URL}' \
  < "$nginx_template_dir/security-headers.conf.template" \
  > "$nginx_config_dir/security-headers.conf"
envsubst '${KEYCLOAK_PUBLIC_URL}' \
  < "$nginx_template_dir/silent-sso-headers.conf.template" \
  > "$nginx_config_dir/silent-sso-headers.conf"

nginx -t

exec nginx -g "daemon off;"
