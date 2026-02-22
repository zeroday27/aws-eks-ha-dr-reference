output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "alerts_topic_arn_secondary" {
  value = aws_sns_topic.alerts_secondary.arn
}
