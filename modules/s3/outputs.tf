# modules/s3/outputs.tf

output "static_bucket_id" {
  description = "Static files bucket ID"
  value       = aws_s3_bucket.static.id
}

output "static_bucket_arn" {
  description = "Static files bucket ARN"
  value       = aws_s3_bucket.static.arn
}

output "static_bucket_domain_name" {
  description = "Static files bucket domain name"
  value       = aws_s3_bucket.static.bucket_regional_domain_name
}

output "images_bucket_id" {
  description = "Images bucket ID"
  value       = aws_s3_bucket.images.id
}

output "images_bucket_arn" {
  description = "Images bucket ARN"
  value       = aws_s3_bucket.images.arn
}

output "logs_bucket_id" {
  description = "Logs bucket ID"
  value       = aws_s3_bucket.logs.id
}

output "logs_bucket_arn" {
  description = "Logs bucket ARN"
  value       = aws_s3_bucket.logs.arn
}

output "backup_bucket_id" {
  description = "Backup bucket ID"
  value       = aws_s3_bucket.backup.id
}

output "backup_bucket_arn" {
  description = "Backup bucket ARN"
  value       = aws_s3_bucket.backup.arn
}
