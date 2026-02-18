output "route53_zone_id" {
  description = "dev/staging에서 사용할 Zone ID"
  value       = module.route53.zone_id
}

output "github_oidc_arn" {
  description = "GitHub Actions OIDC Provider ARN (나중에 Role 만들 때 필요)"
  value       = aws_iam_openid_connect_provider.github_oidc.arn
}

output "cicd_user_names" {
  description = "생성된 CI/CD 봇 사용자 이름들"
  value = {
    teamcity = aws_iam_user.teamcity.name
    argocd   = aws_iam_user.argocd.name
  }
}

# =============================================================================
# S3 Backup
# =============================================================================

output "backup_bucket_name" {
  description = "S3 백업 버킷 이름"
  value       = aws_s3_bucket.backup.id
}

output "backup_bucket_arn" {
  description = "S3 백업 버킷 ARN"
  value       = aws_s3_bucket.backup.arn
}

output "backup_bucket_name" {
  description = "S3 백업 버킷 이름"
  value       = aws_s3_bucket.backup.id
}