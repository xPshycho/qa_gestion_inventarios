#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
  echo "usage: scripts/opentofu/render-ci-config.sh <platform|development|staging|production> <output-directory>" >&2
}

fail() {
  echo "OpenTofu CI configuration error: $*" >&2
  exit 1
}

[[ $# -eq 2 ]] || {
  usage
  exit 2
}

readonly stack="$1"
readonly output_directory="$2"
readonly zero_digest="0000000000000000000000000000000000000000000000000000000000000000"

case "$stack" in
  platform|development|staging|production) ;;
  *)
    usage
    exit 2
    ;;
esac

readonly project_id="${GCP_PROJECT_ID:-}"
readonly region="${GCP_REGION:-}"
readonly state_bucket="${GCP_STATE_BUCKET:-}"
readonly repository_id="${GCP_ARTIFACT_REPOSITORY:-inventory-images}"
readonly deploy_services="${DEPLOY_SERVICES:-false}"
readonly secret_version="${SECRET_VERSION:-1}"

[[ "$project_id" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]] ||
  fail "GCP_PROJECT_ID is missing or invalid."
[[ "$region" =~ ^[a-z]+-[a-z0-9]+[0-9]$ ]] ||
  fail "GCP_REGION is missing or invalid."
[[ "$state_bucket" =~ ^[a-z0-9][a-z0-9._-]{1,220}[a-z0-9]$ ]] ||
  fail "GCP_STATE_BUCKET is missing or invalid."
[[ "$repository_id" =~ ^[a-z][a-z0-9-]{2,61}[a-z0-9]$ ]] ||
  fail "GCP_ARTIFACT_REPOSITORY is invalid."
[[ "$deploy_services" == "true" || "$deploy_services" == "false" ]] ||
  fail "DEPLOY_SERVICES must be true or false."
[[ "$secret_version" =~ ^[1-9][0-9]*$ ]] ||
  fail "SECRET_VERSION must be a positive numeric version."

umask 077
mkdir -p "$output_directory"
[[ -d "$output_directory" ]] || fail "could not create output directory."

readonly backend_file="$output_directory/backend.hcl"
readonly variables_file="$output_directory/terraform.tfvars"

if [[ "$stack" == "platform" ]]; then
  readonly github_repository_id="${GITHUB_REPOSITORY_ID:-}"
  readonly github_repository_owner_id="${GITHUB_REPOSITORY_OWNER_ID:-}"
  [[ "$github_repository_id" =~ ^[1-9][0-9]*$ ]] ||
    fail "GITHUB_REPOSITORY_ID is missing or invalid."
  [[ "$github_repository_owner_id" =~ ^[1-9][0-9]*$ ]] ||
    fail "GITHUB_REPOSITORY_OWNER_ID is missing or invalid."

  readonly state_prefix="inventory/platform"
else
  readonly state_prefix="inventory/environments/$stack"
fi

{
  printf 'bucket = "%s"\n' "$state_bucket"
  printf 'prefix = "%s"\n' "$state_prefix"
} >"$backend_file"

if [[ "$stack" == "platform" ]]; then
  {
    printf 'project_id    = "%s"\n' "$project_id"
    printf 'region        = "%s"\n' "$region"
    printf 'repository_id = "%s"\n' "$repository_id"
    printf 'state_bucket_name          = "%s"\n' "$state_bucket"
    printf 'github_repository_id       = "%s"\n' "$github_repository_id"
    printf 'github_repository_owner_id = "%s"\n' "$github_repository_owner_id"
    printf 'labels = {\n'
    printf '  managed_by = "opentofu"\n'
    printf '  owner      = "qa-team"\n'
    printf '}\n'
  } >"$variables_file"
else
  frontend_image="${FRONTEND_IMAGE:-$region-docker.pkg.dev/$project_id/$repository_id/frontend@sha256:$zero_digest}"
  backend_image="${BACKEND_IMAGE:-$region-docker.pkg.dev/$project_id/$repository_id/backend@sha256:$zero_digest}"
  keycloak_image="${KEYCLOAK_IMAGE:-$region-docker.pkg.dev/$project_id/$repository_id/keycloak@sha256:$zero_digest}"
  cloud_sql_proxy_image="${CLOUD_SQL_PROXY_IMAGE:-gcr.io/cloud-sql-connectors/cloud-sql-proxy@sha256:$zero_digest}"

  if [[ "$deploy_services" == "true" ]]; then
    readonly immutable_image_pattern='^[-a-z0-9._/:]+@sha256:[0-9a-f]{64}$'
    for image in \
      "$frontend_image" \
      "$backend_image" \
      "$keycloak_image" \
      "$cloud_sql_proxy_image"; do
      [[ "$image" =~ $immutable_image_pattern ]] ||
        fail "service image references must use a full sha256 digest."
      [[ "$image" != *"@sha256:$zero_digest" ]] ||
        fail "the all-zero placeholder digest cannot deploy services."
    done
  fi

  {
    printf 'project_id     = "%s"\n' "$project_id"
    printf 'region         = "%s"\n' "$region"
    printf 'deploy_services = %s\n' "$deploy_services"
    printf 'frontend_image        = "%s"\n' "$frontend_image"
    printf 'backend_image         = "%s"\n' "$backend_image"
    printf 'keycloak_image        = "%s"\n' "$keycloak_image"
    printf 'cloud_sql_proxy_image = "%s"\n' "$cloud_sql_proxy_image"
    printf 'secret_version        = "%s"\n' "$secret_version"
    printf 'labels = {\n'
    printf '  environment = "%s"\n' "$stack"
    printf '  managed_by  = "opentofu"\n'
    printf '  owner       = "qa-team"\n'
    printf '}\n'
  } >"$variables_file"
fi

chmod 0600 "$backend_file" "$variables_file"
printf 'Rendered %s configuration in %s\n' "$stack" "$output_directory"
