# modules/cloudfront/variables.tf

variable "name" {
  description = "Project name"
  type        = string
}

variable "static_bucket_domain_name" {
  description = "S3 bucket regional domain name for static files"
  type        = string
}

variable "alb_domain_name" {
  description = "ALB domain name for API origin"
  type        = string
  default     = ""
}

variable "static_domain" {
  description = "Custom domain for static CDN"
  type        = string
  default     = ""
}

variable "api_domain" {
  description = "Custom domain for API CDN"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN (must be in us-east-1)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
