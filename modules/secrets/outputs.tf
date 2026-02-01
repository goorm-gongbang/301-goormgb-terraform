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

output "all_secret_arns" {
  description = "All secret ARNs"
  value = [
    aws_secretsmanager_secret.db.arn,
    aws_secretsmanager_secret.redis.arn,
    aws_secretsmanager_secret.ai_api.arn,
    aws_secretsmanager_secret.app.arn,
  ]
}
