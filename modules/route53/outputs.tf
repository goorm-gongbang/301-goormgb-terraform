# modules/route53/outputs.tf

output "zone_id" {
  description = "Route53 hosted zone ID"
  value       = local.zone_id
}

output "name_servers" {
  description = "Route53 name servers"
  value       = var.create_zone ? aws_route53_zone.this[0].name_servers : data.aws_route53_zone.this[0].name_servers
}

output "domain_name" {
  description = "Domain name"
  value       = var.domain_name
}
