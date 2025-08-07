# LAMP Stack Infrastructure with Terraform

This repository contains Terraform configurations to deploy a highly available LAMP (Linux, Apache, MySQL, PHP) stack on AWS with a bastion host architecture.

## Architecture Diagram

![Architecture Diagram](image/lamp_stack_architecture.png)
## Prerequisites

### Required Tools
- Terraform (>= 1.11.0)
- AWS CLI (>= 2.0.0)
- Git
- MySQL Client (for database initialization)

### AWS Account Requirements
- AWS Account with administrative access
- AWS Access Key and Secret Key
- S3 bucket for Terraform state (optional for remote state)
- DynamoDB table for state locking (optional for remote state)


## Project Structure
```
lamp-stack/
├── README.md                     # Project documentation
├── main.tf                       # Main Terraform configuration
├── outputs.tf                    # Root output definitions
├── provider.tf                   # AWS provider configuration
├── ssh_setup.tf                 # SSH key generation and management
├── terraform.tfvars            # Variable values
├── variables.tf                # Variable declarations
├── deploy.sh                   # Deployment automation script
│
├── modules/
│   ├── compute/                # Compute module (EC2, ASG, Load Balancers)
│   │   ├── main.tf            # Main compute configuration
│   │   ├── outputs.tf         # Compute outputs
│   │   ├── security_groups.tf # Security group definitions
│   │   ├── variables.tf       # Compute variables
│   │   ├── scripts/
│   │   │   └── init.sql      # Database initialization script
│   │   └── templates/
│   │       ├── bastion_user_data.sh.tpl  # Bastion host initialization
│   │       └── web_user_data.sh.tpl      # Web server initialization
│   │
│   ├── database/              # Database module (RDS)
│   │   ├── main.tf           # Main RDS configuration
│   │   ├── outputs.tf        # Database outputs
│   │   ├── security_groups.tf # Database security groups
│   │   └── variables.tf      # Database variables
│   │
│   └── network/              # Network module (VPC, Subnets)
│       ├── main.tf           # Main network configuration
│       ├── outputs.tf        # Network outputs
│       └── variables.tf      # Network variables
│
└── .ssh/                     # Generated SSH keys (gitignored)
    ├── lamp_key             # Private key
    └── lamp_key.pub         # Public key

```

### Key Files Description

#### Root Level Files
- `main.tf`: Main Terraform configuration with module orchestration
- `outputs.tf`: Defines output values from all modules
- `provider.tf`: AWS provider configuration and backend setup
- `ssh_setup.tf`: SSH key pair generation and management
- `terraform.tfvars`: Variable values for deployment
- `variables.tf`: Variable declarations with validations
- `deploy.sh`: Deployment automation script

#### Compute Module
- `main.tf`: EC2 instances, Auto Scaling Groups, and Load Balancers
- `security_groups.tf`: Security group definitions for compute resources
- `templates/`:
  - `bastion_user_data.sh.tpl`: Bastion host initialization script
  - `web_user_data.sh.tpl`: Web server configuration and application setup
- `scripts/init.sql`: Database schema and initial data

#### Database Module
- `main.tf`: RDS instance configuration
- `security_groups.tf`: Database security group rules
- `outputs.tf`: Database endpoint and connection information
- `variables.tf`: Database configuration variables

#### Network Module
- `main.tf`: VPC, subnets, gateways, and routing configuration
- `outputs.tf`: Network IDs and reference values
- `variables.tf`: Network configuration variables

#### Generated Files
- `.ssh/lamp_key`: Private SSH key for instance access
- `.ssh/lamp_key.pub`: Public SSH key for instance configuration

### Important Notes
1. The `.ssh/` directory is automatically generated and should be in `.gitignore`
2. Template files contain environment-specific variables
3. Security group configurations are separated for better management
4. Each module has its own variables and outputs
5. User data templates contain application setup scripts

### Application Files (in web_user_data.sh.tpl)
```
/var/www/html/
├── index.php           # Main application page
├── feedback.php        # Feedback submission form
├── get_messages.php    # AJAX endpoint for messages
├── submit_feedback.php # Feedback processing
├── thank_you.php      # Confirmation page
├── health.php         # Health check endpoint
└── app/
    └── init_db.php    # Database initialization
```


## Features

### Infrastructure
- Multi-AZ deployment across 3 availability zones
- Auto Scaling Groups for web and bastion servers
- Application Load Balancer for web traffic
- Network Load Balancer for bastion access
- Private subnets for database and web servers
- Public subnets for load balancers
- Automated SSH key management

### Application
- PHP-based feedback application
- MySQL database backend
- Health check endpoints
- Automated database initialization
- User-friendly web interface


## Quick Start

1. Clone the repository:
```bash
git clone git@ssh.gitlab.aws.dev:chakradd/ams-terraform-ilt.git
cd lamp-stack
```

2. Configure Terraform State Locking using DynamoDB and S3 Bucket.

### Backend Setup

Create a new file `backend_setup.tf`:

