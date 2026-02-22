output "primary" {
  value = {
    cluster_name                      = module.primary_eks.cluster_name
    cluster_endpoint                  = module.primary_eks.cluster_endpoint
    cluster_arn                       = module.primary_eks.cluster_arn
    workload_irsa_role_arn            = module.primary_eks.workload_irsa_role_arn
    karpenter_controller_role_arn     = module.primary_eks.karpenter_controller_role_arn
    karpenter_instance_profile_name   = module.primary_eks.karpenter_instance_profile_name
    worker_security_group_id          = module.primary_eks.worker_security_group_id
    cluster_security_group_id         = module.primary_eks.cluster_security_group_id
    karpenter_interruption_queue_name = module.primary_eks.karpenter_interruption_queue_name
  }
}

output "secondary" {
  value = {
    cluster_name                      = module.secondary_eks.cluster_name
    cluster_endpoint                  = module.secondary_eks.cluster_endpoint
    cluster_arn                       = module.secondary_eks.cluster_arn
    workload_irsa_role_arn            = module.secondary_eks.workload_irsa_role_arn
    karpenter_controller_role_arn     = module.secondary_eks.karpenter_controller_role_arn
    karpenter_instance_profile_name   = module.secondary_eks.karpenter_instance_profile_name
    worker_security_group_id          = module.secondary_eks.worker_security_group_id
    cluster_security_group_id         = module.secondary_eks.cluster_security_group_id
    karpenter_interruption_queue_name = module.secondary_eks.karpenter_interruption_queue_name
  }
}
