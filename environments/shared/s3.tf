# =============================================================================
# S3 Backup Bucket (kubeadm 클러스터 백업용)
# =============================================================================

resource "aws_s3_bucket" "backup" {
  bucket = "goormgb-backup"

  tags = {
    Name        = "goormgb-backup"
    Environment = "shared"
    Purpose     = "kubeadm cluster backup (postgres, redis, logs)"
  }
}

# 버전 관리 활성화 (실수로 덮어쓰기 방지)
resource "aws_s3_bucket_versioning" "backup" {
  bucket = aws_s3_bucket.backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 암호화 설정
resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Public access 차단
resource "aws_s3_bucket_public_access_block" "backup" {
  bucket = aws_s3_bucket.backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# =============================================================================
# Lifecycle 정책 (환경별 + 타입별로 다르게 설정)
# =============================================================================

resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  # ===== DEV 환경 (kubeadm) - PostgreSQL만 백업 =====

  rule {
    id     = "dev-postgres"
    status = "Enabled"
    filter { prefix = "dev/postgres/" }
    transition {
      days          = 7
      storage_class = "GLACIER"
    }
    expiration { days = 30 }
    noncurrent_version_expiration { noncurrent_days = 7 }
  }

  # ===== PROD 환경 (EKS) - 긴 retention, Glacier 사용 =====

  rule {
    id     = "prod-postgres"
    status = "Enabled"
    filter { prefix = "prod/postgres/" }
    transition {
      days          = 30
      storage_class = "GLACIER"
    }
    expiration { days = 365 }
    noncurrent_version_expiration { noncurrent_days = 30 }
  }

  rule {
    id     = "prod-redis"
    status = "Enabled"
    filter { prefix = "prod/redis/" }
    expiration { days = 30 }
    noncurrent_version_expiration { noncurrent_days = 7 }
  }

  rule {
    id     = "prod-logs"
    status = "Enabled"
    filter { prefix = "prod/logs/" }
    transition {
      days          = 30
      storage_class = "GLACIER"
    }
    expiration { days = 90 }
    noncurrent_version_expiration { noncurrent_days = 14 }
  }
}

