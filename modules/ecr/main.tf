# modules/ecr/main.tf

locals {
  repositories = [
    # Frontend
    "goormgb-frontend",

    # 예상 MSA 5개
    "goormgb-backend-auth",   // 인증 서비스
    "goormgb-backend-queue",  // 대기열 서비스
    "goormgb-backend-seat",   // 좌석 서비스
    "goormgb-backend-order",  // 주문 서비스
    "goormgb-backend-admin",  // 관리자 서비스

    # AI 서비스
    "goormgb-ai-control", // AI Control Plane (Service A)
    "goormgb-ai-test",    // Test Automation (Service B)
  ]
}

resource "aws_ecr_repository" "this" {
  for_each = toset(local.repositories)

  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, {
    Name = each.value
  })
}

# 이미지 수명주기 정책 (비용 절감)
resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 dev images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 prod images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["prod-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Delete untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
