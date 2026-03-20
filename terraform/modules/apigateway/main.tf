terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_cloudwatch_log_group" "api_access" {
  count = var.enable_access_logs ? 1 : 0

  name              = "/aws/apigateway/${var.project_name}-${var.environment}-${var.region}"
  retention_in_days = var.log_retention_days
}

resource "aws_apigatewayv2_api" "this" {
  name          = "${var.project_name}-${var.environment}-${var.region}-http-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_credentials = false
    allow_headers     = ["Authorization", "Content-Type", "Idempotency-Key", "X-Correlation-Id"]
    allow_methods     = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_origins     = var.cors_allow_origins
    expose_headers    = ["X-Served-Region", "X-Correlation-Id"]
    max_age           = 300
  }
}

resource "aws_apigatewayv2_vpc_link" "this" {
  name               = "${var.project_name}-${var.environment}-${var.region}-vpc-link"
  subnet_ids         = var.integration_subnet_ids
  security_group_ids = var.vpc_link_security_group_ids
}

resource "aws_apigatewayv2_integration" "sync_eks" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.this.id
  integration_uri        = var.eks_nlb_listener_arn
  payload_format_version = "1.0"
  timeout_milliseconds   = 29000
}

resource "aws_apigatewayv2_route" "sync_eks" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "ANY /v1/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.sync_eks.id}"
}

resource "aws_apigatewayv2_route" "sync_eks_api_prefix" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "ANY /api/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.sync_eks.id}"
}

resource "aws_apigatewayv2_integration" "async_ingest" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.event_ingest_lambda_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 29000
}

resource "aws_apigatewayv2_route" "async_commands" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /v1/events/commands"
  target    = "integrations/${aws_apigatewayv2_integration.async_ingest.id}"
}

resource "aws_apigatewayv2_route" "async_commands_api_prefix" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /api/events/commands"
  target    = "integrations/${aws_apigatewayv2_integration.async_ingest.id}"
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.event_ingest_lambda_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  dynamic "access_log_settings" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      destination_arn = aws_cloudwatch_log_group.api_access[0].arn
      format = jsonencode({
        requestId      = "$context.requestId"
        ip             = "$context.identity.sourceIp"
        requestTime    = "$context.requestTime"
        routeKey       = "$context.routeKey"
        status         = "$context.status"
        responseLength = "$context.responseLength"
      })
    }
  }

  default_route_settings {
    throttling_burst_limit = 2000
    throttling_rate_limit  = 1000
  }
}
