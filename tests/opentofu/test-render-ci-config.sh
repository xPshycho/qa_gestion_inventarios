#!/usr/bin/env bash

set -Eeuo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly renderer="$repository_root/scripts/opentofu/render-ci-config.sh"
readonly temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/inventory-opentofu-render.XXXXXX")"

cleanup() {
  rm -rf -- "$temporary_root"
}
trap cleanup EXIT

fail() {
  echo "render-ci-config test failed: $*" >&2
  exit 1
}

assert_contains() {
  local expected="$1"
  local file="$2"
  grep -Fqx "$expected" "$file" ||
    fail "expected '$expected' in $file"
}

render() {
  local stack="$1"
  local destination="$2"
  env \
    GCP_PROJECT_ID="project-e70349a8-c787-4733-9a0" \
    GCP_REGION="us-central1" \
    GCP_STATE_BUCKET="project-e70349a8-c787-4733-9a0-opentofu-state" \
    GCP_ARTIFACT_REPOSITORY="inventory-images" \
    GITHUB_REPOSITORY_ID="1258796980" \
    GITHUB_REPOSITORY_OWNER_ID="115911218" \
    "$renderer" "$stack" "$destination"
}

render platform "$temporary_root/platform"
assert_contains 'prefix = "inventory/platform"' "$temporary_root/platform/backend.hcl"
assert_contains 'repository_id = "inventory-images"' "$temporary_root/platform/terraform.tfvars"

render development "$temporary_root/development"
assert_contains 'prefix = "inventory/environments/development"' "$temporary_root/development/backend.hcl"
assert_contains 'deploy_services = false' "$temporary_root/development/terraform.tfvars"

readonly digest="1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
env \
  GCP_PROJECT_ID="project-e70349a8-c787-4733-9a0" \
  GCP_REGION="us-central1" \
  GCP_STATE_BUCKET="project-e70349a8-c787-4733-9a0-opentofu-state" \
  DEPLOY_SERVICES=true \
  FRONTEND_IMAGE="us-central1-docker.pkg.dev/project-e70349a8-c787-4733-9a0/inventory-images/frontend@sha256:$digest" \
  BACKEND_IMAGE="us-central1-docker.pkg.dev/project-e70349a8-c787-4733-9a0/inventory-images/backend@sha256:$digest" \
  KEYCLOAK_IMAGE="us-central1-docker.pkg.dev/project-e70349a8-c787-4733-9a0/inventory-images/keycloak@sha256:$digest" \
  CLOUD_SQL_PROXY_IMAGE="gcr.io/cloud-sql-connectors/cloud-sql-proxy@sha256:$digest" \
  "$renderer" staging "$temporary_root/staging"
assert_contains 'deploy_services = true' "$temporary_root/staging/terraform.tfvars"

if GCP_PROJECT_ID="INVALID" \
  GCP_REGION="us-central1" \
  GCP_STATE_BUCKET="valid-state-bucket" \
  GITHUB_REPOSITORY_ID="1258796980" \
  GITHUB_REPOSITORY_OWNER_ID="115911218" \
  "$renderer" platform "$temporary_root/invalid-project"; then
  fail "invalid project ID was accepted"
fi

if GCP_PROJECT_ID="valid-project1" \
  GCP_REGION="us-central1" \
  GCP_STATE_BUCKET="valid-state-bucket" \
  DEPLOY_SERVICES=true \
  FRONTEND_IMAGE="example/frontend:latest" \
  BACKEND_IMAGE="example/backend:latest" \
  KEYCLOAK_IMAGE="example/keycloak:latest" \
  CLOUD_SQL_PROXY_IMAGE="example/proxy:latest" \
  "$renderer" development "$temporary_root/mutable-images"; then
  fail "mutable service images were accepted"
fi

if rg -n '(password|token|credential)[[:space:]]*=' "$temporary_root"; then
  fail "a generated file looks like it contains secret material"
fi

for generated_file in "$temporary_root"/*/{backend.hcl,terraform.tfvars}; do
  [[ "$(stat -c '%a' "$generated_file")" == "600" ]] ||
    fail "$generated_file does not use mode 0600"
done

echo "OpenTofu CI configuration renderer tests passed."
