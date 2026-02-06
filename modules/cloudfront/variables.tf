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

# Cloudfront가 원본(MiniPC)에 접속할 때 HTTP/HTTPS중 무엇을 쓸지 선택할 수 있게하는 변수
variable "origin_protocol_policy" {
  description = "Origin(MiniPC/ALB) 접속 프로토콜 (http-only, https-only 등"
  type = string
  default = "https-only"
}
