# Compute module for EC2 instances and related resources
# Demonstrates: Launch Templates, Auto Scaling, Load Balancer

# Data source for latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# Bastion Launch Template
resource "aws_launch_template" "bastion" {
  name_prefix   = "${var.environment}-bastion-template"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.bastion_instance_type

  network_interfaces {
    associate_public_ip_address = true
    security_groups            = [aws_security_group.bastion.id]
  }

  key_name = var.key_name  # Use the key name passed from root

  user_data = base64encode(templatefile("${path.module}/templates/bastion_user_data.sh.tpl", {
    environment = var.environment
    ssh_key     = var.ssh_private_key
  }))

  tags = var.common_tags

  lifecycle {
    create_before_destroy = true
  }
}



# Bastion Auto Scaling Group
resource "aws_autoscaling_group" "bastion" {
  name                = "${var.environment}-bastion-asg"
  desired_capacity    = 1
  max_size           = 1
  min_size           = 1
  target_group_arns  = [aws_lb_target_group.bastion.arn]
  vpc_zone_identifier = var.public_subnets

  launch_template {
    id      = aws_launch_template.bastion.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = merge(var.common_tags, {
      Name = "${var.environment}-bastion"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# Web Server Launch Template
# Demonstrates: Dynamic Blocks, User Data
resource "aws_launch_template" "web" {
  name_prefix   = "${var.environment}-web-template"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_config.instance_type

  network_interfaces {
    associate_public_ip_address = false
    security_groups            = [aws_security_group.web.id]
  }

  key_name = var.key_name  # Use the key name passed from root

  user_data = base64encode(templatefile("${path.module}/templates/web_user_data.sh.tpl", {
    environment = var.environment
    db_host     = split(":", var.db_endpoint)[0]
    db_port     = split(":", var.db_endpoint)[1]
    db_name     = var.db_config.name
    db_username = var.db_config.username
    db_password = var.db_config.password
  }))

  tags = var.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# Web Server Auto Scaling Group
# Demonstrates: For Each, Dependencies
resource "aws_autoscaling_group" "web" {
  name                = "${var.environment}-web-asg"
  desired_capacity    = var.asg_config.desired_capacity
  max_size           = var.asg_config.max_size
  min_size           = var.asg_config.min_size
  target_group_arns  = [aws_lb_target_group.web.arn]
  vpc_zone_identifier = var.private_subnets  # Use private subnets

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = merge(var.common_tags, {
      Name = "${var.environment}-web"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# Database initialization through bastion
resource "null_resource" "db_init" {
  depends_on = [aws_autoscaling_group.web, aws_autoscaling_group.bastion]

  triggers = {
    db_endpoint = var.db_endpoint
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for bastion host to be available
      echo "Waiting for bastion host..."
      
      # Get bastion instance ID
      BASTION_ID=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-name ${aws_autoscaling_group.bastion.name} \
        --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
        --output text)
      
      # Get bastion IP
      BASTION_IP=$(aws ec2 describe-instances \
        --instance-ids $BASTION_ID \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)
      
      echo "Bastion IP: $BASTION_IP"

      # Get web server private IP
      WEB_ID=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-name ${aws_autoscaling_group.web.name} \
        --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
        --output text)
      
      WEB_IP=$(aws ec2 describe-instances \
        --instance-ids $WEB_ID \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
        --output text)
      
      echo "Web server IP: $WEB_IP"
      
      # Create temporary SSH config
      echo "Host bastion
        HostName $BASTION_IP
        User ec2-user
        IdentityFile ${abspath(path.root)}/.ssh/lamp_key
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
        " > /tmp/ssh_config

      echo "" >> /tmp/ssh_config

      # Create temporary SSH config
      echo "Host webserver
        HostName $WEB_IP
        User ec2-user
        IdentityFile ${abspath(path.root)}/.ssh/lamp_key
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
        " >> /tmp/ssh_config
      
      echo "Created SSH config:"
      cat /tmp/ssh_config
      
      # Wait for bastion to be ready
      for i in {1..30}; do
        echo "Attempting to connect to bastion (attempt $i)..."
        if ssh -F /tmp/ssh_config bastion "echo 'Bastion is ready'" 2>/dev/null; then
          echo "Bastion host is ready!"
          break
        fi
        if [ $i -eq 30 ]; then
          echo "Timeout waiting for bastion"
          exit 1
        fi
        echo "Waiting for bastion to be ready..."
        sleep 10
      done

      # Test SSH connection from bastion to webserver
      echo "Testing connection from bastion to webserver..."
      ssh -F /tmp/ssh_config bastion "ssh -o StrictHostKeyChecking=no -i ~/.ssh/lamp_key ec2-user@$WEB_IP 'echo Web server is accessible from bastion'"
      
      # Copy database initialization script to bastion
      echo "Copying initialization script to bastion..."
      scp -F /tmp/ssh_config ${path.module}/scripts/init.sql bastion:/tmp/init.sql
      
      # Copy from bastion to webserver
      echo "Copying initialization script from bastion to webserver..."
      ssh -F /tmp/ssh_config bastion "scp -o StrictHostKeyChecking=no -i ~/.ssh/lamp_key /tmp/init.sql ec2-user@$WEB_IP:/tmp/init.sql"
      
      # Sleep for 5 sec
      sleep 5
      
      # Execute database initialization from web server through bastion
      echo "Initializing database from webserver..."
      ssh -F /tmp/ssh_config bastion "ssh -o StrictHostKeyChecking=no -i ~/.ssh/lamp_key ec2-user@$WEB_IP '\
        echo \"Testing MySQL connection...\" && \
        mysql -h ${split(":", var.db_endpoint)[0]} \
        -P ${split(":", var.db_endpoint)[1]} \
        -u ${var.db_config.username} \
        -p\"${var.db_config.password}\" \
        -e \"SELECT VERSION();\" && \
        echo \"Initializing database...\" && \
        mysql -h ${split(":", var.db_endpoint)[0]} \
        -P ${split(":", var.db_endpoint)[1]} \
        -u ${var.db_config.username} \
        -p\"${var.db_config.password}\" \
        < /tmp/init.sql && \
        echo \"Verifying table structure...\" && \
        mysql -h ${split(":", var.db_endpoint)[0]} \
        -P ${split(":", var.db_endpoint)[1]} \
        -u ${var.db_config.username} \
        -p\"${var.db_config.password}\" \
        -e \"DESCRIBE lampapp.feedback;\"'"
      
      # Clean up
      echo "Cleaning up..."
      rm -f /tmp/ssh_config

      echo "Database initialization complete!"
    EOT
  }
}


# Application Load Balancer
# Demonstrates: Load Balancer Configuration
# Bastion Load Balancer
resource "aws_lb" "bastion" {
  name               = "${var.environment}-bastion-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets           = var.public_subnets

  enable_cross_zone_load_balancing = true

  tags = var.common_tags
}

# Bastion Target Group
resource "aws_lb_target_group" "bastion" {
  name     = "${var.environment}-bastion-tg"
  port     = 22
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    port               = 22
    protocol           = "TCP"
    timeout            = 10
    unhealthy_threshold = 2
  }

  tags = var.common_tags
}

# Bastion Listener
resource "aws_lb_listener" "bastion" {
  load_balancer_arn = aws_lb.bastion.arn
  port              = 22
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bastion.arn
  }
}

# Web Application Load Balancer
resource "aws_lb" "web" {
  name               = "${var.environment}-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets           = var.public_subnets

  tags = var.common_tags
}

# Web Target Group
resource "aws_lb_target_group" "web" {
  name     = "${var.environment}-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher            = "200"
    path               = "/health.php"
    port               = "traffic-port"
    timeout            = 5
    unhealthy_threshold = 2
  }

  tags = var.common_tags
}

# Web Listener
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}