#!/usr/bin/env bash

set -euo pipefail

readonly repository_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$repository_root/scripts/testing/local_compose.sh"

declare -a captured_arguments=()
pull_attempts=0
isolated_config=""
docker() {
  if [[ "${1:-}" == "pull" ]]; then
    pull_attempts=$((pull_attempts + 1))
    if [[ "$pull_attempts" -eq 1 ]]; then
      return 1
    fi
    isolated_config="${DOCKER_CONFIG:-}"
    return 0
  fi
  captured_arguments=("$@")
}

local_compose /workspace /workspace/.env inventory-test config --quiet

expected_arguments=(
  compose
  --env-file /workspace/.env
  --project-name inventory-test
  --project-directory /workspace
  --file /workspace/docker-compose.yml
  --file /workspace/docker-compose.override.yml
  config
  --quiet
)

[[ "${#captured_arguments[@]}" -eq "${#expected_arguments[@]}" ]]
for index in "${!expected_arguments[@]}"; do
  [[ "${captured_arguments[$index]}" == "${expected_arguments[$index]}" ]]
done

docker_pull_public_image example.invalid/tool:1
[[ "$pull_attempts" -eq 2 ]]
[[ -n "$isolated_config" ]]
[[ ! -e "$isolated_config" ]]

temporary_root="$(mktemp -d)"
trap 'find "$temporary_root" -depth -delete' EXIT
mkdir -p "$temporary_root/test-results/example/nested"
touch "$temporary_root/test-results/example/stale-result.json"
touch "$temporary_root/test-results/example/nested/stale-log.txt"

reset_test_result_directory "$temporary_root" test-results/example
[[ -d "$temporary_root/test-results/example" ]]
[[ -z "$(find "$temporary_root/test-results/example" -mindepth 1 -print -quit)" ]]

if reset_test_result_directory "$temporary_root" ../outside; then
  printf 'Unsafe result path was accepted.\n' >&2
  exit 1
fi

printf 'local_compose helper tests: PASS\n'
