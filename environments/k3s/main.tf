terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "goormgb-tf-state-bucket"
    key            = "k3s/secrets.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "goormgb-tf-lock"
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

locals {
  environment = "k3s"
  project     = "goormgb"

  common_tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

# k3s 환경 시크릿 정의
module "secrets" {
  source = "../../modules/secrets"

  environment = local.environment

  secrets = {
    # === ArgoCD ===
    "argocd/github-ssh" = {
      description = "ArgoCD GitHub SSH Key"
      value = {
        sshPrivateKey = var.github_ssh_private_key
      }
    }

    "argocd/google-oauth" = {
      description = "ArgoCD Google OAuth"
      value = {
        clientId     = var.google_oauth_client_id
        clientSecret = var.google_oauth_client_secret
      }
    }

    # === Monitoring ===
    "monitoring/grafana" = {
      description = "Grafana admin credentials"
      value = {
        username = "admin"
        password = var.grafana_admin_password
      }
    }

    # === Backend Services ===
    "services/db" = {
      description = "PostgreSQL database credentials"
      value = {
        url      = "jdbc:postgresql://postgresql.data.svc.cluster.local:5432/goormgb"
        username = "goormgb"
        password = var.db_password
      }
    }

    "services/redis" = {
      description = "Redis connection info"
      value = {
        host = "redis-master.data.svc.cluster.local"
        port = "6379"
      }
    }

    "services/jwt" = {
      description = "JWT configuration"
      value = {
        secretKey              = var.jwt_secret_key
        issuer                 = "goormgb-auth-service"
        accessTokenAudience    = "goormgb-api"
        accessTokenExpiration  = "15"
        refreshTokenAudience   = "goormgb-auth-service"
        refreshTokenExpiration = "7"
      }
    }

    "services/oauth/kakao" = {
      description = "Kakao OAuth credentials"
      value = {
        clientId     = var.kakao_client_id
        clientSecret = var.kakao_client_secret
        redirectUri  = "https://api.goormgb.space/auth/callback/kakao"
      }
    }
  }

  tags = local.common_tags
}
