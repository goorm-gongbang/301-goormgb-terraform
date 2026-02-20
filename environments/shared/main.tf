terraform {
  backend "s3" {
    bucket         = "goormgb-tf-state-bucket"
    key            = "shared/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "goormgb-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

module "route53" {
  source = "../../modules/route53_zone"

  domain_name = "goormgb.space"
}

# =============================================================================
# DNS Records
# =============================================================================

# Vercel Frontend (dev.goormgb.space)
resource "aws_route53_record" "dev_frontend" {
  zone_id = module.route53.zone_id
  name    = "dev.goormgb.space"
  type    = "CNAME"
  ttl     = 300
  records = ["3d244415b9bf4a46.vercel-dns-017.com"]
}

# MiniPC API Gateway (api.dev.goormgb.space)
# DDNS로 관리하거나 고정 IP 있으면 A 레코드로 변경
resource "aws_route53_record" "dev_api" {
  zone_id = module.route53.zone_id
  name    = "api.dev.goormgb.space"
  type    = "CNAME"
  ttl     = 300
  records = ["goormgb.space"]  # DDNS가 루트 도메인 업데이트하면 같이 따라감
}