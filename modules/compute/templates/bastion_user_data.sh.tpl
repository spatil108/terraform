#!/bin/bash

# Update system
yum update -y

# Create .ssh directory
mkdir -p /home/ec2-user/.ssh

# Install the private key for connecting to web servers
cat > /home/ec2-user/.ssh/lamp_key << 'EOF'
${ssh_key}
EOF

# Set proper permissions
chmod 600 /home/ec2-user/.ssh/lamp_key
chown ec2-user:ec2-user /home/ec2-user/.ssh/lamp_key

# Install MySQL client
yum install -y mysql

# Tag instance
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

aws ec2 create-tags \
    --region $REGION \
    --resources $INSTANCE_ID \
    --tags Key=Name,Value=${environment}-bastion