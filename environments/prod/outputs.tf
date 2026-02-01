# environments/prod/outputs.tf

# VPC
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

# EKS
output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_node_security_group_id" {
  description = "EKS node security group ID"
  value       = module.eks.node_security_group_id
}

output "karpenter_controller_role_arn" {
  description = "Karpenter controller IAM role ARN"
  value       = module.eks.karpenter_controller_role_arn
}

# Database
output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.endpoint
}

output "redis_endpoint" {
  description = "Redis configuration endpoint"
  value       = module.elasticache.configuration_endpoint
}

# S3
output "static_bucket_id" {
  description = "Static files S3 bucket ID"
  value       = module.s3.static_bucket_id
}

# CloudFront
output "cloudfront_distribution_domain" {
  description = "CloudFront distribution domain"
  value       = module.cloudfront.static_distribution_domain_name
}

# DNS
output "domain_name" {
  description = "Domain name"
  value       = var.domain_name
}

output "route53_zone_id" {
  description = "Route53 zone ID"
  value       = module.route53.zone_id
}

# Secrets
output "secrets_arns" {
  description = "Secrets Manager ARNs"
  value       = module.secrets.all_secret_arns
}
