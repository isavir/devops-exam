output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "prefix" {
  description = "Resource prefix"
  value       = var.prefix
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "vpc_id" {
  description = "ID of the VPC where the cluster is deployed"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

# ECR Outputs
output "ecr_repository_url" {
  description = "The URI of the shared ECR repository for all microservices"
  value       = aws_ecr_repository.microservices.repository_url
}

output "ecr_repository_name" {
  description = "The name of the shared ECR repository"
  value       = aws_ecr_repository.microservices.name
}

# SQS Outputs
output "sqs_queue_url" {
  description = "URL of the SQS queue for email processing"
  value       = aws_sqs_queue.email_processing_queue.url
}

output "sqs_queue_arn" {
  description = "ARN of the SQS queue for email processing"
  value       = aws_sqs_queue.email_processing_queue.arn
}

output "sqs_dlq_url" {
  description = "URL of the SQS dead letter queue"
  value       = aws_sqs_queue.email_processing_dlq.url
}

# SSM Outputs
output "ssm_parameter_name" {
  description = "Name of the SSM parameter containing the auth token"
  value       = aws_ssm_parameter.email_validation_token.name
}


# IAM Outputs (from eks.tf)
output "email_validation_service_role_arn" {
  description = "ARN of the IAM role for email validation service"
  value       = aws_iam_role.email_validation_service_role.arn
}

output "email_processor_service_role_arn" {
  description = "ARN of the IAM role for email processor service"
  value       = aws_iam_role.email_processor_service_role.arn
}

output "items_service_role_arn" {
  description = "ARN of the IAM role for items service"
  value       = aws_iam_role.items_service_role.arn
}

output "audit_service_role_arn" {
  description = "ARN of the IAM role for audit service"
  value       = aws_iam_role.audit_service_role.arn
}

# S3 Outputs
output "s3_email_storage_bucket_name" {
  description = "Name of the S3 bucket for email storage"
  value       = aws_s3_bucket.email_storage.bucket
}

output "s3_email_storage_bucket_arn" {
  description = "ARN of the S3 bucket for email storage"
  value       = aws_s3_bucket.email_storage.arn
}