#!/usr/bin/env bash
set -euo pipefail

PRIMARY_REGION="${PRIMARY_REGION:-ap-southeast-1}"
SECONDARY_REGION="${SECONDARY_REGION:-ap-southeast-2}"

required_commands=(
  terraform
  aws
  kubectl
  helm
  jq
  envsubst
)

echo "==> Checking required CLI tools"
for cmd in "${required_commands[@]}"; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "ERROR: missing command '${cmd}'"
    exit 1
  fi
done

echo "==> Checking AWS credentials"
aws sts get-caller-identity >/dev/null

echo "==> Checking region access"
aws ec2 describe-availability-zones --region "${PRIMARY_REGION}" --all-availability-zones >/dev/null
aws ec2 describe-availability-zones --region "${SECONDARY_REGION}" --all-availability-zones >/dev/null

echo "==> Tool versions"
terraform version | head -n 1
aws --version
kubectl version --client
helm version --short

echo "Preflight checks completed successfully."
