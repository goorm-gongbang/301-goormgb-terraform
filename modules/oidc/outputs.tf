# modules/oidc/outputs.tf

output "role_arn" {
  description = "GitHub Actions에서 사용할 IAM Role ARN"
  value       = aws_iam_role.github_actions.arn
}