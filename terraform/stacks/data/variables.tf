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

variable "database_name" {
  type    = string
  default = "hotel_db"
}

variable "database_username" {
  type    = string
  default = ""
}

variable "db_engine_version" {
  type    = string
  default = "15.4"
}

variable "db_instance_class" {
  type    = string
  default = "db.r6g.large"
}

variable "primary_instance_count" {
  type    = number
  default = 2
}

variable "secondary_instance_count" {
  type    = number
  default = 1
}

variable "redis_node_type" {
  type    = string
  default = "cache.r6g.large"
}

variable "redis_engine_version" {
  type    = string
  default = "7.0"
}

variable "redis_shards" {
  type    = number
  default = 3
}

variable "primary_kms_key_id" {
  type    = string
  default = "alias/aws/elasticache"
}

variable "secondary_kms_key_id" {
  type    = string
  default = "alias/aws/elasticache"
}

variable "deletion_protection" {
  description = "Enable deletion protection on RDS clusters (set false for dev teardown)"
  type        = bool
  default     = true
}
