terraform {
  backend "s3" {
    bucket = "goormgb-tf-state-bucket"
    key = "dev/terraform.tfstate"
    region = "ap-northeast-2"
    dynamodb_table = "goormgb-tf-lock"
    encrypt = true
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

locals {
  environments = "dev"
  project = "goormgb"

  services = [
    "auth-guard",
    "order-core",
    "queue",
    "recommendation",
    "seat"
  ]
}

module "ecr_services" {
  source = "../../modules/ecr"

  for_each = toset(local.services)

  # 네이밍 규칙: 환경/프로젝트/서비스명 (ex: dev/goormgb/auth-guard)
  repository_name = "${local.environments}/${local.project}/${each.key}"

  tags = {
    Environment = local.environments
    Project = local.project
    Service = each.key
    ManagedBy = "Terraform"
  }
}