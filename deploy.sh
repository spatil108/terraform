#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check command status
check_status() {
    if [ $? -eq 0 ]; then
        print_message "$GREEN" "✓ Success: $1"
    else
        print_message "$RED" "✗ Error: $1"
        exit 1
    fi
}

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    print_message "$RED" "Terraform is not installed. Please install it first."
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    print_message "$RED" "AWS credentials not configured. Please configure them first."
    exit 1
fi

# Initialize Terraform
print_message "$YELLOW" "Initializing Terraform..."
terraform init
check_status "Terraform initialization"

# Validate Terraform configuration
print_message "$YELLOW" "Validating Terraform configuration..."
terraform validate
check_status "Terraform validation"

# Create plan
print_message "$YELLOW" "Creating Terraform plan..."
terraform plan -out=tfplan
check_status "Terraform plan creation"

# Ask for confirmation
read -p "Do you want to apply this plan? (yes/no) " answer
if [ "$answer" != "yes" ]; then
    print_message "$YELLOW" "Deployment cancelled."
    exit 0
fi

# Apply plan
print_message "$YELLOW" "Applying Terraform plan..."
terraform apply tfplan
check_status "Terraform apply"

# Output important information
print_message "$GREEN" "\nDeployment completed successfully!"
print_message "$YELLOW" "\nImportant Information:"
terraform output

# Cleanup
rm -f tfplan
print_message "$GREEN" "\nCleanup completed."