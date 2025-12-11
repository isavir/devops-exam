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

output "ssm_parameter_name" {
  description = "Name of the SSM parameter containing the auth token"
  value       = aws_ssm_parameter.email_validation_token.name
}

output "sqs_queue_url_ssm_parameter" {
  description = "Name of the SSM parameter containing the SQS queue URL"
  value       = aws_ssm_parameter.sqs_queue_url.name
}