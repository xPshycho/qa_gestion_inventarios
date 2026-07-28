#!/usr/bin/env bash

set -euo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly repository_root="$(cd -- "$script_dir/../.." && pwd)"
readonly mode="${1:---staged}"
readonly config="$repository_root/.gitleaks.toml"

command -v gitleaks >/dev/null 2>&1 || {
  printf 'gitleaks is required. Install it from https://github.com/gitleaks/gitleaks/releases\n' >&2
  exit 127
}

case "$mode" in
  --staged)
    exec gitleaks git "$repository_root" \
      --staged \
      --config "$config" \
      --redact=100 \
      --no-banner
    ;;
  --history)
    exec gitleaks git "$repository_root" \
      --log-opts=HEAD \
      --config "$config" \
      --redact=100 \
      --no-banner
    ;;
  --current)
    temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/inventory-gitleaks.XXXXXX")"
    cleanup() {
      case "$temporary_root" in
        "${TMPDIR:-/tmp}"/inventory-gitleaks.*)
          rm -rf -- "$temporary_root"
          ;;
      esac
    }
    trap cleanup EXIT

    mkdir "$temporary_root/tree"
    git -C "$repository_root" archive \
      --format=tar \
      --output="$temporary_root/tracked.tar" \
      HEAD
    tar -xf "$temporary_root/tracked.tar" -C "$temporary_root/tree"
    gitleaks dir "$temporary_root/tree" \
      --config "$config" \
      --redact=100 \
      --no-banner
    ;;
  --worktree)
    temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/inventory-gitleaks.XXXXXX")"
    cleanup() {
      case "$temporary_root" in
        "${TMPDIR:-/tmp}"/inventory-gitleaks.*)
          rm -rf -- "$temporary_root"
          ;;
      esac
    }
    trap cleanup EXIT

    mkdir "$temporary_root/tree"
    git -C "$repository_root" ls-files \
      --cached \
      --others \
      --exclude-standard \
      -z |
      while IFS= read -r -d '' versionable_path; do
        if [[ -e "$repository_root/$versionable_path" \
          || -L "$repository_root/$versionable_path" ]]; then
          printf '%s\0' "$versionable_path"
        fi
      done |
      tar \
        --directory="$repository_root" \
        --null \
        --files-from=- \
        --create \
        --file="$temporary_root/versionable.tar"
    tar -xf "$temporary_root/versionable.tar" -C "$temporary_root/tree"
    gitleaks dir "$temporary_root/tree" \
      --config "$config" \
      --redact=100 \
      --no-banner
    ;;
  *)
    printf 'Usage: %s [--staged|--current|--worktree|--history]\n' "$0" >&2
    exit 2
    ;;
esac
