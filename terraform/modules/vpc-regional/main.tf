terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-${var.region}-vpc"
    Environment = var.environment
    Region      = var.region
  }
}

# -----------------------------------------------------------------------------
# VPC Flow Logs — SEC-02
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  name              = "/aws/vpc/${var.project_name}-${var.environment}-${var.region}/flow-logs"
  retention_in_days = 30
}

resource "aws_iam_role" "vpc_flow_log" {
  name = "${var.project_name}-${var.environment}-${var.region}-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "vpc_flow_log" {
  role = aws_iam_role.vpc_flow_log.id
  name = "${var.project_name}-${var.environment}-${var.region}-flow-log-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.vpc_flow_log.arn}:*"
    }]
  })
}

resource "aws_flow_log" "this" {
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  iam_role_arn         = aws_iam_role.vpc_flow_log.arn
  log_destination      = aws_cloudwatch_log_group.vpc_flow_log.arn
  log_destination_type = "cloud-watch-logs"
  max_aggregation_interval = 60

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.region}-flow-log"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.region}-igw"
  }
}

resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.this.id
  availability_zone       = var.availability_zones[count.index]
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                                           = "${var.project_name}-${var.environment}-${var.region}-public-${count.index + 1}"
    "kubernetes.io/role/elb"                                       = "1"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
  }
}

resource "aws_subnet" "app" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.this.id
  availability_zone = var.availability_zones[count.index]
  cidr_block        = var.app_subnet_cidrs[count.index]

  tags = {
    Name                                                           = "${var.project_name}-${var.environment}-${var.region}-app-${count.index + 1}"
    "kubernetes.io/role/internal-elb"                              = "1"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
    "karpenter.sh/discovery"                                       = "${var.project_name}-${var.environment}"
  }
}

resource "aws_subnet" "data" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.this.id
  availability_zone = var.availability_zones[count.index]
  cidr_block        = var.data_subnet_cidrs[count.index]

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.region}-data-${count.index + 1}"
    Tier = "data"
  }
}

resource "aws_subnet" "integration" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.this.id
  availability_zone = var.availability_zones[count.index]
  cidr_block        = var.integration_subnet_cidrs[count.index]

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.region}-integration-${count.index + 1}"
    Tier = "integration"
  }
}

resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.region}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "this" {
  count = length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.region}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.region}-rt-public"
  }
}

resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.region}-rt-private-${count.index + 1}"
  }
}

resource "aws_route_table_association" "app" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "data" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "integration" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.integration[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_security_group" "vpce" {
  count = var.enable_vpc_endpoints ? 1 : 0

  name        = "${var.project_name}-${var.environment}-${var.region}-vpce-sg"
  description = "Allow TLS from VPC to interface endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  interface_endpoint_services = var.enable_vpc_endpoints ? toset([
    "com.amazonaws.${var.region}.secretsmanager",
    "com.amazonaws.${var.region}.sts",
    "com.amazonaws.${var.region}.ecr.api",
    "com.amazonaws.${var.region}.ecr.dkr",
    "com.amazonaws.${var.region}.logs",
    "com.amazonaws.${var.region}.kms",
    "com.amazonaws.${var.region}.ssm"
  ]) : toset([])
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoint_services

  vpc_id              = aws_vpc.this.id
  vpc_endpoint_type   = "Interface"
  service_name        = each.value
  subnet_ids          = aws_subnet.integration[*].id
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce[0].id]

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.region}-${replace(each.value, "com.amazonaws.${var.region}.", "")}-vpce"
  }
}
