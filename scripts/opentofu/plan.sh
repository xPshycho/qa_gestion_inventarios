#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
  echo "usage: scripts/opentofu/plan.sh <platform|development|staging|production> <backend.hcl> <terraform.tfvars> [plan-output]" >&2
}

[[ $# -ge 3 && $# -le 4 ]] || {
  usage
  exit 2
}

readonly stack="$1"
readonly backend_config="$2"
readonly variable_file="$3"
readonly plan_output="${4:-${stack}.tfplan}"
readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

case "$stack" in
  platform)
    stack_directory="$repository_root/infra/opentofu/platform"
    ;;
  development|staging|production)
    stack_directory="$repository_root/infra/opentofu/environments/$stack"
    ;;
  *)
    usage
    exit 2
    ;;
esac

for required_file in "$backend_config" "$variable_file"; do
  [[ -f "$required_file" ]] || {
    echo "required file not found: $required_file" >&2
    exit 1
  }
done

[[ "$plan_output" == *.tfplan ]] || {
  echo "plan output must end in .tfplan" >&2
  exit 1
}

tofu -chdir="$stack_directory" init \
  -input=false \
  -reconfigure \
  -backend-config="$backend_config"

tofu -chdir="$stack_directory" plan \
  -input=false \
  -lock-timeout=5m \
  -var-file="$variable_file" \
  -out="$plan_output"

tofu -chdir="$stack_directory" show -no-color "$plan_output"
