terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.5"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.primary_region
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = var.network_state_bucket
    key    = var.network_state_key
    region = var.state_region
  }
}

locals {
  cloudfront_aliases = distinct(compact([var.api_domain_name, var.web_domain_name]))
}

resource "aws_security_group" "apigw_vpc_link_primary" {
  name   = "${var.project_name}-${var.environment}-apigw-vpclink"
  vpc_id = data.terraform_remote_state.network.outputs.primary.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "apigw_vpc_link_secondary" {
  provider = aws.secondary
  name     = "${var.project_name}-${var.environment}-dr-apigw-vpclink"
  vpc_id   = data.terraform_remote_state.network.outputs.secondary.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_sqs_queue" "event_ingest_dlq_primary" {
  name                      = "${var.project_name}-${var.environment}-event-ingest-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "event_ingest_primary" {
  name                       = "${var.project_name}-${var.environment}-event-ingest"
  visibility_timeout_seconds = 120
  message_retention_seconds  = 345600
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.event_ingest_dlq_primary.arn
    maxReceiveCount     = 5
  })
}

resource "aws_sqs_queue" "event_ingest_dlq_secondary" {
  provider                  = aws.secondary
  name                      = "${var.project_name}-${var.environment}-dr-event-ingest-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "event_ingest_secondary" {
  provider                   = aws.secondary
  name                       = "${var.project_name}-${var.environment}-dr-event-ingest"
  visibility_timeout_seconds = 120
  message_retention_seconds  = 345600
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.event_ingest_dlq_secondary.arn
    maxReceiveCount     = 5
  })
}

resource "aws_iam_role" "lambda_event_ingest" {
  name = "${var.project_name}-${var.environment}-event-ingest-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_ingest_basic" {
  role       = aws_iam_role.lambda_event_ingest.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_ingest_sqs" {
  role = aws_iam_role.lambda_event_ingest.id
  name = "${var.project_name}-${var.environment}-event-ingest-sqs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["sqs:SendMessage"]
        Resource = [
          aws_sqs_queue.event_ingest_primary.arn,
          aws_sqs_queue.event_ingest_secondary.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role" "lambda_event_worker" {
  name = "${var.project_name}-${var.environment}-event-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_worker_basic" {
  role       = aws_iam_role.lambda_event_worker.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_worker_runtime" {
  role = aws_iam_role.lambda_event_worker.id
  name = "${var.project_name}-${var.environment}-event-worker-runtime"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = [
          aws_sqs_queue.event_ingest_primary.arn,
          aws_sqs_queue.event_ingest_secondary.arn
        ]
      },
      {
        Effect = "Allow"
        Action = ["events:PutEvents"]
        Resource = [
          module.eventbridge_primary.bus_arn,
          module.eventbridge_secondary.bus_arn
        ]
      }
    ]
  })
}

data "archive_file" "event_ingest_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/event_ingest.py"
  output_path = "${path.module}/lambda/event_ingest.zip"
}

data "archive_file" "event_worker_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/event_worker.py"
  output_path = "${path.module}/lambda/event_worker.zip"
}

module "eventbridge_primary" {
  source = "../../modules/eventbridge"

  project_name = var.project_name
  environment  = var.environment
  region       = var.primary_region

  lambda_consumers = {
    notifications = {
      arn           = var.notifications_lambda_arn
      event_pattern = jsonencode({ "source" : ["hotel.api"], "detail-type" : ["NotifyGuest"] })
    }
    audit = {
      arn           = var.audit_lambda_arn
      event_pattern = jsonencode({ "source" : ["hotel.api"] })
    }
  }
}

module "eventbridge_secondary" {
  source = "../../modules/eventbridge"

  providers = {
    aws = aws.secondary
  }

  project_name = var.project_name
  environment  = "${var.environment}-dr"
  region       = var.secondary_region

  lambda_consumers = {
    notifications = {
      arn           = var.notifications_lambda_arn_secondary
      event_pattern = jsonencode({ "source" : ["hotel.api"], "detail-type" : ["NotifyGuest"] })
    }
    audit = {
      arn           = var.audit_lambda_arn_secondary
      event_pattern = jsonencode({ "source" : ["hotel.api"] })
    }
  }
}

