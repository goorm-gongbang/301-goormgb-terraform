# modules/cloudfront/outputs.tf

output "static_distribution_id" {
  description = "Static files CloudFront distribution ID"
  value       = aws_cloudfront_distribution.static.id
}

output "static_distribution_domain_name" {
  description = "Static files CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.static.domain_name
}

output "api_distribution_id" {
  description = "API CloudFront distribution ID"
  value       = length(aws_cloudfront_distribution.api) > 0 ? aws_cloudfront_distribution.api[0].id : ""
}

output "api_distribution_domain_name" {
  description = "API CloudFront distribution domain name"
  value       = length(aws_cloudfront_distribution.api) > 0 ? aws_cloudfront_distribution.api[0].domain_name : ""
}

output "oac_id" {
  description = "Origin Access Control ID"
  value       = aws_cloudfront_origin_access_control.s3.id
}
