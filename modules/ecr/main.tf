# modules/ecr/main.tf

locals {
  repositories = [
    # Frontend
    "goormgb-frontend",

    # Backend MSA 5개 (포트 순서)
    "goormgb-backend-auth-guard",    # :8080 - OAuth2/JWT 인증, Bot 탐지, IP 블랙리스트
    "goormgb-backend-queue",         # :8081 - 대기열 진입, 순번 관리, Admission Token 발급
    "goormgb-backend-seat",          # :8082 - 좌석맵, 좌석 Hold, Hold Token 발급
    "goormgb-backend-order-core",    # :8083 - 주문/결제, 티켓 가격, 마이페이지
    "goormgb-backend-recommendation", # :8084 - 가용 좌석 기반 추천 로직

    # AI 서비스
    "goormgb-ai-control", # AI Control Plane (Service A)
    "goormgb-ai-test",    # Test Automation (Service B)
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
