package terraform.security

deny[msg] {
  resource := input[_]
  resource_type := resource.type
  resource_type == "aws_security_group"
  ingress := resource.change.after.ingress[_]
  ingress.cidr_blocks[_] == "0.0.0.0/0"
  ingress.from_port != 80
  ingress.from_port != 443
  msg := sprintf("Security group %s allows unrestricted ingress on port %v", [resource.address, ingress.from_port])
}

deny[msg] {
  resource := input[_]
  resource.type == "aws_eks_cluster"
  resource.change.after.vpc_config[0].endpoint_public_access == true
  msg := sprintf("EKS cluster %s has public endpoint access enabled", [resource.address])
}
