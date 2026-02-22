#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="dev"
PRIMARY_REGION="ap-southeast-1"
SECONDARY_REGION="ap-southeast-2"
PRIMARY_CLUSTER=""
SECONDARY_CLUSTER=""
NLB_NAME="hotel-api-private"
WEB_NAMESPACE="hotel"
WEB_INGRESS_NAME="hotel-web"

usage() {
  cat <<EOF
Usage:
  $(basename "$0") --primary-cluster <name> --secondary-cluster <name> [options]

Options:
  --env <dev|uat|prod>            Environment label (default: dev)
  --primary-region <region>       Default: ap-southeast-1
  --secondary-region <region>     Default: ap-southeast-2
  --nlb-name <name>               Default: hotel-api-private
  --web-namespace <namespace>     Default: hotel
  --web-ingress <name>            Default: hotel-web
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --primary-region)
      PRIMARY_REGION="$2"
      shift 2
      ;;
    --secondary-region)
      SECONDARY_REGION="$2"
      shift 2
      ;;
    --primary-cluster)
      PRIMARY_CLUSTER="$2"
      shift 2
      ;;
    --secondary-cluster)
      SECONDARY_CLUSTER="$2"
      shift 2
      ;;
    --nlb-name)
      NLB_NAME="$2"
      shift 2
      ;;
    --web-namespace)
      WEB_NAMESPACE="$2"
      shift 2
      ;;
    --web-ingress)
      WEB_INGRESS_NAME="$2"
      shift 2
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

if [[ -z "${PRIMARY_CLUSTER}" || -z "${SECONDARY_CLUSTER}" ]]; then
  echo "ERROR: --primary-cluster and --secondary-cluster are required."
  exit 1
fi

collect_values() {
  local region="$1"
  local cluster="$2"
  local out_prefix="$3"

  aws eks update-kubeconfig --region "${region}" --name "${cluster}" --alias "${cluster}" >/dev/null

  local web_dns
  web_dns="$(kubectl --context "${cluster}" -n "${WEB_NAMESPACE}" get ingress "${WEB_INGRESS_NAME}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
  if [[ -z "${web_dns}" ]]; then
    echo "ERROR: could not resolve ALB DNS from ingress '${WEB_NAMESPACE}/${WEB_INGRESS_NAME}' in cluster '${cluster}'"
    exit 1
  fi

  local lb_arn
  lb_arn="$(aws elbv2 describe-load-balancers --region "${region}" --names "${NLB_NAME}" --query 'LoadBalancers[0].LoadBalancerArn' --output text)"

  local listener_arn
  listener_arn="$(aws elbv2 describe-listeners --region "${region}" --load-balancer-arn "${lb_arn}" --query 'Listeners[?Port==`80`].ListenerArn | [0]' --output text)"

  if [[ -z "${listener_arn}" || "${listener_arn}" == "None" ]]; then
    echo "ERROR: no port 80 listener found for NLB '${NLB_NAME}' in region '${region}'"
    exit 1
  fi

  printf -v "${out_prefix}_web_alb_dns" "%s" "${web_dns}"
  printf -v "${out_prefix}_nlb_listener_arn" "%s" "${listener_arn}"
}

collect_values "${PRIMARY_REGION}" "${PRIMARY_CLUSTER}" "primary"
collect_values "${SECONDARY_REGION}" "${SECONDARY_CLUSTER}" "secondary"

cat <<EOF
# Paste into terraform/environments/${ENVIRONMENT}/edge.tfvars
primary_eks_nlb_listener_arn   = "${primary_nlb_listener_arn}"
secondary_eks_nlb_listener_arn = "${secondary_nlb_listener_arn}"
primary_web_alb_dns_name       = "${primary_web_alb_dns}"
secondary_web_alb_dns_name     = "${secondary_web_alb_dns}"
EOF
