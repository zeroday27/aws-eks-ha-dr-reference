variable "project_name" { type = string }
variable "environment" { type = string }
variable "cluster_version" {
  type    = string
  default = "1.34"
}
variable "vpc_id" { type = string }
variable "vpc_cidr" { type = string }
variable "app_subnet_ids" { type = list(string) }
variable "cluster_endpoint_public_access" {
  type    = bool
  default = false
}
variable "cluster_endpoint_public_access_cidrs" {
  type    = list(string)
  default = []
}
variable "system_node_instance_types" {
  type    = list(string)
  default = ["m6i.large"]
}
variable "system_node_desired_size" {
  type    = number
  default = 2
}
variable "system_node_min_size" {
  type    = number
  default = 2
}
variable "system_node_max_size" {
  type    = number
  default = 6
}
variable "workload_service_accounts" {
  description = "Fully-qualified Kubernetes service account subjects allowed to assume the workload IRSA role"
  type        = list(string)
  default     = ["system:serviceaccount:hotel:hotel-app"]
}
