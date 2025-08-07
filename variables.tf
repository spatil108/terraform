# Variable definitions with type constraints and validations
# Demonstrates: Type Constraints, Custom Validations, Variable Types

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be valid (e.g., us-east-1, eu-central-1)."
  }
}

variable "environment" {
  description = "Environment name (dev/stage/prod)"
  type        = string

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Environment must be one of: dev, stage, prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be valid IPv4 CIDR notation."
  }
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
}

# Complex type constraints example
variable "instance_config" {
  description = "Configuration for EC2 instances"
  type = object({
    instance_type = string
    volume_size   = number
    is_public     = bool
    tags          = map(string)
  })

  validation {
    condition     = can(regex("^t[23]|m[45]|c[56]", var.instance_config.instance_type))
    error_message = "Instance type must be a valid AWS instance type."
  }
}

variable "db_config" {
  description = "Database configuration"
  type = object({
    instance_class    = string
    allocated_storage = number
    engine_version    = string
    name              = string
    username          = string
    password          = string
  })
}