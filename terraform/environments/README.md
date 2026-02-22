# Environment Configuration (dev / uat / prod)

Each environment has dedicated variable files for every stack.

## Files

For each environment folder:
- `network.tfvars`
- `platform-eks.tfvars`
- `data.tfvars`
- `edge.tfvars`
- `observability.tfvars`

## Best Practice

1. Use separate AWS accounts per environment.
2. Use separate state keys per environment and stack.
3. Promote changes through `dev -> uat -> prod` in CI/CD.

## Example Apply

```bash
cd terraform/stacks/network
terraform init \
  -backend-config="bucket=example-hotel-tfstate" \
  -backend-config="key=dev/stacks/network/terraform.tfstate" \
  -backend-config="region=ap-southeast-1" \
  -backend-config="dynamodb_table=terraform-state-lock" \
  -backend-config="encrypt=true"
terraform apply -var-file="../../environments/dev/network.tfvars"
```
