# =============================================================================
# IAM User: bot-kubeadm (미니피씨 클러스터 전용)
# =============================================================================

resource "aws_iam_user" "kubeadm" {
  name = "bot-kubeadm"
  path = "/system/"

  tags = merge(local.common_tags, {
    Purpose = "kubeadm cluster - S3 backup, DDNS, ECR pull, ESO"
  })
}

resource "aws_iam_access_key" "kubeadm" {
  user = aws_iam_user.kubeadm.name
}

# =============================================================================
# Policies for bot-kubeadm (최소 권한)
# =============================================================================

# 1. S3 백업 버킷 접근 (dev/ prefix만)
resource "aws_iam_policy" "kubeadm_s3_backup" {
  name        = "kubeadm-s3-backup"
  description = "S3 backup bucket access for kubeadm cluster (dev only)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3BackupAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::goormgb-backup/dev/*"
      },
      {
        Sid      = "S3ListBucket"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::goormgb-backup"
        Condition = {
          StringLike = {
            "s3:prefix" = ["dev/*"]
          }
        }
      }
    ]
  })
}

# 2. Route53 DDNS 업데이트 (goormgb.help zone만)
resource "aws_iam_policy" "kubeadm_route53_ddns" {
  name        = "kubeadm-route53-ddns"
  description = "Route53 DDNS update for kubeadm cluster"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Route53RecordUpdate"
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Resource = "arn:aws:route53:::hostedzone/Z08735923FCA9QTFLOQSL"
      },
      {
        Sid    = "Route53ListZones"
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:GetHostedZone"
        ]
        Resource = "*"
      }
    ]
  })
}

# 3. ECR 이미지 풀 (dev 레포만)
resource "aws_iam_policy" "kubeadm_ecr_pull" {
  name        = "kubeadm-ecr-pull"
  description = "ECR pull access for kubeadm cluster (dev only)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "arn:aws:ecr:ap-northeast-2:*:repository/dev/goormgb/*"
      }
    ]
  })
}

# 4. Secrets Manager 읽기 (dev/* 만)
resource "aws_iam_policy" "kubeadm_secrets_read" {
  name        = "kubeadm-secrets-read"
  description = "Secrets Manager read access for ESO in kubeadm cluster (dev only)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:ap-northeast-2:*:secret:dev/*"
      },
      {
        Sid      = "SecretsManagerList"
        Effect   = "Allow"
        Action   = "secretsmanager:ListSecrets"
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# Attach policies to bot-kubeadm
# =============================================================================

resource "aws_iam_user_policy_attachment" "kubeadm_s3" {
  user       = aws_iam_user.kubeadm.name
  policy_arn = aws_iam_policy.kubeadm_s3_backup.arn
}

resource "aws_iam_user_policy_attachment" "kubeadm_route53" {
  user       = aws_iam_user.kubeadm.name
  policy_arn = aws_iam_policy.kubeadm_route53_ddns.arn
}

resource "aws_iam_user_policy_attachment" "kubeadm_ecr" {
  user       = aws_iam_user.kubeadm.name
  policy_arn = aws_iam_policy.kubeadm_ecr_pull.arn
}

resource "aws_iam_user_policy_attachment" "kubeadm_secrets" {
  user       = aws_iam_user.kubeadm.name
  policy_arn = aws_iam_policy.kubeadm_secrets_read.arn
}
