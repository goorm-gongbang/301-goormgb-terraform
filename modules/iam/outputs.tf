# iam/outputs.tf
output "groups" {
  description = "생성된 IAM 그룹과 정보"
  value       = aws_iam_group.this
}

# CI/CD Role ARNs
output "github_actions_role_arn" {
  description = "GitHub Actions IAM Role ARN"
  value       = aws_iam_role.github_actions.arn
}

output "teamcity_role_arn" {
  description = "TeamCity IAM Role ARN"
  value       = aws_iam_role.teamcity.arn
}

output "teamcity_instance_profile_name" {
  description = "TeamCity EC2 Instance Profile name"
  value       = aws_iam_instance_profile.teamcity.name
}

output "argocd_role_arn" {
  description = "ArgoCD IAM Role ARN (IRSA)"
  value       = length(aws_iam_role.argocd) > 0 ? aws_iam_role.argocd[0].arn : null
}