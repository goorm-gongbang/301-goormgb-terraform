output "secret_arns" {
  description = "생성된 시크릿 ARN 맵"
  value = {
    for k, v in aws_secretsmanager_secret.this : k => v.arn
  }
}

output "secret_names" {
  description = "생성된 시크릿 이름 맵"
  value = {
    for k, v in aws_secretsmanager_secret.this : k => v.name
  }
}
