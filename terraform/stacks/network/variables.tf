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

variable "primary_vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "secondary_vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "primary_public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "primary_app_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "primary_data_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
}

variable "primary_integration_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.31.0/24", "10.0.32.0/24", "10.0.33.0/24"]
}

variable "secondary_public_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
}

variable "secondary_app_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.11.0/24", "10.1.12.0/24", "10.1.13.0/24"]
}

variable "secondary_data_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.21.0/24", "10.1.22.0/24", "10.1.23.0/24"]
}

variable "secondary_integration_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.31.0/24", "10.1.32.0/24", "10.1.33.0/24"]
}
