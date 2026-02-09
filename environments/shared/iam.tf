# -----------------------------------------------
# Cloud Native (CN)
# -----------------------------------------------

resource "aws_iam_group" "cn_admin" {
  name = "CN"
  path = "/users/"
}

#CN은 어드민
resource "aws_iam_group_policy_attachment" "cn_admin_policy" {
  group      = aws_iam_group.cn_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# -----------------------------------------------
# Cyber Security (CS)
# -----------------------------------------------
resource "aws_iam_group" "cs_team" {
  name = "CS"
  path = "/users/"
}

# 1. AWS 관리형: SecurityAudit (여기에 IAM, Config, CloudTrail, GuardDuty 조회 권한 다 있음)
resource "aws_iam_group_policy_attachment" "cs_audit" {
  group      = aws_iam_group.cs_team.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

# 2. 커스텀 정책: SecurityAudit에 빠져 있는 '로그 내용 조회' 권한만 추가
resource "aws_iam_group_policy" "cs_security_ops" {
  name  = "CS-LogDataReading"
  group = aws_iam_group.cs_team.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsDataRead"
        Effect = "Allow"
        Action = [
          # DescribeLogGroups/Streams는 SecurityAudit에 이미 있음
          # 하지만 실제 로그 텍스트를 읽으려면 아래 2개가 필수 (이건 SecurityAudit에 없음)
          "logs:GetLogEvents",
          "logs:FilterLogEvents",

          # 쿼리 실행 결과 조회 (선택 사항, 필요시 추가)
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------
# CICD 리소스
# -----------------------------------------------
resource "aws_iam_group" "cicd_bots" {
  name = "CICD-Bots-Group"
  path = "/system/"
}

resource "aws_iam_user" "teamcity" {
  name = "bot-teamcity"
  path = "/system/"
}

resource "aws_iam_user" "argocd" {
  name = "bot-argocd"
  path = "/system/"
}

resource "aws_iam_group_membership" "cicd_membership" {
  name = "cicd-membership"
  group = aws_iam_group.cicd_bots.name
  users = [
    aws_iam_user.argocd.name,
    aws_iam_user.teamcity.name,
  ]
}

# 추후 권한은 아래처럼 추가
# resource "aws_iam_group_policy_attachment" "cicd_power_user" {
#   group      = aws_iam_group.cicd_bots.name
#   policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
# }

# -----------------------------------------------
# Github Actions OIDC
# -----------------------------------------------
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github_oidc" {
  client_id_list = ["sts.amazonaws.com"]
  url = "https://token.actions.githubusercontent.com"
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = {
    Name = "GitHub-Actions-OIDC"
  }
}