data "aws_caller_identity" "current" {}

# SQS Queue for Email Processing
resource "aws_sqs_queue" "email_processing_queue" {
  name                       = "${var.prefix}-email-processing-queue"
  delay_seconds              = 0
  max_message_size           = 262144
  message_retention_seconds  = 1209600 # 14 days
  receive_wait_time_seconds  = 10      # Long polling
  visibility_timeout_seconds = 300     # 5 minutes

  # Dead Letter Queue configuration
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.email_processing_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name        = "${var.prefix}-email-processing-queue"
    Environment = var.environment
    Service     = "email-validation"
  }
}

# Dead Letter Queue for failed messages
resource "aws_sqs_queue" "email_processing_dlq" {
  name                      = "${var.prefix}-email-processing-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = {
    Name        = "${var.prefix}-email-processing-dlq"
    Environment = var.environment
    Service     = "email-validation"
  }
}

# SQS Queue Policy
resource "aws_sqs_queue_policy" "email_processing_queue_policy" {
  queue_url = aws_sqs_queue.email_processing_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEKSPodsAccess"
        Effect = "Allow"
        Principal = {
          AWS = [
            var.email_validation_role_arn,
            var.email_processor_role_arn
          ]
        }
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.email_processing_queue.arn
      }
    ]
  })
}

# SSM Parameter for Email Validation Token
resource "aws_ssm_parameter" "email_validation_token" {
  name        = "/email-service/auth-token"
  description = "Authentication token for email validation service"
  type        = "SecureString"
  value       = var.email_validation_token

  tags = {
    Name        = "email-validation-token"
    Environment = var.environment
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
    Environment = var.environment
    Service     = "email-validation"
  }
}