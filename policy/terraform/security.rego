package terraform.security

import rego.v1

deny contains msg if {
  resource := input.resource_changes[_]
  resource.type == "aws_security_group"
  ingress := object.get(resource.change.after, "ingress", [])[_]
  ingress.cidr_blocks[_] == "0.0.0.0/0"
  not allowed_public_port(ingress.from_port)
  msg := sprintf("Security group %s allows unrestricted ingress on port %v", [resource.address, ingress.from_port])
}

deny contains msg if {
  resource := input.resource_changes[_]
  resource.type == "aws_eks_cluster"
  resource.change.after.vpc_config[0].endpoint_public_access == true
  msg := sprintf("EKS cluster %s has public endpoint access enabled", [resource.address])
}

deny contains msg if {
  security_group := input.resource.aws_security_group[name]
  ingress := object.get(security_group, "ingress", [])[_]
  ingress.cidr_blocks[_] == "0.0.0.0/0"
  not allowed_public_port(ingress.from_port)
  msg := sprintf("Security group aws_security_group.%s allows unrestricted ingress on port %v", [name, ingress.from_port])
}

deny contains msg if {
  cluster := input.resource.aws_eks_cluster[name]
  vpc_config := object.get(cluster, "vpc_config", [])[_]
  vpc_config.endpoint_public_access == true
  msg := sprintf("EKS cluster aws_eks_cluster.%s has public endpoint access enabled", [name])
}

allowed_public_port(port) if {
  port == 80
}

allowed_public_port(port) if {
  port == 443
}
