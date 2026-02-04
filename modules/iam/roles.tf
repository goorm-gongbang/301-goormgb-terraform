# iam/roles.tf
# CI/CD 서비스용 IAM Roles (최소 권한 원칙)

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "goorm-gongbang"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------
# 1. GitHub Actions Role (OIDC)
# -----------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "github_actions" {
  name = "github-actions-role"
  path = "/services/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Organization 전체 허용
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/*:*"
          }
        }
      }
    ]
  })
}

# GitHub Actions 전용 정책
resource "aws_iam_policy" "github_actions" {
  name        = "github-actions-policy"
  description = "Policy for GitHub Actions CI/CD"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR: 이미지 push/pull
      {
        Sid    = "ECRAccess"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ]
        Resource = "*"
      },
      # EKS: 클러스터 접근
      {
        Sid    = "EKSAccess"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/*"
      },
      # S3: Terraform state
      {
        Sid    = "S3TerraformState"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::goormgb-terraform-state",
          "arn:aws:s3:::goormgb-terraform-state/*"
        ]
      },
      # DynamoDB: Terraform lock
      {
        Sid    = "DynamoDBTerraformLock"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/terraform-lock"
      },
      # Secrets Manager: 읽기 전용
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:goormgb/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}

# -----------------------------------------------
# 2. TeamCity Role (EC2 Instance Profile)
# -----------------------------------------------
resource "aws_iam_role" "teamcity" {
  name = "teamcity-role"
  path = "/services/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "teamcity" {
  name = "teamcity-instance-profile"
  role = aws_iam_role.teamcity.name
}

# TeamCity 전용 정책 (GitHub Actions와 동일)
resource "aws_iam_role_policy_attachment" "teamcity" {
  role       = aws_iam_role.teamcity.name
  policy_arn = aws_iam_policy.github_actions.arn
}

# -----------------------------------------------
# 3. ESO Role (External Secrets Operator - IRSA)
# -----------------------------------------------
variable "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN for IRSA"
  type        = string
  default     = ""
}

variable "eks_oidc_provider_url" {
  description = "EKS OIDC provider URL (without https://)"
  type        = string
  default     = ""
}

resource "aws_iam_role" "eso" {
  count = var.eks_oidc_provider_arn != "" ? 1 : 0

  name = "eso-secrets-role"
  path = "/services/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.eks_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.eks_oidc_provider_url}:sub" = "system:serviceaccount:external-secrets:external-secrets"
            "${var.eks_oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# ESO 전용 정책 - Secrets Manager 읽기만
resource "aws_iam_policy" "eso" {
  count = var.eks_oidc_provider_arn != "" ? 1 : 0

  name        = "eso-secrets-policy"
  description = "Policy for External Secrets Operator - Secrets Manager read only"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:goormgb/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eso" {
  count = var.eks_oidc_provider_arn != "" ? 1 : 0

  role       = aws_iam_role.eso[0].name
  policy_arn = aws_iam_policy.eso[0].arn
}

# -----------------------------------------------
# 4. ArgoCD Role (EKS IRSA) - 필요시
# -----------------------------------------------
resource "aws_iam_role" "argocd" {
  count = var.eks_oidc_provider_arn != "" ? 1 : 0

  name = "argocd-role"
  path = "/services/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.eks_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.eks_oidc_provider_url}:sub" = "system:serviceaccount:argocd:argocd-server"
            "${var.eks_oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# ArgoCD 전용 정책 - ECR 읽기 (이미지 pull)
resource "aws_iam_policy" "argocd" {
  count = var.eks_oidc_provider_arn != "" ? 1 : 0

  name        = "argocd-policy"
  description = "Policy for ArgoCD - ECR read only"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRRead"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "argocd" {
  count = var.eks_oidc_provider_arn != "" ? 1 : 0

  role       = aws_iam_role.argocd[0].name
  policy_arn = aws_iam_policy.argocd[0].arn
}
