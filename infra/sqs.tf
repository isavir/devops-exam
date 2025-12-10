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
    Environment = "production"
    Service     = "email-validation"
  }
}

# Dead Letter Queue for failed messages
resource "aws_sqs_queue" "email_processing_dlq" {
  name                      = "${var.prefix}-email-processing-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = {
    Name        = "${var.prefix}-email-processing-dlq"
    Environment = "production"
    Service     = "email-validation"
  }
}

# SQS Queue Policy references the IAM role defined in eks.tf
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
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.prefix}-email-validation-service-role",
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.prefix}-email-processor-service-role"
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