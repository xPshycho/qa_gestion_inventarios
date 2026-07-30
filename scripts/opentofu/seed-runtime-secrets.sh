#!/usr/bin/env bash

set -Eeuo pipefail

fail() {
  echo "Runtime secret bootstrap error: $*" >&2
  exit 1
}

[[ $# -eq 1 ]] || fail "usage: scripts/opentofu/seed-runtime-secrets.sh <development|staging>"

readonly environment="$1"
case "$environment" in
  development|staging) ;;
  *) fail "only development and staging can be bootstrapped by this script" ;;
esac

readonly project_id="${GCP_PROJECT_ID:-}"
[[ "$project_id" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]] ||
  fail "GCP_PROJECT_ID is missing or invalid"

readonly instance_name="inventory-$environment-postgres"
readonly prefix="inventory-$environment"
readonly secret_specs=(
  "inventory-db-password:INVENTORY_DB_PASSWORD"
  "keycloak-db-password:KEYCLOAK_DB_PASSWORD"
  "keycloak-admin-password:KEYCLOAK_ADMIN_PASSWORD"
  "keycloak-admin-client-secret:KEYCLOAK_ADMIN_CLIENT_SECRET"
  "e2e-admin-password:E2E_ADMIN_PASSWORD"
  "e2e-operator-password:E2E_OPERATOR_PASSWORD"
  "e2e-viewer-password:E2E_VIEWER_PASSWORD"
  "e2e-auditor-password:E2E_AUDITOR_PASSWORD"
)

declare -a versions=()

for spec in "${secret_specs[@]}"; do
  secret_suffix="${spec%%:*}"
  variable_name="${spec##*:}"
  secret_id="$prefix-$secret_suffix"
  secret_value="${!variable_name:-}"

  [[ -n "$secret_value" ]] || fail "$variable_name is required"
  [[ ${#secret_value} -ge 16 ]] || fail "$variable_name must contain at least 16 characters"

  current_version="$(
    gcloud secrets versions list "$secret_id" \
      --project="$project_id" \
      --filter='state=ENABLED' \
      --sort-by='~name' \
      --limit=1 \
      --format='value(name)'
  )"

  if [[ -z "$current_version" ]]; then
    printf '%s' "$secret_value" |
      gcloud secrets versions add "$secret_id" \
        --project="$project_id" \
        --data-file=- \
        --quiet >/dev/null
    current_version="$(
      gcloud secrets versions list "$secret_id" \
        --project="$project_id" \
        --filter='state=ENABLED' \
        --sort-by='~name' \
        --limit=1 \
        --format='value(name)'
    )"
  fi

  [[ "$current_version" =~ ^[1-9][0-9]*$ ]] ||
    fail "could not resolve a numeric enabled version for $secret_id"
  versions+=("$current_version")
done

readonly expected_version="${versions[0]}"
for version in "${versions[@]}"; do
  [[ "$version" == "$expected_version" ]] ||
    fail "secret versions are not aligned; rotate all environment secrets together"
done

if gcloud sql users list \
  --project="$project_id" \
  --instance="$instance_name" \
  --filter='name=inventory' \
  --format='value(name)' |
  grep -Fxq inventory; then
  gcloud sql users set-password inventory \
    --project="$project_id" \
    --instance="$instance_name" \
    --password="$INVENTORY_DB_PASSWORD" \
    --quiet >/dev/null
else
  gcloud sql users create inventory \
    --project="$project_id" \
    --instance="$instance_name" \
    --password="$INVENTORY_DB_PASSWORD" \
    --quiet >/dev/null
fi

if gcloud sql users list \
  --project="$project_id" \
  --instance="$instance_name" \
  --filter='name=keycloak' \
  --format='value(name)' |
  grep -Fxq keycloak; then
  gcloud sql users set-password keycloak \
    --project="$project_id" \
    --instance="$instance_name" \
    --password="$KEYCLOAK_DB_PASSWORD" \
    --quiet >/dev/null
else
  gcloud sql users create keycloak \
    --project="$project_id" \
    --instance="$instance_name" \
    --password="$KEYCLOAK_DB_PASSWORD" \
    --quiet >/dev/null
fi

printf '%s\n' "$expected_version"
