output "repository_url" {
  description = "생성된 ECR 레포의 URL"
  value = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "생성된 ECR 레포의 ARN"
  value = aws_ecr_repository.this.arn
}