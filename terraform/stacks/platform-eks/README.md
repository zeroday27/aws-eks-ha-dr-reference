# Platform EKS Stack

Creates primary and DR EKS clusters (EKS-only container platform) with:
- Managed system node groups
- Karpenter IAM and interruption queue
- OIDC provider + workload IRSA role
- Private control-plane endpoint by default
