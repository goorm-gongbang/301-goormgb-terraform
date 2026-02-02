# environments/prod/main.tf
# Prod 환경: 전체 인프라

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
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

# CloudFront 인증서용 (us-east-1)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "goormgb"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name         = "goormgb"
  cluster_name = "goormgb-prod"
  tags = {
    Project     = "goormgb"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

#------------------------------------------------------------------------------
# VPC
#------------------------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  name              = local.name
  vpc_cidr          = var.vpc_cidr
  cluster_name      = local.cluster_name
  admin_cidr_blocks = var.admin_cidr_blocks

  tags = local.tags
}

#------------------------------------------------------------------------------
# EKS
#------------------------------------------------------------------------------
module "eks" {
  source = "../../modules/eks"

  cluster_name       = local.cluster_name
  cluster_version    = var.eks_cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  tags = local.tags
}

#------------------------------------------------------------------------------
# RDS
#------------------------------------------------------------------------------
module "rds" {
  source = "../../modules/rds"

  name                  = "${local.name}-prod"
  environment           = "prod"
  vpc_id                = module.vpc.vpc_id
  db_subnet_group_name  = module.vpc.db_subnet_group_name
  eks_security_group_id = module.eks.node_security_group_id

  # Graviton + Multi-AZ (고가용성)
  instance_class  = "db.t4g.medium"
  multi_az        = true
  master_password = var.db_password

  tags = local.tags
}

#------------------------------------------------------------------------------
# ElastiCache (Redis)
#------------------------------------------------------------------------------
module "elasticache" {
  source = "../../modules/elasticache"

  name                  = "${local.name}-prod"
  environment           = "prod"
  vpc_id                = module.vpc.vpc_id
  subnet_group_name     = module.vpc.elasticache_subnet_group_name
  eks_security_group_id = module.eks.node_security_group_id

  # 티켓팅 대기열용 클러스터
  node_type          = var.redis_node_type
  num_shards         = var.redis_num_shards
  replicas_per_shard = var.redis_replicas_per_shard

  tags = local.tags
}

#------------------------------------------------------------------------------
# S3
#------------------------------------------------------------------------------
module "s3" {
  source = "../../modules/s3"

  name        = local.name
  environment = "prod"

  tags = local.tags
}

#------------------------------------------------------------------------------
# Route53
#------------------------------------------------------------------------------
module "route53" {
  source = "../../modules/route53"

  domain_name = var.domain_name
  create_zone = var.create_route53_zone

  tags = local.tags
}

#------------------------------------------------------------------------------
# ACM
#------------------------------------------------------------------------------
module "acm" {
  source = "../../modules/acm"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  domain_name = var.domain_name
  zone_id     = module.route53.zone_id

  tags = local.tags
}

#------------------------------------------------------------------------------
# CloudFront
#------------------------------------------------------------------------------
module "cloudfront" {
  source = "../../modules/cloudfront"

  name                      = local.name
  static_bucket_domain_name = module.s3.static_bucket_domain_name
  acm_certificate_arn       = module.acm.cloudfront_certificate_arn
  static_domain             = var.domain_name

  tags = local.tags

  depends_on = [module.acm]
}

#------------------------------------------------------------------------------
# Secrets
#------------------------------------------------------------------------------
module "secrets" {
  source = "../../modules/secrets"

  name        = "${local.name}-prod"
  db_username = "postgres"
  db_password = var.db_password
  db_host     = module.rds.address
  db_port     = module.rds.port
  db_name     = module.rds.database_name
  redis_host  = module.elasticache.configuration_endpoint
  redis_port  = 6379

  openai_api_key     = var.openai_api_key
  openrouter_api_key = var.openrouter_api_key
  jwt_secret         = var.jwt_secret

  tags = local.tags
}
