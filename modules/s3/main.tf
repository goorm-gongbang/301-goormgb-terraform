# modules/s3/main.tf

#------------------------------------------------------------------------------
# S3 Buckets
#------------------------------------------------------------------------------

# Static files bucket (Next.js)
resource "aws_s3_bucket" "static" {
  bucket = "${var.name}-static-${var.environment}"

  tags = merge(var.tags, {
    Name = "${var.name}-static-${var.environment}"
  })
}

resource "aws_s3_bucket_versioning" "static" {
  bucket = aws_s3_bucket.static.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "static" {
  bucket = aws_s3_bucket.static.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Images bucket
resource "aws_s3_bucket" "images" {
  bucket = "${var.name}-images-${var.environment}"

  tags = merge(var.tags, {
    Name = "${var.name}-images-${var.environment}"
  })
}

resource "aws_s3_bucket_versioning" "images" {
  bucket = aws_s3_bucket.images.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "images" {
  bucket = aws_s3_bucket.images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Logs bucket
resource "aws_s3_bucket" "logs" {
  bucket = "${var.name}-logs-${var.environment}"

  tags = merge(var.tags, {
    Name = "${var.name}-logs-${var.environment}"
  })
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Logs lifecycle (prefix별 수명주기 정책)
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  # AI 분석 데이터 (마우스 궤적, 보안 퀴즈) - 30일 보관
  # dev/prod 같이 저장, JSON 내 env 필드로 구분
  rule {
    id     = "ai-data-expiration"
    status = "Enabled"

    filter {
      prefix = "ai-data/"
    }

    expiration {
      days = 30
    }
  }

  # 인프라 운영 로그 (Istio, K8s, Loki) - 3일 보관
  # 이슈 발생 즉시 해결하지 않으면 의미 없음, 용량 차지 방지
  rule {
    id     = "infra-dev-expiration"
    status = "Enabled"

    filter {
      prefix = "infra/dev/"
    }

    expiration {
      days = 3
    }
  }

  rule {
    id     = "infra-prod-expiration"
    status = "Enabled"

    filter {
      prefix = "infra/prod/"
    }

    expiration {
      days = 3
    }
  }

  # 서비스 관제 로그 (웹/FastAPI APM) - 14일 보관
  # 시나리오 테스트, 버그 리포트 확인용
  rule {
    id     = "web-dev-expiration"
    status = "Enabled"

    filter {
      prefix = "web/dev/"
    }

    expiration {
      days = 14
    }
  }

  rule {
    id     = "web-prod-expiration"
    status = "Enabled"

    filter {
      prefix = "web/prod/"
    }

    expiration {
      days = 14
    }
  }
}

# Backup bucket
resource "aws_s3_bucket" "backup" {
  bucket = "${var.name}-backup-${var.environment}"

  tags = merge(var.tags, {
    Name = "${var.name}-backup-${var.environment}"
  })
}

resource "aws_s3_bucket_versioning" "backup" {
  bucket = aws_s3_bucket.backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "backup" {
  bucket = aws_s3_bucket.backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

#------------------------------------------------------------------------------
# AI Data Buckets (MongoDB Archive + VQA)
#------------------------------------------------------------------------------

# AI Trajectory Archive (MongoDB 궤적 데이터 백업)
resource "aws_s3_bucket" "ai_trajectory" {
  bucket = "${var.name}-ai-trajectory-${var.environment}"

  tags = merge(var.tags, {
    Name    = "${var.name}-ai-trajectory-${var.environment}"
    Purpose = "MongoDB trajectory data archive"
  })
}

resource "aws_s3_bucket_versioning" "ai_trajectory" {
  bucket = aws_s3_bucket.ai_trajectory.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "ai_trajectory" {
  bucket = aws_s3_bucket.ai_trajectory.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Trajectory lifecycle (Glacier IR로 저렴하게 보관)
resource "aws_s3_bucket_lifecycle_configuration" "ai_trajectory" {
  bucket = aws_s3_bucket.ai_trajectory.id

  rule {
    id     = "transition-to-glacier-ir"
    status = "Enabled"

    # 7일 후 Glacier Instant Retrieval (저렴하지만 즉시 조회 가능)
    transition {
      days          = 7
      storage_class = "GLACIER_IR"
    }

    # 1년 후 Deep Archive (최저 비용)
    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    # 3년 후 삭제 (필요시 조정)
    expiration {
      days = 1095
    }
  }
}

# AI VQA Quiz Data (MongoDB VQA 퀴즈 데이터 백업)
resource "aws_s3_bucket" "ai_vqa_data" {
  bucket = "${var.name}-ai-vqa-data-${var.environment}"

  tags = merge(var.tags, {
    Name    = "${var.name}-ai-vqa-data-${var.environment}"
    Purpose = "MongoDB VQA quiz data archive"
  })
}

resource "aws_s3_bucket_versioning" "ai_vqa_data" {
  bucket = aws_s3_bucket.ai_vqa_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "ai_vqa_data" {
  bucket = aws_s3_bucket.ai_vqa_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# VQA Data lifecycle (자주 조회할 수 있으므로 Standard-IA)
resource "aws_s3_bucket_lifecycle_configuration" "ai_vqa_data" {
  bucket = aws_s3_bucket.ai_vqa_data.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    # 30일 후 Standard-IA (자주 조회 가능)
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # 180일 후 Glacier IR
    transition {
      days          = 180
      storage_class = "GLACIER_IR"
    }
  }
}

# AI VQA Images (VQA 퀴즈용 이미지)
resource "aws_s3_bucket" "ai_vqa_images" {
  bucket = "${var.name}-ai-vqa-images-${var.environment}"

  tags = merge(var.tags, {
    Name    = "${var.name}-ai-vqa-images-${var.environment}"
    Purpose = "VQA quiz images"
  })
}

resource "aws_s3_bucket_versioning" "ai_vqa_images" {
  bucket = aws_s3_bucket.ai_vqa_images.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "ai_vqa_images" {
  bucket = aws_s3_bucket.ai_vqa_images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# VQA Images CORS (필요시 프론트엔드에서 직접 업로드)
resource "aws_s3_bucket_cors_configuration" "ai_vqa_images" {
  bucket = aws_s3_bucket.ai_vqa_images.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }
}
