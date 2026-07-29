#!/usr/bin/env bash

set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly repository_root="$(cd -- "$script_dir/../.." && pwd)"
declare -a phase_results=()
failed_phases=0

record_phase() {
  local name="$1"
  local exit_code="$2"
  local result=PASS
  if [[ "$exit_code" -ne 0 ]]; then
    result=FAIL
    failed_phases=$((failed_phases + 1))
  fi
  phase_results+=("$name:$result:$exit_code")
}

run_phase() {
  local name="$1"
  shift
  printf '\n==> %s\n' "$name"
  set +e
  "$@"
  local exit_code=$?
  set -e
  record_phase "$name" "$exit_code"
}

run_frontend_tests() {
  pnpm --dir "$repository_root/frontend" install --frozen-lockfile
  pnpm --dir "$repository_root/frontend" build
  pnpm --dir "$repository_root/frontend" test
}

cd "$repository_root"

command -v awk >/dev/null
command -v docker >/dev/null
command -v java >/dev/null
command -v pnpm >/dev/null
docker version >/dev/null
docker compose version >/dev/null

./scripts/security/init-secret-env.sh local

run_phase backend-build \
  bash -c 'cd backend && ../scripts/testing/run_with_java_21.sh ./gradlew clean assemble --no-daemon'
run_phase backend-unit \
  bash -c 'cd backend && ../scripts/testing/run_with_java_21.sh ./gradlew test jacocoTestReport jacocoTestCoverageVerification --no-daemon'
run_phase backend-api \
  bash -c 'cd backend && ../scripts/testing/run_with_java_21.sh ./gradlew apiTest --no-daemon'
run_phase backend-integration \
  bash -c 'cd backend && ../scripts/testing/run_with_java_21.sh ./gradlew integrationTest jacocoIntegrationTestCoverageVerification --no-daemon'
run_phase frontend run_frontend_tests
run_phase e2e "$repository_root/tests/e2e/scripts/run-local.sh"
run_phase performance "$repository_root/tests/performance/run-local.sh"
run_phase security "$repository_root/tests/security/run-local.sh"
run_phase collect-results "$repository_root/scripts/testing/collect_local_test_results.sh"

printf '\nLocal test summary\n'
for phase_result in "${phase_results[@]}"; do
  IFS=: read -r phase result exit_code <<< "$phase_result"
  printf '%-22s %-4s (exit %s)\n' "$phase" "$result" "$exit_code"
done
printf '\nResults: %s/test-results\n' "$repository_root"

if [[ "$failed_phases" -ne 0 ]]; then
  printf '%d local test phase(s) failed.\n' "$failed_phases" >&2
  exit 1
fi
