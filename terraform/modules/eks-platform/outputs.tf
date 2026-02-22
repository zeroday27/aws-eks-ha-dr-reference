output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_arn" {
  value = aws_eks_cluster.this.arn
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.this.arn
}

output "workload_irsa_role_arn" {
  value = aws_iam_role.workload_irsa.arn
}

output "karpenter_controller_role_arn" {
  value = aws_iam_role.karpenter_controller.arn
}

output "karpenter_instance_profile_name" {
  value = aws_iam_instance_profile.karpenter.name
}

output "worker_security_group_id" {
  value = aws_security_group.worker.id
}

output "cluster_security_group_id" {
  value = aws_security_group.cluster.id
}

output "karpenter_interruption_queue_name" {
  value = aws_sqs_queue.karpenter_interruptions.name
}
