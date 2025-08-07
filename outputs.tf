# Output values for resource references
# Demonstrates: Output Values, Splat Expressions

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.network.private_subnet_ids
}

output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = module.compute.alb_dns_name
}

output "db_endpoint" {
  description = "Endpoint of the RDS instance"
  value       = module.database.db_endpoint
  sensitive   = true
}

output "instance_ids" {
  description = "IDs of EC2 instances"
  value       = module.compute.instance_ids
}

output "ssh_key_path" {
  description = "Path to the SSH private key"
  value       = "${path.module}/.ssh/lamp_key"
  sensitive   = true
}

output "bastion_asg_name" {
  description = "Name of the Bastion Auto Scaling Group"
  value       = module.compute.bastion_asg_name
}

output "web_asg_name" {
  description = "Name of the Web Auto Scaling Group"
  value       = module.compute.web_asg_name
}