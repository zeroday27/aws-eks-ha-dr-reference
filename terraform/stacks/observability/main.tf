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
      Stack       = "observability"
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
      Stack       = "observability"
      ManagedBy   = "terraform"
    }
  }
}

data "terraform_remote_state" "edge" {
  backend = "s3"

  config = {
    bucket = var.edge_state_bucket
    key    = var.edge_state_key
    region = var.state_region
  }
}

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"
}

resource "aws_sns_topic" "alerts_secondary" {
  provider = aws.secondary
  name     = "${var.project_name}-${var.environment}-alerts-dr"
}

resource "aws_cloudwatch_metric_alarm" "api_5xx_primary" {
  alarm_name          = "${var.project_name}-${var.environment}-primary-apigw-5xx"
  namespace           = "AWS/ApiGateway"
  metric_name         = "5xx"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 10
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ApiId = data.terraform_remote_state.edge.outputs.primary_api_id
  }
}

resource "aws_cloudwatch_metric_alarm" "api_5xx_secondary" {
  provider            = aws.secondary
  alarm_name          = "${var.project_name}-${var.environment}-secondary-apigw-5xx"
  namespace           = "AWS/ApiGateway"
  metric_name         = "5xx"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 10
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts_secondary.arn]

  dimensions = {
    ApiId = data.terraform_remote_state.edge.outputs.secondary_api_id
  }
}
