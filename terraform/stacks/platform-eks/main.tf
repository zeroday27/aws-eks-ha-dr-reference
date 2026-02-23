terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.primary_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Stack       = "platform-eks"
      ManagedBy   = "terraform"
    }
  }
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Stack       = "platform-eks"
      ManagedBy   = "terraform"
    }
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = var.network_state_bucket
    key    = var.network_state_key
    region = var.state_region
  }
}

module "primary_eks" {
  source = "../../modules/eks-platform"

  project_name             = var.project_name
  environment              = var.environment
  cluster_version          = var.cluster_version
  vpc_id                   = data.terraform_remote_state.network.outputs.primary.vpc_id
  vpc_cidr                 = data.terraform_remote_state.network.outputs.primary.vpc_cidr
  app_subnet_ids           = data.terraform_remote_state.network.outputs.primary.app_subnet_ids
  system_node_desired_size = 3
  system_node_min_size     = 3
  system_node_max_size     = 9
}

module "secondary_eks" {
  source = "../../modules/eks-platform"

  providers = {
    aws = aws.secondary
  }

  project_name             = var.project_name
  environment              = "${var.environment}-dr"
  cluster_version          = var.cluster_version
  vpc_id                   = data.terraform_remote_state.network.outputs.secondary.vpc_id
  vpc_cidr                 = data.terraform_remote_state.network.outputs.secondary.vpc_cidr
  app_subnet_ids           = data.terraform_remote_state.network.outputs.secondary.app_subnet_ids
  system_node_desired_size = 2
  system_node_min_size     = 2
  system_node_max_size     = 6
}
