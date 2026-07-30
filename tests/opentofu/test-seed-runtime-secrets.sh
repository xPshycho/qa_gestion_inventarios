#!/usr/bin/env bash

set -Eeuo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT

mkdir -p "$temporary_directory/bin"

cat >"$temporary_directory/bin/gcloud" <<'GCLOUD'
#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$1 $2 $3 $4" == "secrets versions list inventory-"* ]]; then
  printf '1\n'
  exit 0
fi

if [[ "$1 $2 $3" == "sql users list" ]]; then
  for argument in "$@"; do
    case "$argument" in
      --filter=name=inventory)
        printf 'inventory\n'
        exit 0
        ;;
      --filter=name=keycloak)
        printf 'keycloak\n'
        exit 0
        ;;
    esac
  done
fi

if [[ "$1 $2 $3" == "sql users set-password" ]]; then
  exit 0
fi

printf 'unexpected gcloud invocation\n' >&2
exit 1
GCLOUD
chmod +x "$temporary_directory/bin/gcloud"

export PATH="$temporary_directory/bin:$PATH"
export GCP_PROJECT_ID="project-valid-12345"
export INVENTORY_DB_PASSWORD="test-inventory-password"
export KEYCLOAK_DB_PASSWORD="test-keycloak-db-password"
export KEYCLOAK_ADMIN_PASSWORD="test-keycloak-admin-password"
export KEYCLOAK_ADMIN_CLIENT_SECRET="test-keycloak-client-secret"
export E2E_ADMIN_PASSWORD="test-e2e-admin-password"
export E2E_OPERATOR_PASSWORD="test-e2e-operator-password"
export E2E_VIEWER_PASSWORD="test-e2e-viewer-password"
export E2E_AUDITOR_PASSWORD="test-e2e-auditor-password"

actual_version="$("$repository_root/scripts/opentofu/seed-runtime-secrets.sh" development)"
[[ "$actual_version" == "1" ]]

if "$repository_root/scripts/opentofu/seed-runtime-secrets.sh" production >/dev/null 2>&1; then
  echo "production bootstrap should have been rejected" >&2
  exit 1
fi

if INVENTORY_DB_PASSWORD=short \
  "$repository_root/scripts/opentofu/seed-runtime-secrets.sh" development \
  >/dev/null 2>&1; then
  echo "short secrets should have been rejected" >&2
  exit 1
fi

echo "OpenTofu runtime secret bootstrap tests passed."
