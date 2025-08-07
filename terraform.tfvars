# Variable values for the deployment
aws_region     = "us-east-1"
environment    = "dev"
project_name   = "lamp-stack"
owner          = "DevOps-Team"
cost_center    = "12345"

vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

instance_config = {
  instance_type = "t3.micro"
  volume_size   = 20
  is_public     = false
  tags = {
    Application = "LAMP"
    Component   = "Web"
  }
}

db_config = {
  allocated_storage = 20
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  name              = "lampapp"
  username          = "admin"
  password          = "Change-Me-123!" # Should be handled through secrets management
}

