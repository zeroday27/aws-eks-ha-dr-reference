#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-${ROOT_DIR}/kubernetes/rendered}"

required_vars=(
  AWS_ACCOUNT_ID
  AWS_REGION
  APP_ENV
  WORKLOAD_IRSA_ROLE_ARN
  KARPENTER_DISCOVERY_TAG
  KARPENTER_NODE_ROLE_NAME
  PRIMARY_AZ_1
  PRIMARY_AZ_2
  PRIMARY_AZ_3
  WEB_ALB_CERT_ARN
  DB_SECRET_ARN
  REDIS_SECRET_ARN
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "ERROR: required environment variable not set: ${var_name}"
    exit 1
  fi
done

mkdir -p "${OUTPUT_DIR}/workloads"

for file in "${ROOT_DIR}"/kubernetes/base/*.yaml; do
  envsubst < "${file}" > "${OUTPUT_DIR}/$(basename "${file}")"
done

for file in "${ROOT_DIR}"/kubernetes/base/workloads/*.yaml; do
  envsubst < "${file}" > "${OUTPUT_DIR}/workloads/$(basename "${file}")"
done

echo "Rendered manifests written to: ${OUTPUT_DIR}"
