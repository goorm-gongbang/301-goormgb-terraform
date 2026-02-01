# environments/dev/outputs.tf

output "dev_domain" {
  description = "Dev environment domain"
  value       = "dev.${var.domain_name}"
}

output "zone_id" {
  description = "Route53 zone ID"
  value       = module.route53.zone_id
}
