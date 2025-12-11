# Production Environment Configuration
aws_region  = "us-west-2"
prefix      = "exam"
environment = "production"

# EKS Configuration
cluster_version    = "1.29"
node_instance_type = "t3.small"
desired_capacity   = 1
max_capacity       = 1
min_capacity       = 1

# Network Configuration
vpc_cidr        = "10.0.0.0/16"
private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnets  = ["10.0.4.0/24", "10.0.5.0/24"]

# Security Configuration
email_validation_token = "$DJISA<$#45ex3RtYr"