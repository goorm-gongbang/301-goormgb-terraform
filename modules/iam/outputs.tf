# iam/outputs.tf
output "groups" {
  description = "생성된 IAM 그룹과 정보"
  value = aws_iam_group.this
}