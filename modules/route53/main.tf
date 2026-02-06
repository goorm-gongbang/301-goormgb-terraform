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

# MiniPC IP를 가르키는 레코드 (Cloudfront가 바라볼 원본)
resource "aws_route53_record" "origin_dev" {
  count = var.origin_dev_ip != "" ? 1 : 0

  zone_id = local.zone_id
  name    = "origin-dev.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [var.origin_dev_ip]
}

# 사용자가 접속할 dev 레코드 (Cloudfront를 가르킴)
resource "aws_route53_record" "dev" {
  count = var.dev_cloudfront_domain != "" ? 1 : 0
  name    = "dev.${var.domain_name}"
  type    = "A"
  zone_id = "local.zone_id"

  alias {
    evaluate_target_health = false
    name                   = "var.dev_cloudfront_domain"
    zone_id                = "var.cloudfront_zone_id"
  }
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
