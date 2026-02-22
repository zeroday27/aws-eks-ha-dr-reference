variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "lambda_consumers" {
  description = "Map of EventBridge consumers keyed by service name"
  type = map(object({
    arn           = string
    event_pattern = string
  }))
  default = {}
}

variable "archive_retention_days" {
  type    = number
  default = 7
}

variable "create_global_endpoint" {
  description = "Create EventBridge global endpoint in primary region"
  type        = bool
  default     = false
}

variable "secondary_event_bus_arn" {
  description = "Secondary region bus ARN (required when create_global_endpoint=true)"
  type        = string
  default     = ""
}

variable "route53_health_check_arn" {
  description = "Route53 health check ARN used for EventBridge failover"
  type        = string
  default     = ""
}
