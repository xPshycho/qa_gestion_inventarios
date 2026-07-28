#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$script_dir/common.sh"

require_command jq
load_production_env

readonly source_realm="$PRODUCTION_REPOSITORY_ROOT/infra/keycloak/inventory-realm.json"
if [[ "$KEYCLOAK_IMPORT_DIR" == /* ]]; then
  readonly target_dir="$KEYCLOAK_IMPORT_DIR"
else
  readonly target_dir="$PRODUCTION_REPOSITORY_ROOT/$KEYCLOAK_IMPORT_DIR"
fi
readonly target_realm="$target_dir/inventory-realm.json"

mkdir -p -- "$target_dir"
# The generated state directory is private, while the realm itself must be
# readable by the non-root UID used by the official Keycloak image.
chmod 0755 -- "$target_dir"

temporary_realm="$(mktemp "$target_dir/inventory-realm.json.XXXXXX")"
readonly temporary_realm
cleanup_temporary_realm() {
  rm -f -- "$temporary_realm"
}
trap cleanup_temporary_realm EXIT

jq \
  --arg frontend_url "$PRODUCTION_FRONTEND_URL" \
  --arg realm "$KEYCLOAK_REALM" \
  --arg frontend_client_id "$KEYCLOAK_CLIENT_ID" \
  --arg admin_client_id "$KEYCLOAK_ADMIN_CLIENT_ID" \
  --arg admin_client_secret "$KEYCLOAK_ADMIN_CLIENT_SECRET" \
  --arg admin_username "$E2E_ADMIN_USERNAME" \
  --arg admin_password "$E2E_ADMIN_PASSWORD" \
  --arg operator_username "$E2E_OPERATOR_USERNAME" \
  --arg operator_password "$E2E_OPERATOR_PASSWORD" \
  --arg viewer_username "$E2E_VIEWER_USERNAME" \
  --arg viewer_password "$E2E_VIEWER_PASSWORD" \
  --arg auditor_username "$E2E_AUDITOR_USERNAME" \
  --arg auditor_password "$E2E_AUDITOR_PASSWORD" \
  '
    .realm = $realm |
    (.clients[] | select(.clientId == $frontend_client_id) | .redirectUris) =
      [($frontend_url + "/*")] |
    (.clients[] | select(.clientId == $frontend_client_id) | .webOrigins) =
      [$frontend_url] |
    (.clients[] | select(.clientId == $frontend_client_id) |
      .attributes["post.logout.redirect.uris"]) = ($frontend_url + "/*") |
    (.clients[] | select(.clientId == $admin_client_id) | .secret) =
      $admin_client_secret |
    (.users[] | select(.username == $admin_username) |
      .credentials[0].value) = $admin_password |
    (.users[] | select(.username == $operator_username) |
      .credentials[0].value) = $operator_password |
    (.users[] | select(.username == $viewer_username) |
      .credentials[0].value) = $viewer_password |
    (.users[] | select(.username == $auditor_username) |
      .credentials[0].value) = $auditor_password
  ' \
  "$source_realm" > "$temporary_realm"

chmod 0644 -- "$temporary_realm"

jq --exit-status \
  --arg frontend_url "$PRODUCTION_FRONTEND_URL" \
  --arg realm "$KEYCLOAK_REALM" \
  --arg frontend_client_id "$KEYCLOAK_CLIENT_ID" \
  --arg admin_client_id "$KEYCLOAK_ADMIN_CLIENT_ID" \
  --arg admin_client_secret "$KEYCLOAK_ADMIN_CLIENT_SECRET" \
  --arg admin_username "$E2E_ADMIN_USERNAME" \
  --arg admin_password "$E2E_ADMIN_PASSWORD" \
  --arg operator_username "$E2E_OPERATOR_USERNAME" \
  --arg operator_password "$E2E_OPERATOR_PASSWORD" \
  --arg viewer_username "$E2E_VIEWER_USERNAME" \
  --arg viewer_password "$E2E_VIEWER_PASSWORD" \
  --arg auditor_username "$E2E_AUDITOR_USERNAME" \
  --arg auditor_password "$E2E_AUDITOR_PASSWORD" \
  '
    (.realm == $realm) and
    (([.clients[] | select(.clientId == $frontend_client_id)] | length) == 1) and
    ((.clients[] | select(.clientId == $frontend_client_id) |
      .redirectUris) == [($frontend_url + "/*")]) and
    ((.clients[] | select(.clientId == $frontend_client_id) |
      .webOrigins) == [$frontend_url]) and
    ((.clients[] | select(.clientId == $frontend_client_id) |
      .attributes["post.logout.redirect.uris"]) == ($frontend_url + "/*")) and
    (([.clients[] | select(.clientId == $admin_client_id)] | length) == 1) and
    ((.clients[] | select(.clientId == $admin_client_id) |
      .secret) == $admin_client_secret) and
    (([.users[] | select(.username == $admin_username)] | length) == 1) and
    ((.users[] | select(.username == $admin_username) |
      .credentials[0].value) == $admin_password) and
    (([.users[] | select(.username == $operator_username)] | length) == 1) and
    ((.users[] | select(.username == $operator_username) |
      .credentials[0].value) == $operator_password) and
    (([.users[] | select(.username == $viewer_username)] | length) == 1) and
    ((.users[] | select(.username == $viewer_username) |
      .credentials[0].value) == $viewer_password) and
    (([.users[] | select(.username == $auditor_username)] | length) == 1) and
    ((.users[] | select(.username == $auditor_username) |
      .credentials[0].value) == $auditor_password)
  ' \
  "$temporary_realm" >/dev/null

mv -- "$temporary_realm" "$target_realm"
trap - EXIT

printf 'Rendered Keycloak production realm: %s\n' "$target_realm"
