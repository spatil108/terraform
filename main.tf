# Main configuration file demonstrating multiple Terraform concepts

# Local variables for common values and computations
# Demonstrates: Local Values, Built-in Functions
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Terraform   = "true"
    Owner       = var.owner
    CostCenter  = var.cost_center
  }

/*
Let's break down the calculation for 10.0.0.0/16 with 8 newbits for each subnet index:

Base Formula: BaseIP + (Index × 2^(32-NewPrefix))

BaseIP: 10.0.0.0
NewPrefix: 16 + 8 = 24
2^(32-24) = 2^8 = 256
Let's calculate for each index:

Private Subnet - Index 0:
10.0.0.0 + (0 × 2^(32-24))
= 10.0.0.0 + (0 × 256)
= 10.0.0.0

In binary:
10.0.0.0   = 00001010.00000000.00000000.00000000
0 × 256     = 00000000.00000000.00000000.00000000
Result      = 10.0.0.0/24
Private Subnet - Index 1:
10.0.0.0 + (1 × 2^(32-24))
= 10.0.0.0 + (1 × 256)
= 10.0.1.0

In binary:
10.0.0.0   = 00001010.00000000.00000000.00000000
1 × 256     = 00000000.00000000.00000001.00000000
Result      = 10.0.1.0/24
Private Subnet - Index 2:
10.0.0.0 + (2 × 2^(32-24))
= 10.0.0.0 + (2 × 256)
= 10.0.2.0

In binary:
10.0.0.0   = 00001010.00000000.00000000.00000000
2 × 256     = 00000000.00000000.00000010.00000000
Result      = 10.0.2.0/24
Public Subnet - Index 3:
10.0.0.0 + (3 × 2^(32-24))
= 10.0.0.0 + (3 × 256)
= 10.0.3.0

In binary:
10.0.0.0   = 00001010.00000000.00000000.00000000
3 × 256     = 00000000.00000000.00000011.00000000
Result      = 10.0.3.0/24
Public Subnet - Index 4:
10.0.0.0 + (4 × 2^(32-24))
= 10.0.0.0 + (4 × 256)
= 10.0.4.0

In binary:
10.0.0.0   = 00001010.00000000.00000000.00000000
4 × 256     = 00000000.00000000.00000100.00000000
Result      = 10.0.4.0/24
Public Subnet - Index 5:
10.0.0.0 + (5 × 2^(32-24))
= 10.0.0.0 + (5 × 256)
= 10.0.5.0

In binary:
10.0.0.0   = 00001010.00000000.00000000.00000000
5 × 256     = 00000000.00000000.00000101.00000000
Result      = 10.0.5.0/24
Key Points:

Each increment of the index shifts the subnet by 256 addresses (2^8)
The third octet increases by 1 for each subnet (because 256 is one complete octet)
Each /24 subnet contains 256 IP addresses
Private subnets use indexes 0-2 (10.0.0.0/24 to 10.0.2.0/24)
Public subnets use indexes 3-5 (10.0.3.0/24 to 10.0.5.0/24)
This creates a clean, non-overlapping subnet structure within the VPC, with clear separation between private and public subnets.

*/

  # Dynamic computation example
  az_count        = length(var.availability_zones)
  private_subnets = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  public_subnets  = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 8, i + local.az_count)]
}

# Pre-deployment validation
# Demonstrates: Null Resource, Local-exec Provisioner
resource "null_resource" "pre_deployment_check" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Starting deployment validation at $(date)"
      echo "Environment: ${var.environment}"
      echo "Region: ${var.aws_region}"
    EOT
  }
}

# Network Module
# Demonstrates: Module Usage, Dependencies
module "network" {
  source = "./modules/network"

  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  environment        = var.environment
  private_subnets    = local.private_subnets
  public_subnets     = local.public_subnets
  common_tags        = local.common_tags

  depends_on = [null_resource.pre_deployment_check]
}

# Compute Module
# Demonstrates: Module Dependencies, Data Sources
module "compute" {
  source = "./modules/compute"

  vpc_id          = module.network.vpc_id
  public_subnets  = module.network.public_subnet_ids
  private_subnets = module.network.private_subnet_ids
  environment     = var.environment
  project_name    = var.project_name
  common_tags     = local.common_tags
  instance_config = var.instance_config
  db_endpoint     = module.database.db_endpoint
  db_config = {
    name     = var.db_config.name
    username = var.db_config.username
    password = var.db_config.password
  }
  key_name        = aws_key_pair.lamp_key.key_name
  ssh_private_key = data.local_file.ssh_private_key.content
  depends_on      = [null_resource.ssh_key_gen]
}

# Database Module
# Demonstrates: Sensitive Data Handling, Explicit Dependencies
module "database" {
  source = "./modules/database"

  vpc_id          = module.network.vpc_id
  private_subnets = module.network.private_subnet_ids
  environment     = var.environment
  common_tags     = local.common_tags
  web_sg_id       = module.compute.web_sg_id
  db_config       = var.db_config
  depends_on      = [module.network]
}