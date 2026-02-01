# environments/shared/main.tf
# 공통 리소스: ECR, IAM

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
      Environment = "shared"
      ManagedBy   = "terraform"
    }
  }
}

#------------------------------------------------------------------------------
# ECR Repositories
#------------------------------------------------------------------------------
module "ecr" {
  source = "../../modules/ecr"

  tags = {
    Project   = "goormgb"
    ManagedBy = "terraform"
  }
}

#------------------------------------------------------------------------------
# IAM (기존 모듈 사용)
#------------------------------------------------------------------------------
module "iam" {
  source = "../../modules/iam"
}
