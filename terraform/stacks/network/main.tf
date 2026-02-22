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
      Stack       = "network"
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
      Stack       = "network"
      ManagedBy   = "terraform"
    }
  }
}

data "aws_availability_zones" "primary" {
  state = "available"
}

data "aws_availability_zones" "secondary" {
  provider = aws.secondary
  state    = "available"
}

module "primary_vpc" {
  source = "../../modules/vpc-regional"

  project_name             = var.project_name
  environment              = var.environment
  region                   = var.primary_region
  vpc_cidr                 = var.primary_vpc_cidr
  availability_zones       = slice(data.aws_availability_zones.primary.names, 0, 3)
  public_subnet_cidrs      = var.primary_public_subnet_cidrs
  app_subnet_cidrs         = var.primary_app_subnet_cidrs
  data_subnet_cidrs        = var.primary_data_subnet_cidrs
  integration_subnet_cidrs = var.primary_integration_subnet_cidrs
  enable_vpc_endpoints     = true
}

module "secondary_vpc" {
  source = "../../modules/vpc-regional"

  providers = {
    aws = aws.secondary
  }

  project_name             = var.project_name
  environment              = var.environment
  region                   = var.secondary_region
  vpc_cidr                 = var.secondary_vpc_cidr
  availability_zones       = slice(data.aws_availability_zones.secondary.names, 0, 3)
  public_subnet_cidrs      = var.secondary_public_subnet_cidrs
  app_subnet_cidrs         = var.secondary_app_subnet_cidrs
  data_subnet_cidrs        = var.secondary_data_subnet_cidrs
  integration_subnet_cidrs = var.secondary_integration_subnet_cidrs
  enable_vpc_endpoints     = true
}
