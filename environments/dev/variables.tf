# === ArgoCD ===
variable "github_ssh_private_key" {
  description = "GitHub SSH private key for ArgoCD"
  type        = string
  sensitive   = true
}

variable "google_oauth_client_id" {
  description = "Google OAuth client ID"
  type        = string
  sensitive   = true
}

variable "google_oauth_client_secret" {
  description = "Google OAuth client secret"
  type        = string
  sensitive   = true
}

# === Monitoring ===
variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

# === Database ===
variable "db_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

# === JWT ===
variable "jwt_secret_key" {
  description = "JWT signing secret key"
  type        = string
  sensitive   = true
}

# === Kakao OAuth ===
variable "kakao_client_id" {
  description = "Kakao OAuth client ID"
  type        = string
  sensitive   = true
}

variable "kakao_client_secret" {
  description = "Kakao OAuth client secret"
  type        = string
  sensitive   = true
}
