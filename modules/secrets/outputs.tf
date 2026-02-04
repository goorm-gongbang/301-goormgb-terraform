# modules/secrets/outputs.tf

output "db_secret_arn" {
  description = "Database secret ARN"
  value       = aws_secretsmanager_secret.db.arn
}

output "redis_secret_arn" {
  description = "Redis secret ARN"
  value       = aws_secretsmanager_secret.redis.arn
}

output "ai_api_secret_arn" {
  description = "AI API keys secret ARN"
  value       = aws_secretsmanager_secret.ai_api.arn
}

output "app_secret_arn" {
  description = "Application secret ARN"
  value       = aws_secretsmanager_secret.app.arn
}

output "porkbun_ddns_secret_arn" {
  description = "Porkbun DDNS secret ARN"
  value       = length(aws_secretsmanager_secret.porkbun_ddns) > 0 ? aws_secretsmanager_secret.porkbun_ddns[0].arn : null
}

output "google_oauth_secret_arn" {
  description = "Google OAuth secret ARN"
  value       = length(aws_secretsmanager_secret.google_oauth) > 0 ? aws_secretsmanager_secret.google_oauth[0].arn : null
}

output "argocd_secret_arn" {
  description = "ArgoCD secret ARN"
  value       = length(aws_secretsmanager_secret.argocd) > 0 ? aws_secretsmanager_secret.argocd[0].arn : null
}

output "all_secret_arns" {
  description = "All secret ARNs"
  value = concat(
    [
      aws_secretsmanager_secret.db.arn,
      aws_secretsmanager_secret.redis.arn,
      aws_secretsmanager_secret.ai_api.arn,
      aws_secretsmanager_secret.app.arn,
    ],
    length(aws_secretsmanager_secret.porkbun_ddns) > 0 ? [aws_secretsmanager_secret.porkbun_ddns[0].arn] : [],
    length(aws_secretsmanager_secret.google_oauth) > 0 ? [aws_secretsmanager_secret.google_oauth[0].arn] : [],
    length(aws_secretsmanager_secret.argocd) > 0 ? [aws_secretsmanager_secret.argocd[0].arn] : [],
  )
}
