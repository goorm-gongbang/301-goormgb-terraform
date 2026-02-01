# modules/lambda-mongodb-backup/main.tf

#------------------------------------------------------------------------------
# MongoDB Atlas → S3 Backup Lambda
#------------------------------------------------------------------------------

locals {
  function_name = "${var.name}-mongodb-backup-${var.environment}"
}

# Lambda 실행 역할
resource "aws_iam_role" "lambda" {
  name = "${local.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Lambda 기본 실행 권한
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# S3 쓰기 권한
resource "aws_iam_role_policy" "s3_write" {
  name = "${local.function_name}-s3-write"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:ListBucket"
        ]
        Resource = [
          var.trajectory_bucket_arn,
          "${var.trajectory_bucket_arn}/*",
          var.vqa_data_bucket_arn,
          "${var.vqa_data_bucket_arn}/*"
        ]
      }
    ]
  })
}

# Secrets Manager 읽기 권한
resource "aws_iam_role_policy" "secrets_read" {
  name = "${local.function_name}-secrets-read"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.mongodb_secret_arn
      }
    ]
  })
}

# Lambda 함수
resource "aws_lambda_function" "mongodb_backup" {
  function_name = local.function_name
  role          = aws_iam_role.lambda.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"
  timeout       = 300  # 5분
  memory_size   = 512

  filename         = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path)

  environment {
    variables = {
      MONGODB_SECRET_ARN      = var.mongodb_secret_arn
      TRAJECTORY_BUCKET       = var.trajectory_bucket_id
      VQA_DATA_BUCKET         = var.vqa_data_bucket_id
      ENVIRONMENT             = var.environment
      TRAJECTORY_TTL_DAYS     = var.trajectory_ttl_days
      VQA_TTL_DAYS            = var.vqa_ttl_days
    }
  }

  tags = var.tags
}

# EventBridge 스케줄 (매일 새벽 3시 KST = 18:00 UTC)
resource "aws_cloudwatch_event_rule" "daily_backup" {
  name                = "${local.function_name}-daily"
  description         = "Daily MongoDB backup to S3"
  schedule_expression = "cron(0 18 * * ? *)"  # 매일 03:00 KST

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.daily_backup.name
  target_id = "mongodb-backup"
  arn       = aws_lambda_function.mongodb_backup.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mongodb_backup.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_backup.arn
}

# 백업 실패 알림 (CloudWatch Alarm)
resource "aws_cloudwatch_metric_alarm" "backup_errors" {
  alarm_name          = "${local.function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 86400  # 24시간
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "MongoDB backup Lambda errors"
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    FunctionName = aws_lambda_function.mongodb_backup.function_name
  }

  tags = var.tags
}
