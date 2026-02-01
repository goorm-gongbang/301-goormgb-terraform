# environments/dev/main.tf
# Dev 환경: Route53 레코드만 (미니PC k3s 연결)

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

#------------------------------------------------------------------------------
# Route53 - Dev 레코드
#------------------------------------------------------------------------------
module "route53" {
  source = "../../modules/route53"

  domain_name = var.domain_name
  create_zone = false # 이미 존재하는 zone 사용

  # 미니PC IP로 dev 서브도메인 연결
  dev_ip = var.dev_minipc_ip

  tags = {
    Project     = "goormgb"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
