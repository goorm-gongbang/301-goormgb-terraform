# modules/route53/main.tf

#------------------------------------------------------------------------------
# Hosted Zone (이미 있으면 data로 가져오기)
#------------------------------------------------------------------------------
resource "aws_route53_zone" "this" {
  count = var.create_zone ? 1 : 0

  name    = var.domain_name
  comment = "Managed by Terraform"

  tags = merge(var.tags, {
    Name = var.domain_name
  })
}

data "aws_route53_zone" "this" {
  count = var.create_zone ? 0 : 1

  name         = var.domain_name
  private_zone = false
}

locals {
  zone_id = var.create_zone ? aws_route53_zone.this[0].zone_id : data.aws_route53_zone.this[0].zone_id
}

#------------------------------------------------------------------------------
# Records
#------------------------------------------------------------------------------

# A record for root domain (CloudFront)
resource "aws_route53_record" "root" {
  count = var.cloudfront_domain_name != "" ? 1 : 0

  zone_id = local.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_zone_id
    evaluate_target_health = false
  }
}

# A record for www subdomain
resource "aws_route53_record" "www" {
  count = var.cloudfront_domain_name != "" ? 1 : 0

  zone_id = local.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_zone_id
    evaluate_target_health = false
  }
}

# A record for API subdomain (ALB)
resource "aws_route53_record" "api" {
  count = var.alb_dns_name != "" ? 1 : 0

  zone_id = local.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# A record for dev subdomain
resource "aws_route53_record" "dev" {
  count = var.dev_ip != "" ? 1 : 0

  zone_id = local.zone_id
  name    = "dev.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [var.dev_ip]
}

# CNAME records for monitoring tools
resource "aws_route53_record" "monitoring" {
  for_each = var.monitoring_records

  zone_id = local.zone_id
  name    = "${each.key}.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [each.value]
}
