# AWS EKS HA/DR Reference Architecture

Generic, production-oriented reference for:
- Functional Infrastructure-as-Code with Terraform
- Kubernetes manifests for EKS workloads
- Multi-region active/passive high-availability and disaster recovery patterns
- Event-driven API integration with API Gateway, SQS, EventBridge, and Lambda

## Scope

This repository is intentionally generic and reusable for assessment, POC, and internal platform blueprint work.

## Repository Structure

- `.github/workflows/` - Terraform governance CI checks
- `terraform/modules/` - reusable infrastructure modules
- `terraform/stacks/` - deployable stacks (`network`, `platform-eks`, `data`, `edge`, `observability`)
- `terraform/environments/` - per-environment tfvars (`dev`, `uat`, `prod`)
- `kubernetes/base/` - base manifests for services, autoscaling, policies, and observability
- `policy/terraform/` - policy as code (OPA/Rego)
- `docs/` - architecture, API contracts, runbooks, and testing plan
- `scripts/` - deployment helpers for preflight, Terraform stacks, manifest rendering, and edge input collection

## Environment Strategy

Use isolated environments:
- `dev`
- `uat`
- `prod`

Recommended enterprise pattern:
- Separate AWS accounts per environment
- Separate Terraform state keys per stack/environment
- Promotion flow: `dev -> uat -> prod`

## Quick Start

1. Run preflight checks:
```bash
./scripts/preflight.sh
```

2. Export backend variables:
```bash
export TF_STATE_BUCKET="<state_bucket>"
export TF_LOCK_TABLE="<lock_table>"
export TF_STATE_REGION="ap-southeast-1"
```

3. Plan/apply Terraform in stack order:
```bash
./scripts/deploy_terraform.sh --env dev --action plan
./scripts/deploy_terraform.sh --env dev --action apply
```

4. For full real-AWS POC steps (including EKS manifests and edge dependencies), use `docs/runbooks/DEV_POC_DEPLOYMENT.md`.

## Notes

- Replace placeholder ARNs, domains, and account IDs in `terraform/environments/*/*.tfvars` before deployment.
- This repo includes reference manifests; tune resources, policies, and workload identities for your org.
- Credential material is stored in AWS Secrets Manager and mounted via Secrets Store CSI; do not place credentials in environment variables or committed config files.
