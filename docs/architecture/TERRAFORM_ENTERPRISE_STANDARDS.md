# Terraform Enterprise Production Standards

## Stack and State Strategy

1. Split by blast radius and ownership: `network`, `platform-eks`, `data`, `edge`, `observability`.
2. Use remote state in S3 with DynamoDB lock table.
3. Enable state bucket versioning, SSE-KMS, and retention controls.
4. Use environment-partitioned state keys:
- `dev/stacks/<stack>/terraform.tfstate`
- `uat/stacks/<stack>/terraform.tfstate`
- `prod/stacks/<stack>/terraform.tfstate`

## Governance Controls

1. Provider and module versions are pinned.
2. PR gates run `terraform fmt`, `validate`, `tflint`, `tfsec`, `checkov`, and OPA policies.
3. Policy checks block public EKS endpoints and unsafe network rules.

## Delivery Controls

1. `plan` must run in CI for all changed stacks.
2. `apply` requires approval and environment-specific role assumption.
3. Drift detection runs on schedule and alerts to operations channel.

## Account and Region Strategy

1. Use separate environments: `dev`, `uat`, `prod`.
2. Prefer separate AWS accounts per environment (minimum: separate prod account).
3. Separate accounts for security and log archive.
4. Active region: `ap-southeast-1`; passive region: `ap-southeast-2`.
5. Shared standards must be codified as reusable modules.
