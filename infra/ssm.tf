# SSM Parameter for Email Validation Token
resource "aws_ssm_parameter" "email_validation_token" {
  name        = "/email-service/auth-token"
  description = "Authentication token for email validation service"
  type        = "SecureString"
  value       = var.email_validation_token

  tags = {
    Name        = "email-validation-token"
    Environment = "production"
    Service     = "email-validation"
  }
}

# Additional SSM Parameters for configuration
resource "aws_ssm_parameter" "sqs_queue_url" {
  name        = "/email-service/sqs-queue-url"
  description = "SQS Queue URL for email processing"
  type        = "String"
  value       = aws_sqs_queue.email_processing_queue.url

  tags = {
    Name        = "email-service-sqs-url"
    Environment = "production"
    Service     = "email-validation"
  }
}

# SSM Parameter for S3 Bucket Name
resource "aws_ssm_parameter" "s3_bucket_name" {
  name        = "/email-service/s3-bucket-name"
  description = "S3 Bucket name for email storage"
  type        = "String"
  value       = aws_s3_bucket.email_storage.bucket

  tags = {
    Name        = "email-service-s3-bucket"
    Environment = "production"
    Service     = "email-processing"
  }
}