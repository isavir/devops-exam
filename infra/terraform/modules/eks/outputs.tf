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

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if enabled"
  value       = module.eks.oidc_provider_arn
}

# Kubernetes Namespace
output "email_services_namespace" {
  description = "Name of the email services namespace"
  value       = kubernetes_namespace.email_services.metadata[0].name
}

# IAM Role ARNs for other modules
output "email_validation_service_role_arn" {
  description = "ARN of the IAM role for email validation service"
  value       = aws_iam_role.email_validation_service_role.arn
}

output "email_processor_service_role_arn" {
  description = "ARN of the IAM role for email processor service"
  value       = aws_iam_role.email_processor_service_role.arn
}