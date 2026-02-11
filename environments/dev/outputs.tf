output "ecr_urls" {
  description = "서비스별 ECR 레포의 URL 목록"
  value = {for k, v in module.ecr_services : k => v.repository_url}
}