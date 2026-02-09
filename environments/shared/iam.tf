# CS 그룹 권한
resource "aws_iam_group" "cs_team" {
  name = "CS"
  path = "/users/"
}

resource "aws_iam_group_policy_attachment" "cs_audit" {
  group      = aws_iam_group.cs_team.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

# CICD 관련 리소스
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
  group = "aws_iam_group.cicd_bots.name"
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

# Github Actions OIDC
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