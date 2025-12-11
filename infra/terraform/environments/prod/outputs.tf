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
  value       = module.networking.vpc_id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.networking.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.networking.public_subnets
}

# ECR Outputs
output "ecr_repository_url" {
  description = "The URI of the shared ECR repository for all microservices"
  value       = module.storage.ecr_repository_url
}

output "ecr_repository_name" {
  description = "The name of the shared ECR repository"
  value       = module.storage.ecr_repository_name
}

# SQS Outputs
output "sqs_queue_url" {
  description = "URL of the SQS queue for email processing"
  value       = module.messaging.sqs_queue_url
}

output "sqs_queue_arn" {
  description = "ARN of the SQS queue for email processing"
  value       = module.messaging.sqs_queue_arn
}

output "sqs_dlq_url" {
  description = "URL of the SQS dead letter queue"
  value       = module.messaging.sqs_dlq_url
}

# SSM Outputs
output "ssm_parameter_name" {
  description = "Name of the SSM parameter containing the auth token"
  value       = module.messaging.ssm_parameter_name
}

output "ssm_sqs_queue_url_parameter" {
  description = "Name of the SSM parameter containing the SQS queue URL"
  value       = module.messaging.sqs_queue_url_ssm_parameter
}

output "ssm_s3_bucket_name_parameter" {
  description = "Name of the SSM parameter containing the S3 bucket name"
  value       = module.storage.s3_bucket_name_ssm_parameter
}

# IAM Outputs
output "email_validation_service_role_arn" {
  description = "ARN of the IAM role for email validation service"
  value       = module.eks.email_validation_service_role_arn
}

output "email_processor_service_role_arn" {
  description = "ARN of the IAM role for email processor service"
  value       = module.eks.email_processor_service_role_arn
}

# S3 Outputs
output "s3_email_storage_bucket_name" {
  description = "Name of the S3 bucket for email storage"
  value       = module.storage.s3_email_storage_bucket_name
}

output "s3_email_storage_bucket_arn" {
  description = "ARN of the S3 bucket for email storage"
  value       = module.storage.s3_email_storage_bucket_arn
}