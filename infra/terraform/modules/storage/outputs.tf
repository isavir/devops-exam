output "ecr_repository_url" {
  description = "The URI of the shared ECR repository for all microservices"
  value       = aws_ecr_repository.microservices.repository_url
}

output "ecr_repository_name" {
  description = "The name of the shared ECR repository"
  value       = aws_ecr_repository.microservices.name
}

output "s3_email_storage_bucket_name" {
  description = "Name of the S3 bucket for email storage"
  value       = aws_s3_bucket.email_storage.bucket
}

output "s3_email_storage_bucket_arn" {
  description = "ARN of the S3 bucket for email storage"
  value       = aws_s3_bucket.email_storage.arn
}