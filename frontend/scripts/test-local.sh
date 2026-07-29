#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly frontend_directory="$(cd -- "$script_dir/.." && pwd)"
readonly repository_root="$(cd -- "$frontend_directory/.." && pwd)"
readonly playwright_image="${PLAYWRIGHT_IMAGE:-mcr.microsoft.com/playwright:v1.60.0-noble}"

command -v docker >/dev/null
docker version >/dev/null
docker pull "$playwright_image"

set +e
docker run --rm --ipc=host \
  --user "$(id -u):$(id -g)" \
  --volume "$repository_root:/work" \
  --workdir /work/frontend \
  "$playwright_image" \
  bash -ceu '
    chrome_path="$(
      find /ms-playwright -type f \
        \( -path "*/chrome-linux/chrome" -o -path "*/chrome-linux64/chrome" \) \
        -print -quit
    )"
    test -x "$chrome_path"
    CHROME_BIN="$chrome_path" \
      ./node_modules/.bin/ng test \
        --watch=false \
        --browsers=ChromeHeadlessNoSandbox \
        --code-coverage
  '
test_exit_code=$?
set -e

status=failed
[[ "$test_exit_code" -eq 0 ]] && status=passed
python3 "$repository_root/scripts/testing/collect_test_results.py" \
  --suite frontend/unit \
  --status "$status" \
  --output-root "$repository_root/test-results" \
  --copy coverage="$frontend_directory/coverage" \
  --metadata workflow=local \
  --metadata browser=playwright-docker \
  --metadata junit=not-generated-by-karma

exit "$test_exit_code"
