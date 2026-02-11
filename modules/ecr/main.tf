terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.17.0"
    }
  }
}
resource "aws_ecr_repository" "this" {
  name = var.repository_name
  image_tag_mutability = "IMMUTABLE"
  force_delete = false

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "this" {
  policy     = jsonencode({
    rules = [
      {
        rulePriority = 1
        description = "최근 50개의 이미지만 유지"
        selection = {
          tagStatus = "any"
          countType = "imageCountMoreThan"
          countNumber = 50
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
  repository = aws_ecr_repository.this.name
}