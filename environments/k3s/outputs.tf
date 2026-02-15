output "secret_arns" {
  description = "생성된 시크릿 ARN"
  value       = module.secrets.secret_arns
}

output "secret_names" {
  description = "생성된 시크릿 이름"
  value       = module.secrets.secret_names
}
