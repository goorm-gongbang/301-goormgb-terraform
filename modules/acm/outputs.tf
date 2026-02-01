# modules/acm/outputs.tf

output "cloudfront_certificate_arn" {
  description = "ACM certificate ARN for CloudFront (us-east-1)"
  value       = aws_acm_certificate.cloudfront.arn
}

output "alb_certificate_arn" {
  description = "ACM certificate ARN for ALB (ap-northeast-2)"
  value       = aws_acm_certificate.alb.arn
}

output "domain_name" {
  description = "Domain name"
  value       = var.domain_name
}
