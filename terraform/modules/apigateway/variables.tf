variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "integration_subnet_ids" {
  description = "Private subnets used by API Gateway VPC link"
  type        = list(string)
}

variable "vpc_link_security_group_ids" {
  description = "Security groups for API Gateway VPC link"
  type        = list(string)
}

variable "eks_nlb_listener_arn" {
  description = "NLB listener ARN fronting EKS synchronous APIs"
  type        = string
}

variable "event_ingest_lambda_arn" {
  description = "Lambda ARN used for async command ingestion"
  type        = string
}

variable "enable_access_logs" {
  type    = bool
  default = true
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "cors_allow_origins" {
  description = "Allowed origins for CORS. Use specific domains in production."
  type        = list(string)
  default     = ["*"]
}
