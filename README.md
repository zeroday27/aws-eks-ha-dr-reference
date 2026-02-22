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

1. Initialize a stack:
```bash
cd terraform/stacks/network
terraform init
```

2. Validate with environment tfvars:
```bash
terraform validate
terraform plan -var-file=../../environments/dev/network.tfvars
```

3. Apply in stack order:
- `network`
- `platform-eks`
- `data`
- `edge`
- `observability`

## Notes

- Replace placeholder ARNs, domains, and account IDs in `terraform/environments/*/*.tfvars` before deployment.
- This repo includes reference manifests; tune resources, policies, and workload identities for your org.
