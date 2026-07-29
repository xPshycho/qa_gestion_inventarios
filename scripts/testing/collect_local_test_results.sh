#!/usr/bin/env bash

set -euo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly repository_root="$(cd -- "$script_dir/../.." && pwd)"
readonly collector="$script_dir/collect_test_results.py"

cd "$repository_root"

command -v jq >/dev/null

collect_junit_suite() {
  local suite="$1"
  local junit_path="$2"
  shift 2
  local centralized_junit_path="test-results/$suite/evidence/junit"
  local effective_junit_path="$junit_path"
  local status=unknown
  if [[ -d "$junit_path" ]] \
    && [[ -n "$(find "$junit_path" -type f -name '*.xml' -print -quit)" ]]; then
    status=passed
  elif [[ -d "$centralized_junit_path" ]] \
    && [[ -n "$(find "$centralized_junit_path" -type f -name '*.xml' -print -quit)" ]]; then
    effective_junit_path="$centralized_junit_path"
    status=passed
  fi
  python3 "$collector" \
    --suite "$suite" \
    --status "$status" \
    --junit "$effective_junit_path" \
    "$@" \
    --metadata workflow=local
}

collect_junit_suite \
  backend/unit \
  backend/build/test-results/test \
  --copy junit=backend/build/test-results/test \
  --copy html=backend/build/reports/tests/test \
  --copy coverage=backend/build/reports/jacoco/test

collect_junit_suite \
  backend/api \
  backend/build/test-results/apiTest \
  --copy junit=backend/build/test-results/apiTest \
  --copy html=backend/build/reports/tests/apiTest

collect_junit_suite \
  backend/integration \
  backend/build/test-results/integrationTest \
  --copy junit=backend/build/test-results/integrationTest \
  --copy html=backend/build/reports/tests/integrationTest \
  --copy coverage=backend/build/reports/jacoco/integrationTest

frontend_status=unknown
[[ -d frontend/coverage ]] && frontend_status=passed
python3 "$collector" \
  --suite frontend/unit \
  --status "$frontend_status" \
  --copy coverage=frontend/coverage \
  --metadata workflow=local \
  --metadata junit=not-generated-by-karma

playwright_junit=test-results/e2e/playwright/evidence/junit
collect_junit_suite e2e/playwright "$playwright_junit"

k6_status=unknown
if [[ -f test-results/performance/k6/k6-summary.json ]]; then
  if jq -e '.thresholdsPassed == true' \
    test-results/performance/k6/k6-summary.json >/dev/null; then
    k6_status=passed
  else
    k6_status=failed
  fi
fi
python3 "$collector" \
  --suite performance/k6 \
  --status "$k6_status" \
  --metadata workflow=local \
  --metadata nativeSummary=k6-summary.json

for scanner in headers zap trivy; do
  scanner_status=unknown
  scanner_summary="test-results/security/$scanner/summary.json"
  if [[ -f "$scanner_summary" ]]; then
    existing_status="$(jq -r '.status // "unknown"' "$scanner_summary")"
    case "$existing_status" in
      passed|failed|cancelled|unknown)
        scanner_status="$existing_status"
        ;;
    esac
  fi
  python3 "$collector" \
    --suite "security/$scanner" \
    --status "$scanner_status" \
    --metadata workflow=local
done

if [[ -d .staging/evidence ]]; then
  ./scripts/staging/verify-evidence-safety.sh
  python3 "$collector" \
    --suite staging/post-deploy \
    --status passed \
    --copy evidence=.staging/evidence \
    --metadata workflow=local-staging
fi

printf 'Centralized test results are available at %s/test-results\n' "$repository_root"
