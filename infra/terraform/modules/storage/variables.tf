variable "prefix" {
  description = "Prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "email_processor_role_arn" {
  description = "ARN of the email processor IAM role"
  type        = string
}