terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
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
      Stack       = "data"
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
      Stack       = "data"
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

resource "aws_security_group" "rds_primary" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Allow PostgreSQL from app tier"
  vpc_id      = data.terraform_remote_state.network.outputs.primary.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.terraform_remote_state.network.outputs.primary.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.terraform_remote_state.network.outputs.primary.vpc_cidr]
  }
}

resource "aws_security_group" "rds_secondary" {
  provider    = aws.secondary
  name        = "${var.project_name}-${var.environment}-dr-rds-sg"
  description = "Allow PostgreSQL from app tier"
  vpc_id      = data.terraform_remote_state.network.outputs.secondary.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.terraform_remote_state.network.outputs.secondary.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.terraform_remote_state.network.outputs.secondary.vpc_cidr]
  }
}

resource "aws_security_group" "redis_primary" {
  name        = "${var.project_name}-${var.environment}-redis-sg"
  description = "Allow Redis from app tier"
  vpc_id      = data.terraform_remote_state.network.outputs.primary.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [data.terraform_remote_state.network.outputs.primary.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.terraform_remote_state.network.outputs.primary.vpc_cidr]
  }
}

resource "aws_security_group" "redis_secondary" {
  provider    = aws.secondary
  name        = "${var.project_name}-${var.environment}-dr-redis-sg"
  description = "Allow Redis from app tier"
  vpc_id      = data.terraform_remote_state.network.outputs.secondary.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [data.terraform_remote_state.network.outputs.secondary.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.terraform_remote_state.network.outputs.secondary.vpc_cidr]
  }
}

resource "aws_db_subnet_group" "primary" {
  name       = "${var.project_name}-${var.environment}-db-subnet"
  subnet_ids = data.terraform_remote_state.network.outputs.primary.data_subnet_ids
}

resource "aws_db_subnet_group" "secondary" {
  provider   = aws.secondary
  name       = "${var.project_name}-${var.environment}-dr-db-subnet"
  subnet_ids = data.terraform_remote_state.network.outputs.secondary.data_subnet_ids
}

resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_string" "db_username_suffix" {
  length  = 8
  upper   = false
  special = false
  numeric = true
}

locals {
  effective_db_username = var.database_username != "" ? var.database_username : "dbu${random_string.db_username_suffix.result}"
}

resource "aws_rds_global_cluster" "this" {
  global_cluster_identifier = "${var.project_name}-${var.environment}-global"
  engine                    = "aurora-postgresql"
  engine_version            = var.db_engine_version
  deletion_protection       = var.deletion_protection
}

resource "aws_rds_cluster" "primary" {
  cluster_identifier              = "${var.project_name}-${var.environment}-primary"
  engine                          = "aurora-postgresql"
  engine_version                  = var.db_engine_version
  global_cluster_identifier       = aws_rds_global_cluster.this.id
  db_subnet_group_name            = aws_db_subnet_group.primary.name
  database_name                   = var.database_name
  master_username                 = local.effective_db_username
  master_password                 = random_password.db.result
  vpc_security_group_ids          = [aws_security_group.rds_primary.id]
  storage_encrypted               = true
  deletion_protection             = var.deletion_protection
  backup_retention_period         = 7
  enabled_cloudwatch_logs_exports = ["postgresql"]
  skip_final_snapshot             = false
  final_snapshot_identifier       = "${var.project_name}-${var.environment}-primary-final"
}

resource "aws_rds_cluster_instance" "primary" {
  count = var.primary_instance_count

  identifier         = "${var.project_name}-${var.environment}-primary-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.primary.id
  instance_class     = var.db_instance_class
  engine             = aws_rds_cluster.primary.engine
  engine_version     = aws_rds_cluster.primary.engine_version
}

resource "aws_rds_cluster" "secondary" {
  provider                  = aws.secondary
  cluster_identifier        = "${var.project_name}-${var.environment}-secondary"
  engine                    = "aurora-postgresql"
  engine_version            = var.db_engine_version
  global_cluster_identifier = aws_rds_global_cluster.this.id
  db_subnet_group_name      = aws_db_subnet_group.secondary.name
  vpc_security_group_ids    = [aws_security_group.rds_secondary.id]
  storage_encrypted         = true
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-${var.environment}-secondary-final"
}

resource "aws_rds_cluster_instance" "secondary" {
  provider = aws.secondary
  count    = var.secondary_instance_count

  identifier         = "${var.project_name}-${var.environment}-secondary-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.secondary.id
  instance_class     = var.db_instance_class
  engine             = aws_rds_cluster.secondary.engine
  engine_version     = aws_rds_cluster.secondary.engine_version
}

resource "aws_secretsmanager_secret" "db_primary" {
  name = "${var.project_name}/${var.environment}/database/primary"
}

resource "aws_secretsmanager_secret_version" "db_primary" {
  secret_id = aws_secretsmanager_secret.db_primary.id
  secret_string = jsonencode({
    username    = local.effective_db_username
    password    = random_password.db.result
    host        = aws_rds_cluster.primary.endpoint
    reader_host = aws_rds_cluster.primary.reader_endpoint
    database    = var.database_name
    port        = 5432
  })
}

resource "aws_secretsmanager_secret" "db_secondary" {
  provider = aws.secondary
  name     = "${var.project_name}/${var.environment}/database/secondary"
}

resource "aws_secretsmanager_secret_version" "db_secondary" {
  provider  = aws.secondary
  secret_id = aws_secretsmanager_secret.db_secondary.id
  secret_string = jsonencode({
    username    = local.effective_db_username
    password    = random_password.db.result
    host        = aws_rds_cluster.secondary.endpoint
    reader_host = aws_rds_cluster.secondary.reader_endpoint
    database    = var.database_name
    port        = 5432
  })
}

module "redis_primary" {
  source = "../../modules/elasticache"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = data.terraform_remote_state.network.outputs.primary.vpc_id
  private_subnet_ids = data.terraform_remote_state.network.outputs.primary.data_subnet_ids
  node_type          = var.redis_node_type
  num_cache_clusters = var.redis_shards
  engine_version     = var.redis_engine_version
  security_group_id  = aws_security_group.redis_primary.id
  kms_key_id         = var.primary_kms_key_id
}

module "redis_secondary" {
  source = "../../modules/elasticache"

  providers = {
    aws = aws.secondary
  }

  project_name       = var.project_name
  environment        = "${var.environment}-dr"
  vpc_id             = data.terraform_remote_state.network.outputs.secondary.vpc_id
  private_subnet_ids = data.terraform_remote_state.network.outputs.secondary.data_subnet_ids
  node_type          = var.redis_node_type
  num_cache_clusters = var.redis_shards
  engine_version     = var.redis_engine_version
  security_group_id  = aws_security_group.redis_secondary.id
  kms_key_id         = var.secondary_kms_key_id
}
