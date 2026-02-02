# modules/iam/roles.tf
# CI/CD 서비스용 IAM Roles
# (GitHub Actions OIDC 관련 설정은 modules/oidc 모듈로 이동되었습니다.)

data "aws_caller_identity" "current" {}

# -----------------------------------------------
# 1. TeamCity Role (EC2 Instance Profile)
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

resource "aws_iam_role_policy_attachment" "teamcity" {
  role       = aws_iam_role.teamcity.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# -----------------------------------------------
# 2. ArgoCD Role (EKS IRSA)
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

resource "aws_iam_role_policy_attachment" "argocd" {
  count = var.eks_oidc_provider_arn != "" ? 1 : 0

  role       = aws_iam_role.argocd[0].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}