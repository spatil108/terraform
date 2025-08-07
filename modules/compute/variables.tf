variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "project name"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "instance_config" {
  description = "EC2 instance configuration"
  type = object({
    instance_type = string
    volume_size   = number
    is_public     = bool
    tags          = map(string)
  })
}

variable "asg_config" {
  description = "Auto Scaling Group configuration"
  type = object({
    min_size         = number
    max_size         = number
    desired_capacity = number
  })
  default = {
    min_size         = 2
    max_size         = 4
    desired_capacity = 2
  }
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "db_endpoint" {
  description = "Database endpoint"
  type        = string
}

variable "db_config" {
  description = "Database configuration"
  type = object({
    name     = string
    username = string
    password = string
  })
}

variable "bastion_instance_type" {
  description = "Instance type for bastion hosts"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
}

variable "ssh_private_key" {
  description = "Content of the SSH private key"
  type        = string
  sensitive   = true
}