# Terraform Stacks (Production Layout)

This repository now uses a stack-oriented Terraform layout:

1. `network`: Dual-region VPCs with 4 subnet tiers (public, app, data, integration) and VPC endpoints.
2. `platform-eks`: Primary and DR EKS clusters with Karpenter-ready IAM and IRSA.
3. `data`: Aurora Global Database + regional Redis.
4. `edge`: CloudFront + WAF + API Gateway regional ingress + EventBridge/Lambda event ingestion.
5. `observability`: Cross-region CloudWatch alarms and alert fanout.

## Apply Order

1. `network`
2. `platform-eks`
3. `data`
4. `edge`
5. `observability`

## Environment Model

Use separate configuration and state paths for each environment:
- `dev`
- `uat`
- `prod`

Environment variable files are under `terraform/environments/<env>/`.

## Backend Pattern

Each stack uses `backend "s3" {}` and must be initialized with explicit backend config:

```bash
terraform init \
  -backend-config="bucket=<tf_state_bucket>" \
  -backend-config="key=<env>/stacks/<stack>/terraform.tfstate" \
  -backend-config="region=ap-southeast-1" \
  -backend-config="dynamodb_table=<tf_lock_table>" \
  -backend-config="encrypt=true"
```