resource "aws_lambda_function" "event_ingest_primary" {
  function_name = "${var.project_name}-${var.environment}-event-ingest"
  role          = aws_iam_role.lambda_event_ingest.arn
  handler       = "event_ingest.handler"
  runtime       = "python3.12"
  filename      = data.archive_file.event_ingest_zip.output_path
  timeout       = 10

  source_code_hash = data.archive_file.event_ingest_zip.output_base64sha256

  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.event_ingest_primary.id
    }
  }

  depends_on = [aws_iam_role_policy.lambda_ingest_sqs]
}

resource "aws_lambda_function" "event_ingest_secondary" {
  provider      = aws.secondary
  function_name = "${var.project_name}-${var.environment}-dr-event-ingest"
  role          = aws_iam_role.lambda_event_ingest.arn
  handler       = "event_ingest.handler"
  runtime       = "python3.12"
  filename      = data.archive_file.event_ingest_zip.output_path
  timeout       = 10

  source_code_hash = data.archive_file.event_ingest_zip.output_base64sha256

  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.event_ingest_secondary.id
    }
  }

  depends_on = [aws_iam_role_policy.lambda_ingest_sqs]
}

resource "aws_lambda_function" "event_worker_primary" {
  function_name = "${var.project_name}-${var.environment}-event-worker"
  role          = aws_iam_role.lambda_event_worker.arn
  handler       = "event_worker.handler"
  runtime       = "python3.12"
  filename      = data.archive_file.event_worker_zip.output_path
  timeout       = 30

  source_code_hash = data.archive_file.event_worker_zip.output_base64sha256

  environment {
    variables = {
      EVENT_BUS_NAME = module.eventbridge_primary.bus_name
    }
  }

  depends_on = [aws_iam_role_policy.lambda_worker_runtime]
}

resource "aws_lambda_function" "event_worker_secondary" {
  provider      = aws.secondary
  function_name = "${var.project_name}-${var.environment}-dr-event-worker"
  role          = aws_iam_role.lambda_event_worker.arn
  handler       = "event_worker.handler"
  runtime       = "python3.12"
  filename      = data.archive_file.event_worker_zip.output_path
  timeout       = 30

  source_code_hash = data.archive_file.event_worker_zip.output_base64sha256

  environment {
    variables = {
      EVENT_BUS_NAME = module.eventbridge_secondary.bus_name
    }
  }

  depends_on = [aws_iam_role_policy.lambda_worker_runtime]
}

resource "aws_lambda_event_source_mapping" "event_worker_primary" {
  event_source_arn                   = aws_sqs_queue.event_ingest_primary.arn
  function_name                      = aws_lambda_function.event_worker_primary.arn
  batch_size                         = 10
  maximum_batching_window_in_seconds = 5
  function_response_types            = ["ReportBatchItemFailures"]
  enabled                            = true
}

resource "aws_lambda_event_source_mapping" "event_worker_secondary" {
  provider                           = aws.secondary
  event_source_arn                   = aws_sqs_queue.event_ingest_secondary.arn
  function_name                      = aws_lambda_function.event_worker_secondary.arn
  batch_size                         = 10
  maximum_batching_window_in_seconds = 5
  function_response_types            = ["ReportBatchItemFailures"]
  enabled                            = true
}

module "api_primary" {
  source = "../../modules/apigateway"

  project_name                = var.project_name
  environment                 = var.environment
  region                      = var.primary_region
  integration_subnet_ids      = data.terraform_remote_state.network.outputs.primary.integration_subnet_ids
  vpc_link_security_group_ids = [aws_security_group.apigw_vpc_link_primary.id]
  eks_nlb_listener_arn        = var.primary_eks_nlb_listener_arn
  event_ingest_lambda_arn     = aws_lambda_function.event_ingest_primary.arn
}

module "api_secondary" {
  source = "../../modules/apigateway"

  providers = {
    aws = aws.secondary
  }

  project_name                = var.project_name
  environment                 = "${var.environment}-dr"
  region                      = var.secondary_region
  integration_subnet_ids      = data.terraform_remote_state.network.outputs.secondary.integration_subnet_ids
  vpc_link_security_group_ids = [aws_security_group.apigw_vpc_link_secondary.id]
  eks_nlb_listener_arn        = var.secondary_eks_nlb_listener_arn
  event_ingest_lambda_arn     = aws_lambda_function.event_ingest_secondary.arn
}

