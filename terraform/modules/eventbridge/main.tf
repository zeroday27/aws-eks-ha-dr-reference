terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_cloudwatch_event_bus" "this" {
  name = "${var.project_name}-${var.environment}-${var.region}-bus"
}

resource "aws_cloudwatch_event_archive" "this" {
  name             = "${var.project_name}-${var.environment}-${var.region}-archive"
  event_source_arn = aws_cloudwatch_event_bus.this.arn
  retention_days   = var.archive_retention_days
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_name}-${var.environment}-${var.region}-eventbridge-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_cloudwatch_event_bus_policy" "allow_account" {
  event_bus_name = aws_cloudwatch_event_bus.this.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowAccountPutEvents"
      Effect    = "Allow"
      Principal = { AWS = data.aws_caller_identity.current.account_id }
      Action    = "events:PutEvents"
      Resource  = aws_cloudwatch_event_bus.this.arn
    }]
  })
}

resource "aws_cloudwatch_event_rule" "consumer" {
  for_each = var.lambda_consumers

  name           = "${var.project_name}-${var.environment}-${var.region}-${each.key}"
  description    = "Routes events for ${each.key}"
  event_bus_name = aws_cloudwatch_event_bus.this.name
  event_pattern  = each.value.event_pattern
}

resource "aws_cloudwatch_event_target" "consumer" {
  for_each = var.lambda_consumers

  rule           = aws_cloudwatch_event_rule.consumer[each.key].name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  arn            = each.value.arn
  target_id      = each.key

  dead_letter_config {
    arn = aws_sqs_queue.dlq.arn
  }

  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts       = 10
  }
}

resource "aws_lambda_permission" "eventbridge" {
  for_each = var.lambda_consumers

  statement_id  = "AllowExecutionFromEventBridge-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.consumer[each.key].arn
}

resource "aws_cloudwatch_event_endpoint" "global" {
  count = var.create_global_endpoint ? 1 : 0

  name = "${var.project_name}-${var.environment}-global-endpoint"

  event_bus {
    event_bus_arn = aws_cloudwatch_event_bus.this.arn
  }

  event_bus {
    event_bus_arn = var.secondary_event_bus_arn
  }

  replication_config {
    state = "ENABLED"
  }

  routing_config {
    failover_config {
      primary {
        health_check = var.route53_health_check_arn
      }

      secondary {
        route = "SECONDARY"
      }
    }
  }
}

data "aws_caller_identity" "current" {}
