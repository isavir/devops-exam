data "aws_caller_identity" "current" {}

# ECR Repository for all microservices
resource "aws_ecr_repository" "microservices" {
  name                 = "${var.prefix}-microservices"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.prefix}-microservices"
    Environment = var.environment
  }
}

# S3 Bucket for Email Storage
resource "aws_s3_bucket" "email_storage" {
  bucket = "${var.prefix}-email-storage-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "${var.prefix}-email-storage"
    Environment = var.environment
    Service     = "email-processing"
  }
}

# Random suffix for bucket name uniqueness
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "email_storage_versioning" {
  bucket = aws_s3_bucket.email_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "email_storage_pab" {
  bucket = aws_s3_bucket.email_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Policy
resource "aws_s3_bucket_policy" "email_storage_policy" {
  bucket = aws_s3_bucket.email_storage.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEmailProcessorAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.email_processor_role_arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.email_storage.arn,
          "${aws_s3_bucket.email_storage.arn}/*"
        ]
      },
      {
        Sid       = "DenyInsecureConnections"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.email_storage.arn,
          "${aws_s3_bucket.email_storage.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# SSM Parameter for S3 Bucket Name
resource "aws_ssm_parameter" "s3_bucket_name" {
  name        = "/email-service/s3-bucket-name"
  description = "S3 Bucket name for email storage"
  type        = "String"
  value       = aws_s3_bucket.email_storage.bucket

  tags = {
    Name        = "email-service-s3-bucket"
    Environment = var.environment
    Service     = "email-processing"
  }
}