resource "aws_route53_health_check" "primary_api" {
  fqdn              = replace(module.api_primary.api_endpoint, "https://", "")
  port              = 443
  type              = "HTTPS"
  resource_path     = "/v1/health/ready"
  failure_threshold = 3
  request_interval  = 30
}

resource "aws_cloudwatch_event_endpoint" "global" {
  name = "${var.project_name}-${var.environment}-global-endpoint"

  event_bus {
    event_bus_arn = module.eventbridge_primary.bus_arn
  }

  event_bus {
    event_bus_arn = module.eventbridge_secondary.bus_arn
  }

  replication_config {
    state = "ENABLED"
  }

  routing_config {
    failover_config {
      primary {
        health_check = aws_route53_health_check.primary_api.arn
      }

      secondary {
        route = "SECONDARY"
      }
    }
  }
}

resource "aws_wafv2_web_acl" "cloudfront" {
  provider = aws.us_east_1
  name     = "${var.project_name}-${var.environment}-cloudfront-waf"
  scope    = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimit"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-cloudfront-waf"
    sampled_requests_enabled   = true
  }
}

resource "aws_cloudfront_distribution" "api" {
  enabled         = true
  is_ipv6_enabled = true
  aliases         = local.cloudfront_aliases

  # Frontend web origin (EKS web ALB in primary region)
  origin {
    domain_name = var.primary_web_alb_dns_name
    origin_id   = "primary-web"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Frontend web origin (EKS web ALB in secondary region)
  origin {
    domain_name = var.secondary_web_alb_dns_name
    origin_id   = "secondary-web"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin_group {
    origin_id = "regional-web-failover"

    failover_criteria {
      status_codes = [500, 502, 503, 504]
    }

    member {
      origin_id = "primary-web"
    }

    member {
      origin_id = "secondary-web"
    }
  }

  # Backend API origin (primary region API Gateway)
  origin {
    domain_name = replace(module.api_primary.api_endpoint, "https://", "")
    origin_id   = "primary-api"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    domain_name = replace(module.api_secondary.api_endpoint, "https://", "")
    origin_id   = "secondary-api"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # API failover group
  origin_group {
    origin_id = "regional-api-failover"

    failover_criteria {
      status_codes = [500, 502, 503, 504]
    }

    member {
      origin_id = "primary-api"
    }

    member {
      origin_id = "secondary-api"
    }
  }

  # Default web behavior: frontend pages and static assets from EKS web ALB
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "regional-web-failover"

    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["Accept", "Accept-Language", "CloudFront-Viewer-Country"]

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 60
    max_ttl     = 300
  }

  # API paths to API Gateway (recommended separation from web traffic)
  ordered_cache_behavior {
    path_pattern     = "/api/v1/balance/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "regional-api-failover"

    forwarded_values {
      query_string = true
      headers      = ["Authorization"]
      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 5
    max_ttl                = 30
    viewer_protocol_policy = "redirect-to-https"
  }

  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "regional-api-failover"

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Idempotency-Key", "X-Correlation-Id", "CloudFront-Viewer-Country"]

      cookies {
        forward = "all"
      }
    }

    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    viewer_protocol_policy = "redirect-to-https"
  }

  # Legacy API paths kept for backward compatibility
  ordered_cache_behavior {
    path_pattern     = "/v1/balance/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "regional-api-failover"

    forwarded_values {
      query_string = true
      headers      = ["Authorization"]
      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 5
    max_ttl                = 30
    viewer_protocol_policy = "redirect-to-https"
  }

  ordered_cache_behavior {
    path_pattern     = "/v1/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "regional-api-failover"

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Idempotency-Key", "X-Correlation-Id", "CloudFront-Viewer-Country"]

      cookies {
        forward = "all"
      }
    }

    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.us_east_1_acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  web_acl_id = aws_wafv2_web_acl.cloudfront.arn
}

resource "aws_route53_record" "api" {
  count = var.create_route53_record ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.api_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.api.domain_name
    zone_id                = aws_cloudfront_distribution.api.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "web" {
  count = var.create_web_route53_record && var.web_domain_name != "" && var.web_domain_name != var.api_domain_name ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.web_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.api.domain_name
    zone_id                = aws_cloudfront_distribution.api.hosted_zone_id
    evaluate_target_health = false
  }
}
