variable "project_name" {
  type    = string
  default = "hotel"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "primary_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "secondary_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "network_state_bucket" { type = string }
variable "network_state_key" { type = string }
variable "state_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "primary_eks_nlb_listener_arn" {
  description = "NLB listener ARN for primary EKS synchronous API ingress"
  type        = string
}

variable "secondary_eks_nlb_listener_arn" {
  description = "NLB listener ARN for secondary EKS synchronous API ingress"
  type        = string
}

variable "primary_web_alb_dns_name" {
  description = "Primary region ALB DNS for frontend web traffic from CloudFront"
  type        = string
}

variable "secondary_web_alb_dns_name" {
  description = "Secondary region ALB DNS for frontend web traffic from CloudFront"
  type        = string
}

variable "api_domain_name" {
  type    = string
  default = "api.hotel.example.com"
}

variable "web_domain_name" {
  type    = string
  default = ""
}

variable "us_east_1_acm_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for CloudFront"
  type        = string
}

variable "route53_zone_id" {
  type    = string
  default = ""
}

variable "create_route53_record" {
  description = "Create Route53 A record for api_domain_name"
  type        = bool
  default     = false
}

variable "create_web_route53_record" {
  description = "Create Route53 A record for web_domain_name"
  type        = bool
  default     = false
}

variable "notifications_lambda_arn" {
  type = string
}

variable "audit_lambda_arn" {
  type = string
}

variable "notifications_lambda_arn_secondary" {
  type = string
}

variable "audit_lambda_arn_secondary" {
  type = string
}
