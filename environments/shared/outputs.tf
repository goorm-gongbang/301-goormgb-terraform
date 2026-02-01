# environments/shared/outputs.tf

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
}

output "ecr_registry_id" {
  description = "ECR registry ID"
  value       = module.ecr.registry_id
}

output "iam_groups" {
  description = "IAM groups"
  value       = module.iam.groups
}
