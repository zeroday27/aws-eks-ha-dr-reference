# =============================================================================
# ElastiCache Module - Redis Cluster for Point Balance Caching
# =============================================================================

# -----------------------------------------------------------------------------
# ElastiCache Subnet Group
# -----------------------------------------------------------------------------
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-redis-subnet"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-redis-subnet"
  }
}

# -----------------------------------------------------------------------------
# ElastiCache Parameter Group
# -----------------------------------------------------------------------------
resource "aws_elasticache_parameter_group" "main" {
  name   = "${var.project_name}-${var.environment}-redis-params"
  family = "redis7"

  # Optimized for caching user point balances
  parameter {
    name  = "maxmemory-policy"
    value = "volatile-lru"
  }

  parameter {
    name  = "timeout"
    value = "300"
  }

  # Enable cluster mode for horizontal scaling
  parameter {
    name  = "cluster-enabled"
    value = "yes"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-redis-params"
  }
}

# -----------------------------------------------------------------------------
# ElastiCache Replication Group (Multi-AZ Redis Cluster)
# -----------------------------------------------------------------------------
resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${var.project_name}-${var.environment}-redis"
  description          = "Redis cluster for ${var.project_name} point balance caching"

  # Engine Configuration
  engine         = "redis"
  engine_version = var.engine_version
  node_type      = var.node_type
  port           = 6379

  # Cluster Configuration - Multi-AZ for High Availability
  num_node_groups         = var.num_cache_clusters
  replicas_per_node_group = 1

  # High Availability
  automatic_failover_enabled = true
  multi_az_enabled           = true

  # Network
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [var.security_group_id]

  # Security
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  kms_key_id                 = var.kms_key_id
  auth_token                 = random_password.redis_auth.result

  # Parameter Group
  parameter_group_name = aws_elasticache_parameter_group.main.name

  # Maintenance
  maintenance_window       = "sun:05:00-sun:06:00"
  snapshot_window          = "04:00-05:00"
  snapshot_retention_limit = 7

  # Auto Minor Version Upgrade
  auto_minor_version_upgrade = true

  # Notifications
  notification_topic_arn = aws_sns_topic.redis_notifications.arn

  tags = {
    Name = "${var.project_name}-${var.environment}-redis"
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow_log.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_engine_log.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }
}

# -----------------------------------------------------------------------------
# Redis Auth Token
# -----------------------------------------------------------------------------
resource "random_password" "redis_auth" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# -----------------------------------------------------------------------------
# Store Redis Credentials in Secrets Manager
# -----------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "redis_credentials" {
  name        = "${var.project_name}/${var.environment}/redis/credentials"
  description = "Redis credentials for ${var.project_name}"
  kms_key_id  = var.kms_key_id

  tags = {
    Name = "${var.project_name}-${var.environment}-redis-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "redis_credentials" {
  secret_id = aws_secretsmanager_secret.redis_credentials.id
  secret_string = jsonencode({
    auth_token             = random_password.redis_auth.result
    primary_endpoint       = aws_elasticache_replication_group.main.primary_endpoint_address
    configuration_endpoint = aws_elasticache_replication_group.main.configuration_endpoint_address
    port                   = 6379
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Log Groups for Redis
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "redis_slow_log" {
  name              = "/aws/elasticache/${var.project_name}-${var.environment}/slow-log"
  retention_in_days = 14

  tags = {
    Name = "${var.project_name}-${var.environment}-redis-slow-log"
  }
}

resource "aws_cloudwatch_log_group" "redis_engine_log" {
  name              = "/aws/elasticache/${var.project_name}-${var.environment}/engine-log"
  retention_in_days = 14

  tags = {
    Name = "${var.project_name}-${var.environment}-redis-engine-log"
  }
}

# -----------------------------------------------------------------------------
# SNS Topic for Redis Notifications
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "redis_notifications" {
  name = "${var.project_name}-${var.environment}-redis-notifications"

  tags = {
    Name = "${var.project_name}-${var.environment}-redis-notifications"
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms for Redis Monitoring
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "redis_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-redis-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 75
  alarm_description   = "Redis CPU utilization is high"
  alarm_actions       = [aws_sns_topic.redis_notifications.arn]

  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.main.id
  }
}

resource "aws_cloudwatch_metric_alarm" "redis_memory" {
  alarm_name          = "${var.project_name}-${var.environment}-redis-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Redis memory usage is high"
  alarm_actions       = [aws_sns_topic.redis_notifications.arn]

  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.main.id
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "redis_configuration_endpoint" {
  description = "Redis configuration endpoint (for cluster mode)"
  value       = aws_elasticache_replication_group.main.configuration_endpoint_address
}

output "redis_port" {
  description = "Redis port"
  value       = 6379
}

output "redis_secret_arn" {
  description = "Redis credentials secret ARN"
  value       = aws_secretsmanager_secret.redis_credentials.arn
}
