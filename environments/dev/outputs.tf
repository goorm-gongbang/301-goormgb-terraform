# ECR
output "ecr_urls" {
  description = "서비스별 ECR 레포의 URL 목록"
  value = { for k, v in module.ecr_services : k => v.repository_url }
}

# Secrets
output "secret_arns" {
  description = "생성된 시크릿 ARN"
  value       = module.secrets.secret_arns
}

output "secret_names" {
  description = "생성된 시크릿 이름"
  value       = module.secrets.secret_names
}
