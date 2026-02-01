# environments/ai/main.tf
# AI 전용 환경: ECS Fargate Spot
# dev/prod 환경 선택 가능 (terraform apply -var="environment=dev")

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
      Environment = "ai-${var.environment}"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name = "goormgb-ai-${var.environment}"
  tags = {
    Project     = "goormgb"
    Environment = "ai-${var.environment}"
    ManagedBy   = "terraform"
  }
}

#------------------------------------------------------------------------------
# Remote State (prod 인프라 참조)
#------------------------------------------------------------------------------
data "terraform_remote_state" "prod" {
  backend = "s3"

  config = {
    bucket = "goorm-gongbang-tf-state"
    key    = "prod/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

#------------------------------------------------------------------------------
# ECS Cluster (AI 전용)
#------------------------------------------------------------------------------
module "ecs" {
  source = "../../modules/ecs"

  cluster_name       = local.name
  environment        = var.environment
  vpc_id             = data.terraform_remote_state.prod.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.prod.outputs.private_subnet_ids

  container_image = var.ai_container_image
  container_port  = 8000
  task_cpu        = 1024 # 1 vCPU
  task_memory     = 2048 # 2 GB

  # EKS와 통신 허용
  eks_security_group_id = data.terraform_remote_state.prod.outputs.eks_node_security_group_id

  # Secrets Manager에서 시크릿 가져오기
  secrets_arns = data.terraform_remote_state.prod.outputs.secrets_arns
  container_secrets = [
    {
      name       = "DATABASE_URL"
      value_from = "${data.terraform_remote_state.prod.outputs.secrets_arns[0]}:host::"
    },
    {
      name       = "OPENAI_API_KEY"
      value_from = "${data.terraform_remote_state.prod.outputs.secrets_arns[2]}:openai_api_key::"
    }
  ]

  tags = local.tags
}
