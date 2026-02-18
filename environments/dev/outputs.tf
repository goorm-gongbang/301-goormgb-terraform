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

# IAM - kubeadm cluster
output "kubeadm_user_name" {
  description = "kubeadm 클러스터용 IAM User"
  value       = aws_iam_user.kubeadm.name
}

output "kubeadm_access_key_id" {
  description = "kubeadm 클러스터용 AWS Access Key ID (Secrets Manager에 자동 저장됨)"
  value       = aws_iam_access_key.kubeadm.id
  sensitive   = true
}
