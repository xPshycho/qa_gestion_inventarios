#!/usr/bin/env bash
#
# Regression contract for post-CI deployment gates. GitHub propagates skipped
# jobs through a needs chain unless the downstream condition uses always().

set -Eeuo pipefail

readonly workflow=".github/workflows/ci-required.yml"

job_block() {
  local -r job="$1"

  awk -v job="$job" '
    $0 == "  " job ":" { capture = 1 }
    capture && $0 ~ /^  [a-z0-9-]+:$/ && $0 != "  " job ":" { exit }
    capture { print }
  ' "$workflow"
}

assert_contains() {
  local -r job="$1"
  local -r expected="$2"
  local block

  block="$(job_block "$job")"
  [[ -n "$block" ]] || {
    echo "missing workflow job: $job" >&2
    return 1
  }
  grep -Fq "$expected" <<<"$block" || {
    echo "job $job is missing deployment gate: $expected" >&2
    return 1
  }
}

for job in staging gcp-development gcp-staging; do
  assert_contains "$job" "always()"
  assert_contains "$job" "needs.ci-required.result == 'success'"
done

assert_contains gcp-development "github.ref == 'refs/heads/develop'"
assert_contains gcp-staging "needs.staging.result == 'success'"
assert_contains gcp-staging "github.ref == 'refs/heads/staging'"

echo "Post-CI deployment gates preserve successful promotions after skipped jobs."
