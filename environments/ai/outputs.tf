# environments/ai/outputs.tf

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.service_name
}

output "ecs_security_group_id" {
  description = "ECS tasks security group ID"
  value       = module.ecs.security_group_id
}

output "environment" {
  description = "Deployed environment"
  value       = var.environment
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = module.ecs.log_group_name
}

# CI/CD에서 사용할 정보
output "task_definition_arn" {
  description = "Task definition ARN (for GitHub Actions)"
  value       = module.ecs.task_definition_arn
}
