#!/usr/bin/env bash
#
# validate.sh
# Ejecuta el contrato offline de OpenTofu: formato, controles de material
# sensible, tests de scripts, init sin backend, validate y tests con mocks.
#
# Uso:
#   scripts/opentofu/validate.sh
#
# Red:
#   OpenTofu puede descargar providers si no están en caché, pero no autentica
#   contra GCP ni consulta recursos del proyecto.

set -Eeuo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repository_root"

export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-${TMPDIR:-/tmp}/inventory-opentofu-plugin-cache}"
mkdir -p "$TF_PLUGIN_CACHE_DIR"

readonly roots=(
  infra/opentofu/bootstrap
  infra/opentofu/platform
  infra/opentofu/environments/development
  infra/opentofu/environments/staging
  infra/opentofu/environments/production
)

tofu fmt -check -recursive infra/opentofu
./tests/opentofu/test-render-ci-config.sh
./tests/opentofu/test-seed-runtime-secrets.sh
./tests/opentofu/test-ci-deployment-gates.sh
node ./tests/opentofu/test-infra-doc-links.mjs

if rg -n \
  '(^|[[:space:]])(secret_data|credentials)[[:space:]]*=' \
  infra/opentofu \
  --glob '*.tf' \
  --glob '*.tfvars.example'; then
  echo "OpenTofu must not manage secret values or credential files." >&2
  exit 1
fi

if find infra/opentofu -type f \
  \( -name '*.tfstate' -o -name '*.tfplan' -o -name '*.json.key' \) \
  -print -quit |
  grep -q .; then
  echo "Generated state, plan or service-account key material is present." >&2
  exit 1
fi

for root in "${roots[@]}"; do
  tofu -chdir="$root" init -backend=false -input=false
  tofu -chdir="$root" validate
done

for environment in development staging production; do
  tofu -chdir="infra/opentofu/environments/$environment" test -no-color
done

bash -n frontend/docker-entrypoint.sh

echo "OpenTofu validation completed without contacting Google Cloud APIs."
