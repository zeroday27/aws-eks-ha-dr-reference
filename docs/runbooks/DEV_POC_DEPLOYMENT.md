# Dev POC Deployment Runbook (AWS Real Environment)

This runbook prepares and deploys the `dev` environment in phases so dependencies are satisfied before the `edge` stack.

## 1. Prerequisites

1. AWS access with permissions for VPC, EKS, RDS, ElastiCache, API Gateway, Lambda, EventBridge, CloudFront, WAF, Route53, IAM.
2. Tools installed: `terraform`, `aws`, `kubectl`, `helm`, `jq`, `envsubst`.
3. Remote state backend already created:
  - S3 bucket for Terraform state
  - DynamoDB table for state locking
4. Domain and certificates:
  - ACM cert in `us-east-1` for CloudFront (`us_east_1_acm_certificate_arn`)
  - ACM cert in each workload region for web ALB (`WEB_ALB_CERT_ARN`)
5. Controllers installed in both EKS clusters:
  - AWS Load Balancer Controller
  - Karpenter
  - Secrets Store CSI Driver + AWS provider (`provider-aws`)
6. Security rule: no credentials in environment variables or config files; applications consume credentials from AWS Secrets Manager mounts.

## 2. Preflight

```bash
cd <repo-root>
./scripts/preflight.sh
```

## 3. Configure dev tfvars

Edit:
- `terraform/environments/dev/network.tfvars`
- `terraform/environments/dev/platform-eks.tfvars`
- `terraform/environments/dev/data.tfvars`
- `terraform/environments/dev/edge.tfvars`
- `terraform/environments/dev/observability.tfvars`

At minimum, replace all placeholder values:
- account IDs
- ARNs
- Route53 hosted zone ID
- domain names
- certificate ARNs

## 4. Phase A: Terraform foundation (network + EKS + data)

Set backend variables:

```bash
export TF_STATE_BUCKET="example-hotel-tfstate"
export TF_LOCK_TABLE="terraform-state-lock"
export TF_STATE_REGION="ap-southeast-1"
```

Run plan first:

```bash
./scripts/deploy_terraform.sh --env dev --action plan --stacks network,platform-eks,data
```

Apply foundation:

```bash
./scripts/deploy_terraform.sh --env dev --action apply --stacks network,platform-eks,data
```

## 5. Connect to both clusters

Read cluster names from Terraform output:

```bash
PRIMARY_CLUSTER=$(terraform -chdir=terraform/stacks/platform-eks output -json | jq -r '.primary.value.cluster_name')
SECONDARY_CLUSTER=$(terraform -chdir=terraform/stacks/platform-eks output -json | jq -r '.secondary.value.cluster_name')
```

Update kubeconfig contexts:

```bash
aws eks update-kubeconfig --region ap-southeast-1 --name "$PRIMARY_CLUSTER" --alias "$PRIMARY_CLUSTER"
aws eks update-kubeconfig --region ap-southeast-2 --name "$SECONDARY_CLUSTER" --alias "$SECONDARY_CLUSTER"
```

Install Secrets Store CSI Driver + AWS provider (run for each cluster context):

```bash
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm repo add aws-secrets-manager https://aws.github.io/secrets-store-csi-driver-provider-aws
helm repo update

kubectl config use-context "$PRIMARY_CLUSTER"
helm upgrade --install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
  --namespace kube-system
helm upgrade --install secrets-provider-aws aws-secrets-manager/secrets-store-csi-driver-provider-aws \
  --namespace kube-system

kubectl config use-context "$SECONDARY_CLUSTER"
helm upgrade --install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
  --namespace kube-system
helm upgrade --install secrets-provider-aws aws-secrets-manager/secrets-store-csi-driver-provider-aws \
  --namespace kube-system
```

## 6. Render and apply Kubernetes manifests (each region)

Set render variables for each region before applying:

```bash
export AWS_ACCOUNT_ID="<account_id>"
export AWS_REGION="ap-southeast-1"
export APP_ENV="dev"
export WORKLOAD_IRSA_ROLE_ARN="<platform_eks_workload_irsa_role_arn>"
export KARPENTER_DISCOVERY_TAG="hotel-dev"
export KARPENTER_INSTANCE_PROFILE="hotel-dev-karpenter-node-profile"
export VPC_CIDR="10.0.0.0/16"
export PRIMARY_AZ_1="ap-southeast-1a"
export PRIMARY_AZ_2="ap-southeast-1b"
export PRIMARY_AZ_3="ap-southeast-1c"
export WEB_ALB_CERT_ARN="<acm_cert_arn_in_ap_southeast_1>"
export DB_SECRET_ARN="$(terraform -chdir=terraform/stacks/data output -raw primary_db_secret_arn)"
export REDIS_SECRET_ARN="$(terraform -chdir=terraform/stacks/data output -raw primary_redis_secret_arn)"
```

