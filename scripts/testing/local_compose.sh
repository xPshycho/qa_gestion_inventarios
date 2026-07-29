#!/usr/bin/env bash

local_compose() {
  local compose_repository_root="$1"
  local compose_environment_file="$2"
  local compose_project_name="$3"
  shift 3

  docker compose \
    --env-file "$compose_environment_file" \
    --project-name "$compose_project_name" \
    --project-directory "$compose_repository_root" \
    --file "$compose_repository_root/docker-compose.yml" \
    --file "$compose_repository_root/docker-compose.override.yml" \
    "$@"
}

docker_pull_public_image() {
  local image="$1"
  local isolated_docker_config

  if docker pull "$image"; then
    return 0
  fi

  printf 'Docker pull failed; retrying public image without credential helpers: %s\n' \
    "$image" >&2
  isolated_docker_config="$(mktemp -d)"
  chmod 0700 "$isolated_docker_config"

  set +e
  DOCKER_CONFIG="$isolated_docker_config" docker pull "$image"
  local pull_exit_code=$?
  set -e

  find "$isolated_docker_config" -depth -delete
  return "$pull_exit_code"
}

wait_for_http_endpoint() {
  local label="$1"
  local url="$2"
  local timeout_seconds="${3:-120}"
  local deadline=$((SECONDS + timeout_seconds))

  until curl \
    --fail \
    --silent \
    --show-error \
    --max-time 5 \
    "$url" >/dev/null 2>&1; do
    if ((SECONDS >= deadline)); then
      printf 'Timed out waiting for %s at %s\n' "$label" "$url" >&2
      return 1
    fi
    sleep 2
  done

  printf '%s is reachable at %s\n' "$label" "$url"
}

capture_local_compose_diagnostics() {
  local diagnostic_repository_root="$1"
  local diagnostic_environment_file="$2"
  local diagnostic_project_name="$3"
  local diagnostic_output_directory="$4"

  mkdir -p "$diagnostic_output_directory"
  local_compose \
    "$diagnostic_repository_root" \
    "$diagnostic_environment_file" \
    "$diagnostic_project_name" \
    ps --all \
    > "$diagnostic_output_directory/compose-ps.txt" 2>&1 || true
  local_compose \
    "$diagnostic_repository_root" \
    "$diagnostic_environment_file" \
    "$diagnostic_project_name" \
    logs --no-color \
    > "$diagnostic_output_directory/compose.log" 2>&1 || true
}

reset_test_result_directory() {
  local reset_repository_root="$1"
  local relative_path="$2"
  local results_root="$reset_repository_root/test-results"
  local target="$reset_repository_root/$relative_path"

  case "$target" in
    "$results_root"/*) ;;
    *)
      printf 'Refusing to clear non-test result path: %s\n' "$target" >&2
      return 1
      ;;
  esac

  if [[ -d "$target" ]]; then
    find "$target" -mindepth 1 -depth -delete
  elif [[ -e "$target" ]]; then
    printf 'Expected a directory but found another file type: %s\n' "$target" >&2
    return 1
  fi
  mkdir -p "$target"
}
