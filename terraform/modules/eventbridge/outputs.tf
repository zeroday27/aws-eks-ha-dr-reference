output "bus_name" {
  value = aws_cloudwatch_event_bus.this.name
}

output "bus_arn" {
  value = aws_cloudwatch_event_bus.this.arn
}

output "dlq_arn" {
  value = aws_sqs_queue.dlq.arn
}

output "global_endpoint_arn" {
  value = var.create_global_endpoint ? aws_cloudwatch_event_endpoint.global[0].arn : null
}
