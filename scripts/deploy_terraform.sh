#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_STACKS=("network" "platform-eks" "data" "edge" "observability")

ENVIRONMENT="dev"
ACTION="plan"
STACKS_CSV=""
AUTO_APPROVE="false"

usage() {
  cat <<EOF
Usage:
  $(basename "$0") --env <dev|uat|prod> --action <plan|apply> [--stacks <csv>] [--auto-approve]

Required environment variables:
  TF_STATE_BUCKET   S3 bucket for Terraform state

Optional environment variables:
  TF_STATE_REGION   Backend region (default: ap-southeast-1)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --action)
      ACTION="$2"
      shift 2
      ;;
    --stacks)
      STACKS_CSV="$2"
      shift 2
      ;;
    --auto-approve)
      AUTO_APPROVE="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument '$1'"
      usage
      exit 1
      ;;
  esac
done

if [[ "${ACTION}" != "plan" && "${ACTION}" != "apply" ]]; then
  echo "ERROR: --action must be one of: plan, apply"
  exit 1
fi

if [[ -z "${TF_STATE_BUCKET:-}" ]]; then
  echo "ERROR: TF_STATE_BUCKET is required."
  exit 1
fi

TF_STATE_REGION="${TF_STATE_REGION:-ap-southeast-1}"

if [[ -n "${STACKS_CSV}" ]]; then
  IFS=',' read -r -a STACKS <<< "${STACKS_CSV}"
else
  STACKS=("${DEFAULT_STACKS[@]}")
fi

PLAN_DIR="${ROOT_DIR}/terraform/.plans/${ENVIRONMENT}"
mkdir -p "${PLAN_DIR}"

echo "Environment: ${ENVIRONMENT}"
echo "Action: ${ACTION}"
echo "Stacks: ${STACKS[*]}"

for stack in "${STACKS[@]}"; do
  stack_dir="${ROOT_DIR}/terraform/stacks/${stack}"
  tfvars_file="${ROOT_DIR}/terraform/environments/${ENVIRONMENT}/${stack}.tfvars"
  state_key="${ENVIRONMENT}/stacks/${stack}/terraform.tfstate"
  plan_file="${PLAN_DIR}/${stack}.tfplan"

  if [[ ! -d "${stack_dir}" ]]; then
    echo "ERROR: stack directory not found: ${stack_dir}"
    exit 1
  fi

  if [[ ! -f "${tfvars_file}" ]]; then
    echo "ERROR: tfvars file not found: ${tfvars_file}"
    exit 1
  fi

  echo
  echo "==> Stack: ${stack}"

  terraform -chdir="${stack_dir}" init -reconfigure \
    -backend-config="bucket=${TF_STATE_BUCKET}" \
    -backend-config="key=${state_key}" \
    -backend-config="region=${TF_STATE_REGION}" \
    -backend-config="use_lockfile=true" \
    -backend-config="encrypt=true"

  terraform -chdir="${stack_dir}" validate
  terraform -chdir="${stack_dir}" plan -var-file="${tfvars_file}" -out="${plan_file}"

  if [[ "${ACTION}" == "apply" ]]; then
    if [[ "${AUTO_APPROVE}" == "true" ]]; then
      terraform -chdir="${stack_dir}" apply -auto-approve "${plan_file}"
    else
      terraform -chdir="${stack_dir}" apply "${plan_file}"
    fi
  fi
done

echo
if [[ "${ACTION}" == "plan" ]]; then
  echo "Terraform plan completed for environment '${ENVIRONMENT}'."
else
  echo "Terraform apply completed for environment '${ENVIRONMENT}'."
fi
