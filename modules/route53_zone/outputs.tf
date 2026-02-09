output "zone_id" {
  value = aws_route53_zone.this.zone_id
}

output "name" {
  value = aws_route53_zone.this.name
}

output "name_server" {
  value = aws_route53_zone.this.name_servers
}