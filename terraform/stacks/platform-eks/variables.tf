variable "project_name" {
  type    = string
  default = "hotel"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "cluster_version" {
  type    = string
  default = "1.29"
}

variable "primary_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "secondary_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "network_state_bucket" {
  type = string
}

variable "network_state_key" {
  type = string
}

variable "state_region" {
  type    = string
  default = "ap-southeast-1"
}
