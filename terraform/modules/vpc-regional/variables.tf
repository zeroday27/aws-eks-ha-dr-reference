variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region label for tags"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR for the regional VPC"
  type        = string
}

variable "availability_zones" {
  description = "Exactly 3 availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets"
  type        = list(string)
}

variable "app_subnet_cidrs" {
  description = "CIDRs for private app subnets (EKS workloads)"
  type        = list(string)
}

variable "data_subnet_cidrs" {
  description = "CIDRs for private data subnets (RDS/Redis)"
  type        = list(string)
}

variable "integration_subnet_cidrs" {
  description = "CIDRs for private integration subnets (Lambda/VPC endpoints)"
  type        = list(string)
}

variable "enable_vpc_endpoints" {
  description = "Create interface endpoints for core AWS services"
  type        = bool
  default     = true
}
