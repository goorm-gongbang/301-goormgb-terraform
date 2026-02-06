terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "goormgb"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

# CloudFront 인증서용 (us-east-1 필수)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  default_tags {
    tags = {
      Project     = "goormgb"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name        = "goormgb"
  environment = "dev"
  domain_name = "dev.${var.domain_name}"
}

# 1. Route53 설정 (모듈 변수 변경 반영)
module "route53" {
  source = "../../modules/route53"

  domain_name = var.domain_name
  create_zone = false

  # MiniPC 실제 IP (origin-dev.goormgb.com)
  origin_dev_ip = var.dev_minipc_ip

  # 사용자 접속 도메인 (dev.goormgb.com) -> CloudFront
  dev_cloudfront_domain = module.cloudfront.static_distribution_domain_name
}

# 2. S3 (프론트엔드 정적 파일)
module "s3" {
  source = "../../modules/s3"
  name        = local.name
  environment = local.environment
}

# 3. ACM (SSL 인증서)
module "acm" {
  source = "../../modules/acm"
  providers = {
    aws.us_east_1 = aws.us_east_1
  }
  domain_name = local.domain_name
  zone_id     = module.route53.zone_id
}

# 4. CloudFront
module "cloudfront" {
  source = "../../modules/cloudfront"

  name                      = "${local.name}-${local.environment}"
  static_bucket_domain_name = module.s3.static_bucket_domain_name
  acm_certificate_arn       = module.acm.cloudfront_certificate_arn

  static_domain             = local.domain_name

  # CloudFront가 데이터를 가져올 곳 (MiniPC)
  alb_domain_name           = "origin-dev.${var.domain_name}"
  origin_protocol_policy    = "https-only" # MiniPC가 HTTPS 지원 시

  depends_on = [module.acm]
}