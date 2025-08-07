# Network module demonstrating VPC and networking resources
# This module creates a complete VPC infrastructure with public and private subnets

# Data source to get available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Resource
# Demonstrates: Basic resource creation, tags merging
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  # Demonstrate tag merging with local tags
  tags = merge(var.common_tags, {
    Name = "${var.environment}-vpc"
    Type = "Main"
  })
}

# Public Subnets using count
# Demonstrates: Count parameter, dynamic resource creation
resource "aws_subnet" "public" {
  count             = length(var.public_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnets[count.index]
  availability_zone = var.availability_zones[count.index]
  
  map_public_ip_on_launch = true
  
  tags = merge(var.common_tags, {
    Name = "${var.environment}-public-${count.index + 1}"
    Type = "Public"
    Tier = "Web"
  })
}

# Private Subnets using count
# Demonstrates: Count parameter, dynamic resource creation
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]
  
  tags = merge(var.common_tags, {
    Name = "${var.environment}-private-${count.index + 1}"
    Type = "Private"
    Tier = "Application"
  })
}

# Internet Gateway
# Demonstrates: Simple resource creation, dependency management
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(var.common_tags, {
    Name = "${var.environment}-igw"
  })
}

# NAT Gateway with EIP
# Demonstrates: Count parameter, explicit dependencies
resource "aws_eip" "nat" {
  count = length(var.public_subnets)
  
  tags = merge(var.common_tags, {
    Name = "${var.environment}-nat-eip-${count.index + 1}"
  })

  # Explicit dependency on Internet Gateway
  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count         = length(var.public_subnets)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  
  tags = merge(var.common_tags, {
    Name = "${var.environment}-nat-${count.index + 1}"
  })

  # Explicit dependency
  depends_on = [aws_internet_gateway.main]
}

# Route Tables
# Demonstrates: Dynamic blocks, count parameter
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = merge(var.common_tags, {
    Name = "${var.environment}-public-rt"
    Type = "Public"
  })
}

resource "aws_route_table" "private" {
  count  = length(var.private_subnets)
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }
  
  tags = merge(var.common_tags, {
    Name = "${var.environment}-private-rt-${count.index + 1}"
    Type = "Private"
  })
}

# Route Table Associations
# Demonstrates: Count parameter, splat expressions
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# VPC Flow Logs
# Demonstrates: Conditional creation, dynamic blocks
resource "aws_flow_log" "main" {
  count                = var.enable_flow_logs ? 1 : 0
  iam_role_arn        = aws_iam_role.flow_logs[0].arn
  log_destination     = aws_cloudwatch_log_group.flow_logs[0].arn
  traffic_type        = "ALL"
  vpc_id              = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.environment}-vpc-flow-logs"
  })
}

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/aws/vpc/${var.environment}-flow-logs"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name = "${var.environment}-vpc-flow-logs"
  })
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.environment}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}


# IAM Role Policy for Flow Logs
resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.environment}-vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Network ACLs with dynamic block
# Demonstrates: Dynamic blocks, for_each
resource "aws_network_acl" "main" {
  vpc_id = aws_vpc.main.id
  
  # Ingress rules
  dynamic "ingress" {
    for_each = var.network_acls
    content {
      protocol   = ingress.value.protocol
      rule_no    = ingress.value.rule_no
      action     = ingress.value.action
      cidr_block = ingress.value.cidr_block
      from_port  = ingress.value.from_port
      to_port    = ingress.value.to_port
    }
  }

  # Egress rules (using the same rules as ingress)
  dynamic "egress" {
    for_each = var.network_acls
    content {
      protocol   = egress.value.protocol
      rule_no    = egress.value.rule_no
      action     = egress.value.action
      cidr_block = egress.value.cidr_block
      from_port  = egress.value.from_port
      to_port    = egress.value.to_port
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-main-nacl"
  })
}

# Associate NACLs with Subnets
resource "aws_network_acl_association" "public" {
  count = length(var.public_subnets)
  
  network_acl_id = aws_network_acl.main.id
  subnet_id      = aws_subnet.public[count.index].id
}

resource "aws_network_acl_association" "private" {
  count = length(var.private_subnets)
  
  network_acl_id = aws_network_acl.main.id
  subnet_id      = aws_subnet.private[count.index].id
}