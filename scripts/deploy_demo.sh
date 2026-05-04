#!/usr/bin/env bash
# =============================================================================
# deploy_demo.sh — Deploy Online Boutique demo to EKS cluster
# Usage: ./scripts/deploy_demo.sh [--remove]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
MANIFEST="${REPO_ROOT}/kubernetes/demo/online-boutique.yaml"
NAMESPACE="hotel"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ---------- Pre-flight ----------
check_prereqs() {
  for cmd in kubectl; do
    if ! command -v "$cmd" &>/dev/null; then
      log_error "$cmd not found. Install it first."
      exit 1
    fi
  done

  if ! kubectl cluster-info &>/dev/null; then
    log_error "Cannot reach Kubernetes cluster. Check kubeconfig."
    exit 1
  fi
  log_info "Cluster reachable: $(kubectl cluster-info 2>/dev/null | head -1)"
}

# ---------- Deploy ----------
deploy() {
  log_info "Deploying Online Boutique demo to namespace '${NAMESPACE}'..."
  kubectl apply -f "$MANIFEST"

  log_info "Waiting for all deployments to be available (timeout 5m)..."
  local deployments
  deployments=$(kubectl get deploy -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')

  for deploy_name in $deployments; do
    log_info "  Waiting for ${deploy_name}..."
    kubectl rollout status deployment/"$deploy_name" -n "$NAMESPACE" --timeout=300s || {
      log_warn "  ${deploy_name} did not become ready in time."
    }
  done

  echo ""
  log_info "=== Deployment Summary ==="
  kubectl get pods -n "$NAMESPACE" -o wide
  echo ""

  # Wait for external LB URL
  local lb_url=""
  local attempts=0
  local max_attempts=30

  log_info "Waiting for LoadBalancer hostname..."
  while [[ -z "$lb_url" && $attempts -lt $max_attempts ]]; do
    lb_url=$(kubectl get svc public-api-bff-external -n "$NAMESPACE" \
      -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
    
    if [[ -z "$lb_url" ]]; then
      sleep 10
      attempts=$((attempts+1))
    fi
  done

  if [[ -n "$lb_url" ]]; then
    log_info "Demo LoadBalancer Hostname: ${lb_url}"
    
    if [[ -n "${TF_VAR_cloudflare_api_token:-}" ]]; then
      log_info "Cloudflare token detected. Configuring DNS..."
      (
        cd "${REPO_ROOT}/terraform/stacks/demo-dns"
        terraform init
        terraform apply -auto-approve -var="nlb_hostname=${lb_url}"
      )
      log_info "Demo Frontend: https://demo.yangonai.com"
    else
      log_warn "TF_VAR_cloudflare_api_token not set. Skipping DNS configuration."
      log_info "Demo Frontend: http://${lb_url}"
    fi
  else
    log_warn "LoadBalancer not provisioned within timeout. Check AWS/EKS status."
    echo "  kubectl get svc public-api-bff-external -n ${NAMESPACE}"
  fi
}

# ---------- Remove ----------
remove() {
  log_warn "Removing Online Boutique demo from namespace '${NAMESPACE}'..."
  kubectl delete -f "$MANIFEST" --ignore-not-found
  log_info "Demo removed."
}

# ---------- Main ----------
check_prereqs

if [[ "${1:-}" == "--remove" ]]; then
  remove
else
  deploy
fi
