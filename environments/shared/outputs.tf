output "backend_bucket" {
  value = module.backend.s3_bucket_id
}

output "backend_dynamodb" {
  value = module.backend.dynamodb_table_name
}

output "route53_zone_id" {
  description = "dev/staging에서 사용할 Zone ID"
  value       = module.route53.zone_id
}

output "route53_name_servers" {
  description = "도메인 구입처에 등록할 네임서버"
  value       = module.route53.name_servers
}