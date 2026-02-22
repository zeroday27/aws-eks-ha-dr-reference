output "primary_api_endpoint" {
  value = module.api_primary.api_endpoint
}

output "secondary_api_endpoint" {
  value = module.api_secondary.api_endpoint
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.api.domain_name
}

output "web_domain_name" {
  value = var.web_domain_name
}

output "api_domain_name" {
  value = var.api_domain_name
}

output "eventbridge_primary_bus_arn" {
  value = module.eventbridge_primary.bus_arn
}

output "eventbridge_secondary_bus_arn" {
  value = module.eventbridge_secondary.bus_arn
}

output "eventbridge_global_endpoint_arn" {
  value = aws_cloudwatch_event_endpoint.global.arn
}

output "primary_api_id" {
  value = module.api_primary.api_id
}

output "secondary_api_id" {
  value = module.api_secondary.api_id
}

output "primary_event_queue_arn" {
  value = aws_sqs_queue.event_ingest_primary.arn
}

output "secondary_event_queue_arn" {
  value = aws_sqs_queue.event_ingest_secondary.arn
}