Render manifests:

```bash
./scripts/render_k8s_manifests.sh
```

Apply to primary:

```bash
kubectl --context "$PRIMARY_CLUSTER" create namespace hotel --dry-run=client -o yaml | kubectl apply -f -
kubectl --context "$PRIMARY_CLUSTER" apply -f kubernetes/rendered/priorities.yaml
kubectl --context "$PRIMARY_CLUSTER" apply -f kubernetes/rendered/karpenter-nodepool.yaml
kubectl --context "$PRIMARY_CLUSTER" apply -f kubernetes/rendered/secret-provider-class.yaml
kubectl --context "$PRIMARY_CLUSTER" apply -f kubernetes/rendered/deployment.yaml
kubectl --context "$PRIMARY_CLUSTER" apply -f kubernetes/rendered/service.yaml
kubectl --context "$PRIMARY_CLUSTER" apply -f kubernetes/rendered/workloads/eks-services.yaml
kubectl --context "$PRIMARY_CLUSTER" apply -f kubernetes/rendered/web-frontend-ingress.yaml
```

Repeat for secondary with region-specific values (`AWS_REGION`, `PRIMARY_AZ_*`, `WEB_ALB_CERT_ARN`) and secrets:
- `DB_SECRET_ARN="$(terraform -chdir=terraform/stacks/data output -raw secondary_db_secret_arn)"`
- `REDIS_SECRET_ARN="$(terraform -chdir=terraform/stacks/data output -raw secondary_redis_secret_arn)"`
Re-run `./scripts/render_k8s_manifests.sh` with the secondary values, then apply to `"$SECONDARY_CLUSTER"`:

```bash
kubectl --context "$SECONDARY_CLUSTER" create namespace hotel --dry-run=client -o yaml | kubectl apply -f -
kubectl --context "$SECONDARY_CLUSTER" apply -f kubernetes/rendered/priorities.yaml
kubectl --context "$SECONDARY_CLUSTER" apply -f kubernetes/rendered/karpenter-nodepool.yaml
kubectl --context "$SECONDARY_CLUSTER" apply -f kubernetes/rendered/secret-provider-class.yaml
kubectl --context "$SECONDARY_CLUSTER" apply -f kubernetes/rendered/deployment.yaml
kubectl --context "$SECONDARY_CLUSTER" apply -f kubernetes/rendered/service.yaml
kubectl --context "$SECONDARY_CLUSTER" apply -f kubernetes/rendered/workloads/eks-services.yaml
kubectl --context "$SECONDARY_CLUSTER" apply -f kubernetes/rendered/web-frontend-ingress.yaml
```

## 7. Collect edge stack inputs from live infrastructure

```bash
./scripts/collect_edge_inputs.sh \
  --env dev \
  --primary-cluster "$PRIMARY_CLUSTER" \
  --secondary-cluster "$SECONDARY_CLUSTER"
```

Copy script output into:
- `terraform/environments/dev/edge.tfvars`

Optional: set Lambda consumer ARNs in `edge.tfvars` when integration consumers are ready:
- `notifications_lambda_arn`
- `audit_lambda_arn`
- `notifications_lambda_arn_secondary`
- `audit_lambda_arn_secondary`

## 8. Phase B: Edge and Observability

Plan:

```bash
./scripts/deploy_terraform.sh --env dev --action plan --stacks edge,observability
```

Apply:

```bash
./scripts/deploy_terraform.sh --env dev --action apply --stacks edge,observability
```

## 9. Smoke validation

1. Confirm pods and services in both clusters:
```bash
kubectl --context "$PRIMARY_CLUSTER" -n hotel get pods,svc,ingress
kubectl --context "$SECONDARY_CLUSTER" -n hotel get pods,svc,ingress
```

2. Confirm CloudFront and API endpoints:
```bash
terraform -chdir=terraform/stacks/edge output cloudfront_domain_name
terraform -chdir=terraform/stacks/edge output primary_api_endpoint
terraform -chdir=terraform/stacks/edge output secondary_api_endpoint
```

3. Validate async path (`/api/events/commands`) and confirm messages flow SQS -> Lambda worker -> EventBridge.

## 10. Recommended next step after dev

Promote same process to `uat`, then `prod` with account isolation and approval gates.
