variable "prefix" {
  description = "Prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "email_validation_role_arn" {
  description = "ARN of the email validation IAM role"
  type        = string
}

variable "email_processor_role_arn" {
  description = "ARN of the email processor IAM role"
  type        = string
}

variable "email_validation_token" {
  type        = string
  description = "Authentication token for email validation service"
  sensitive   = true
}