# Database module for RDS instance
# Demonstrates: Sensitive Data, Subnet Groups

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnets
  
  tags = merge(var.common_tags, {
    Name = "${var.environment}-db-subnet-group"
  })
}

# RDS Instance
# Demonstrates: Sensitive Data Handling, Resource Dependencies
resource "aws_db_instance" "main" {
  identifier           = "${var.environment}-db"
  allocated_storage    = var.db_config.allocated_storage
  storage_type         = "gp2"
  engine              = "mysql"
  engine_version      = var.db_config.engine_version
  instance_class      = var.db_config.instance_class
  db_name             = var.db_config.name
  username            = var.db_config.username
  password            = var.db_config.password
  
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  
  backup_retention_period = var.environment == "prod" ? 7 : 1
  skip_final_snapshot    = var.environment != "prod"
  
  tags = merge(var.common_tags, {
    Name = "${var.environment}-db"
  })
}