```hcl
# Provider configuration
provider "aws" {
  region = "us-east-1"  # Change to your desired region
}

# Variables
variable "project_name" {
  description = "Project name"
  type        = string
  default     = "lamp-stack"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# Random string for unique naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-state-${var.project_name}-${var.environment}-${random_string.suffix.result}"

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "terraform-state-${var.project_name}-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-locks-${var.project_name}-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "terraform-locks-${var.project_name}-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# Outputs
output "backend_config" {
  description = "Backend configuration for main Terraform configuration"
  value = {
    bucket         = aws_s3_bucket.terraform_state.id
    dynamodb_table = aws_dynamodb_table.terraform_locks.id
    region         = aws_s3_bucket.terraform_state.region
    key            = "terraform.tfstate"
  }
}
```

### Usage Instructions

1. Save the above configuration as `backend_setup.tf`

2. Initialize Terraform:
```bash
terraform init
```

3. Apply the configuration:
```bash
terraform apply
```

4. Note the outputs and update your main Terraform configuration with the backend:
```hcl
terraform {
  backend "s3" {
    bucket         = "<output_bucket_name>"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "<output_table_name>"
    encrypt        = true
  }
}
```

### Features
- Unique bucket and table names using random suffix
- Versioning enabled
- Server-side encryption
- Public access blocked
- State locking with DynamoDB
- Proper tagging
- Prevent accidental deletion

### Security Considerations
- Bucket versioning enabled
- Encryption enabled
- Public access blocked
- State locking enabled
- Access logs available
- Secure IAM policies

### Cost Considerations
- S3 costs based on storage and requests
- DynamoDB on-demand pricing
- Monitor usage and costs

### Best Practices
1. Use unique names
2. Enable versioning
3. Enable encryption
4. Block public access
5. Use state locking
6. Implement proper tagging
7. Monitor access logs

### Cleanup
To destroy the backend (if needed):
```bash
# Remove state files first
terraform state rm aws_s3_bucket.terraform_state

# Then destroy
terraform destroy
```

Remember to:
- Keep backend configuration secure
- Use proper naming conventions
- Enable versioning and encryption
- Block public access
- Use proper IAM permissions
- Monitor costs
- Implement proper backup strategies

3. Create `terraform.tfvars`:
```hcl
# Variable values for the deployment
aws_region     = "us-east-1"
environment    = "dev"
project_name   = "lamp-stack"
owner          = "DevOps-Team"
cost_center    = "12345"
bucket         = "chakradd-terraform-state-bucket" #replace with your s3 bucket name created from above
dynamodb_table = "terraform-state-lock" #replace with your dynamodb_table name created from above

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
  name              = "lampdb"
  username          = "admin"
  password          = "Change-Me-123!" # Should be handled through secrets management
}
```

4. Initialize Terraform:
```bash
terraform init
```

5. Apply the configuration:
```bash
terraform apply
```

## Module Details

### Network Module (`modules/network`)
- VPC with public and private subnets
- NAT Gateways for private subnet connectivity
- Route tables and Internet Gateway
- Optional VPC Flow Logs

### Compute Module (`modules/compute`)
- Web server Auto Scaling Group
- Bastion host Auto Scaling Group
- Application Load Balancer
- Network Load Balancer for bastion access
- Security groups and SSH key management
- User data scripts for server configuration

### Database Module (`modules/database`)
- RDS MySQL instance
- Private subnet deployment
- Security group configuration
- Automated initialization

## Security Features

### Network Security
- Bastion host architecture
- Private subnets for sensitive resources
- Security group restrictions
- SSH key-based authentication

### Application Security
- Database password management
- Private network communication
- Regular security updates
- Health monitoring endpoints

## Maintenance

### Updates and Modifications
```bash
# Plan changes
terraform plan

# Apply changes
terraform apply

# Destroy infrastructure
terraform destroy
```

### Monitoring
- CloudWatch metrics for instances
- RDS performance monitoring
- Application health checks
- Load balancer metrics

## Troubleshooting

### Common Issues
1. SSH Connection Issues
```bash
# Test bastion connection
ssh -i .ssh/lamp_key ec2-user@<bastion-ip>

# Test web server connection through bastion
ssh -F /tmp/ssh_config webserver
```

2. Database Connection Issues
```bash
# Test from web server
mysql -h <rds-endpoint> -u admin -p -e "SELECT VERSION();"
```

### Logs
- Check CloudWatch Logs
- Review System Logs
- Monitor RDS Logs

## Contributing
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License
This project is licensed under the MIT License - see the LICENSE file for details.

## Authors
Chakradhar Devarakonda

## Acknowledgments
- AWS Documentation
- Terraform Documentation
- Community Contributors

## Support
For support, please create an issue in the GitHub repository or contact the maintainers.

## Additional Resources
- [AWS Documentation](https://docs.aws.amazon.com/)
- [Terraform Documentation](https://www.terraform.io/docs/)
- [LAMP Stack Best Practices](https://aws.amazon.com/what-is/lamp-stack/)

## Environment Variables
```bash
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
export AWS_DEFAULT_REGION="us-east-1"
```

## Tags
- Environment
- Project
- ManagedBy
- Owner

Remember to:
- Update passwords and credentials
- Review security settings
- Monitor costs
- Keep documentation updated
- Implement proper backup strategies