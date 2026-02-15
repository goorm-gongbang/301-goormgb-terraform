# AWS Secrets Manager 모듈
# 환경별 시크릿 관리

# Secret 생성
resource "aws_secretsmanager_secret" "this" {
  for_each = var.secrets

  name        = "${var.environment}/${each.key}"
  description = each.value.description

  tags = merge(var.tags, {
    Name        = "${var.environment}/${each.key}"
    Environment = var.environment
  })
}

# Secret 값 설정 (초기값)
resource "aws_secretsmanager_secret_version" "this" {
  for_each = var.secrets

  secret_id     = aws_secretsmanager_secret.this[each.key].id
  secret_string = jsonencode(each.value.value)
}
