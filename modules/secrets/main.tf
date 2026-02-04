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

#------------------------------------------------------------------------------
# Porkbun DDNS credentials
#------------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "porkbun_ddns" {
  count = var.porkbun_api_key != "" ? 1 : 0

  name        = "${var.name}/porkbun-ddns"
  description = "Porkbun DDNS API credentials"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "porkbun_ddns" {
  count = var.porkbun_api_key != "" ? 1 : 0

  secret_id = aws_secretsmanager_secret.porkbun_ddns[0].id
  secret_string = jsonencode({
    DOMAIN       = var.porkbun_domain
    SUBDOMAINS   = var.porkbun_subdomains
    APIKEY       = var.porkbun_api_key
    SECRETAPIKEY = var.porkbun_secret_key
  })
}

#------------------------------------------------------------------------------
# Google OAuth credentials
#------------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "google_oauth" {
  count = var.google_client_id != "" ? 1 : 0

  name        = "${var.name}/google-oauth"
  description = "Google OAuth client credentials"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "google_oauth" {
  count = var.google_client_id != "" ? 1 : 0

  secret_id = aws_secretsmanager_secret.google_oauth[0].id
  secret_string = jsonencode({
    client_id     = var.google_client_id
    client_secret = var.google_client_secret
  })
}

#------------------------------------------------------------------------------
# ArgoCD configuration
#------------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "argocd" {
  count = length(var.argocd_admin_users) > 0 ? 1 : 0

  name        = "${var.name}/argocd"
  description = "ArgoCD configuration (Google OAuth admin users)"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "argocd" {
  count = length(var.argocd_admin_users) > 0 ? 1 : 0

  secret_id = aws_secretsmanager_secret.argocd[0].id
  secret_string = jsonencode({
    admin_users   = var.argocd_admin_users
    client_id     = var.google_client_id
    client_secret = var.google_client_secret
  })
}
