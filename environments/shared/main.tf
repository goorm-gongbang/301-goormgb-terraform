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

# ... (기존 ECR, IAM 모듈 부분 유지) ...

# [이동됨] Github Actions OIDC
module "oidc" {
  source      = "../../modules/oidc"
  github_repo = "goorm-gongbang/301-goormgb-terraform"
}

# [이동됨] Terraform State Lock
resource "aws_dynamodb_table" "terraform_lock" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform Lock Table"
  }
}
