output "aurora_global_cluster_id" {
  value = aws_rds_global_cluster.this.id
}

output "primary_db_endpoint" {
  value = aws_rds_cluster.primary.endpoint
}

output "secondary_db_endpoint" {
  value = aws_rds_cluster.secondary.endpoint
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db_primary.arn
}

output "primary_db_secret_arn" {
  value = aws_secretsmanager_secret.db_primary.arn
}

output "secondary_db_secret_arn" {
  value = aws_secretsmanager_secret.db_secondary.arn
}

output "primary_redis_endpoint" {
  value = module.redis_primary.redis_endpoint
}

output "secondary_redis_endpoint" {
  value = module.redis_secondary.redis_endpoint
}

output "primary_redis_secret_arn" {
  value = module.redis_primary.redis_secret_arn
}

output "secondary_redis_secret_arn" {
  value = module.redis_secondary.redis_secret_arn
}
