# modules/secrets/variables.tf

variable "name" {
  description = "Project name prefix"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = ""
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_host" {
  description = "Database host"
  type        = string
  default     = ""
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = ""
}

variable "redis_host" {
  description = "Redis host"
  type        = string
  default     = ""
}

variable "redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

variable "openai_api_key" {
  description = "OpenAI API key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "openrouter_api_key" {
  description = "OpenRouter API key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "jwt_secret" {
  description = "JWT secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# Porkbun DDNS
#------------------------------------------------------------------------------
variable "porkbun_domain" {
  description = "Porkbun domain"
  type        = string
  default     = "goormgb.space"
}

variable "porkbun_subdomains" {
  description = "Porkbun subdomains"
  type        = string
  default     = "@,*"
}

variable "porkbun_api_key" {
  description = "Porkbun API key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "porkbun_secret_key" {
  description = "Porkbun secret API key"
  type        = string
  sensitive   = true
  default     = ""
}

#------------------------------------------------------------------------------
# Google OAuth
#------------------------------------------------------------------------------
variable "google_client_id" {
  description = "Google OAuth client ID"
  type        = string
  default     = ""
}

variable "google_client_secret" {
  description = "Google OAuth client secret"
  type        = string
  sensitive   = true
  default     = ""
}

#------------------------------------------------------------------------------
# ArgoCD
#------------------------------------------------------------------------------
variable "argocd_admin_users" {
  description = "List of Gmail addresses for ArgoCD admin access"
  type        = list(string)
  default     = []
}
