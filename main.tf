terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.17.0"
    }
  }
}
# main.tf
module "iam" {
  source = "./modules/iam"
}

module "oidc" {
  source = "./modules/oidc"

  github_repo = "goorm-gongbang/301-goormgb-terraform"
}

# Terraform 상태 잠금용 DynamoDB 모듈화 안하고 그냥 일단 이렇게 추가하는걸로
resource "aws_dynamodb_table" "terraform_lock" {
  name = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform Lock Table"
  }
}