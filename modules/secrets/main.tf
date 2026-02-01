# modules/secrets/main.tf

#------------------------------------------------------------------------------
# Secrets Manager Secrets
#------------------------------------------------------------------------------

# Database credentials
resource "aws_secretsmanager_secret" "db" {
  name        = "${var.name}/db-credentials"
  description = "Database credentials for ${var.name}"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = var.db_host
    port     = var.db_port
    database = var.db_name
  })
}

# Redis credentials
resource "aws_secretsmanager_secret" "redis" {
  name        = "${var.name}/redis-credentials"
  description = "Redis credentials for ${var.name}"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "redis" {
  secret_id = aws_secretsmanager_secret.redis.id
  secret_string = jsonencode({
    host = var.redis_host
    port = var.redis_port
  })
}

# AI API Keys
resource "aws_secretsmanager_secret" "ai_api" {
  name        = "${var.name}/ai-api-keys"
  description = "AI API keys for ${var.name}"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "ai_api" {
  secret_id = aws_secretsmanager_secret.ai_api.id
  secret_string = jsonencode({
    openai_api_key     = var.openai_api_key
    openrouter_api_key = var.openrouter_api_key
  })
}

# Application secrets
resource "aws_secretsmanager_secret" "app" {
  name        = "${var.name}/app-secrets"
  description = "Application secrets for ${var.name}"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    jwt_secret = var.jwt_secret
  })
}
