output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.web.dns_name
}

output "web_sg_id" {
  description = "ID of the web servers security group"
  value       = aws_security_group.web.id
}

output "instance_ids" {
  description = "IDs of instances in the ASG"
  value       = aws_autoscaling_group.web.id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.web.arn
}

output "bastion_asg_name" {
  description = "Name of the Bastion Auto Scaling Group"
  value       = aws_autoscaling_group.bastion.name
}

output "bastion_sg_id" {
  description = "ID of the Bastion Security Group"
  value       = aws_security_group.bastion.id
}

output "web_asg_name" {
  description = "Name of the Web Auto Scaling Group"
  value       = aws_autoscaling_group.web.name
}

output "ssh_key_path" {
  description = "Path to the SSH private key"
  value       = "${path.module}/.ssh/lamp_key"
}

output "bastion_nlb_dns" {
  description = "DNS name of the bastion Network Load Balancer"
  value       = aws_lb.bastion.dns_name
}

output "web_alb_dns" {
  description = "DNS name of the web Application Load Balancer"
  value       = aws_lb.web.dns_name
}
