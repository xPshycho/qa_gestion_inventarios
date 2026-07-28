#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$script_dir/common.sh"

require_command docker
require_command jq
require_command sha256sum
load_staging_env
ensure_evidence_dir

readonly collected_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
readonly commit_sha="$(git -C "$STAGING_REPOSITORY_ROOT" rev-parse HEAD)"
if [[ -n "$(git -C "$STAGING_REPOSITORY_ROOT" status --porcelain --untracked-files=all)" ]]; then
  readonly worktree_dirty=true
else
  readonly worktree_dirty=false
fi
readonly source_fingerprint="$(
  {
    git -C "$STAGING_REPOSITORY_ROOT" diff --binary HEAD
    while IFS= read -r -d '' untracked_file; do
      printf '%s\0' "$untracked_file"
      sha256sum -- "$STAGING_REPOSITORY_ROOT/$untracked_file"
    done < <(
      git -C "$STAGING_REPOSITORY_ROOT" \
        ls-files --others --exclude-standard -z |
        sort --zero-terminated
    )
  } | sha256sum | awk '{ print $1 }'
)"
readonly backend_image_id="$(
  docker image inspect \
    --format '{{.Id}}' \
    "inventory-backend:$APP_VERSION" \
    2>/dev/null || true
)"
readonly frontend_image_id="$(
  docker image inspect \
    --format '{{.Id}}' \
    "inventory-frontend:$APP_VERSION" \
    2>/dev/null || true
)"
if [[ -n "${GITHUB_RUN_ID:-}" ]]; then
  readonly run_url="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
else
  readonly run_url=""
fi

staging_compose ps --all > "$STAGING_EVIDENCE_DIR/compose-ps.txt" || true
staging_compose images > "$STAGING_EVIDENCE_DIR/compose-images.txt" || true

staging_compose logs --no-color --timestamps 2>&1 |
  redact_staging_secrets > "$STAGING_EVIDENCE_DIR/compose.log" || true

readonly running_services="$(
  staging_compose ps --services --status running 2>/dev/null |
    awk 'NF { count += 1 } END { print count + 0 }'
)"

jq --null-input \
  --arg collectedAt "$collected_at" \
  --arg deploymentId "$STAGING_DEPLOYMENT_ID" \
  --arg version "$APP_VERSION" \
  --arg commit "$commit_sha" \
  --arg sourceFingerprint "$source_fingerprint" \
  --arg project "$COMPOSE_PROJECT_NAME" \
  --arg frontendUrl "$STAGING_FRONTEND_URL" \
  --arg backendUrl "$STAGING_BACKEND_URL" \
  --arg keycloakUrl "$STAGING_KEYCLOAK_URL" \
  --arg lifecycle "$STAGING_LIFECYCLE" \
  --arg visibility "$STAGING_VISIBILITY" \
  --arg runUrl "$run_url" \
  --arg backendImageId "$backend_image_id" \
  --arg frontendImageId "$frontend_image_id" \
  --argjson runningServices "$running_services" \
  --argjson worktreeDirty "$worktree_dirty" \
  '{
    collectedAt: $collectedAt,
    deploymentId: $deploymentId,
    version: $version,
    commit: $commit,
    worktreeDirty: $worktreeDirty,
    sourceFingerprint: $sourceFingerprint,
    composeProject: $project,
    environment: "staging",
    lifecycle: $lifecycle,
    visibility: $visibility,
    runUrl: $runUrl,
    images: {
      backend: {
        tag: ("inventory-backend:" + $version),
        id: $backendImageId
      },
      frontend: {
        tag: ("inventory-frontend:" + $version),
        id: $frontendImageId
      }
    },
    urls: {
      frontend: $frontendUrl,
      backendDiagnostics: $backendUrl,
      keycloak: $keycloakUrl
    },
    runningServices: $runningServices
  }' > "$STAGING_EVIDENCE_DIR/deployment.json"

{
  printf '# Staging deployment evidence\n\n'
  printf -- '- Collected at: `%s`\n' "$collected_at"
  printf -- '- Deployment ID: `%s`\n' "$STAGING_DEPLOYMENT_ID"
  printf -- '- Commit: `%s`\n' "$commit_sha"
  printf -- '- Worktree dirty: `%s`\n' "$worktree_dirty"
  printf -- '- Source fingerprint: `%s`\n' "$source_fingerprint"
  printf -- '- Image version: `%s`\n' "$APP_VERSION"
  printf -- '- Compose project: `%s`\n' "$COMPOSE_PROJECT_NAME"
  printf -- '- Environment: `staging`\n'
  printf -- '- Lifecycle: `%s`\n' "$STAGING_LIFECYCLE"
  printf -- '- Visibility: `%s` (loopback only)\n' "$STAGING_VISIBILITY"
  printf -- '- Frontend URL: `%s`\n' "$STAGING_FRONTEND_URL"
  printf -- '- Backend diagnostics URL: `%s`\n' "$STAGING_BACKEND_URL"
  printf -- '- Keycloak URL: `%s`\n' "$STAGING_KEYCLOAK_URL"
  printf -- '- Backend image ID: `%s`\n' "${backend_image_id:-unavailable}"
  printf -- '- Frontend image ID: `%s`\n' "${frontend_image_id:-unavailable}"
  printf -- '- Running services: `%s`\n' "$running_services"
  printf '\nSecrets and rendered Compose configuration are intentionally excluded.\n'
} > "$STAGING_EVIDENCE_DIR/deployment-summary.md"

printf 'Staging evidence collected in %s\n' "$STAGING_EVIDENCE_DIR"
