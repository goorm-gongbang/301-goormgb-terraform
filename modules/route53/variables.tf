# modules/route53/variables.tf

variable "domain_name" {
  description = "Domain name"
  type        = string
}

variable "create_zone" {
  description = "Create new hosted zone or use existing"
  type        = bool
  default     = true
}

variable "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  type        = string
  default     = ""
}

variable "cloudfront_zone_id" {
  description = "CloudFront hosted zone ID (always Z2FDTNDATAQYW2)"
  type        = string
  default     = "Z2FDTNDATAQYW2"
}

variable "alb_dns_name" {
  description = "ALB DNS name"
  type        = string
  default     = ""
}

variable "alb_zone_id" {
  description = "ALB hosted zone ID"
  type        = string
  default     = ""
}

variable "dev_ip" {
  description = "Dev environment IP address"
  type        = string
  default     = ""
}

variable "monitoring_records" {
  description = "CNAME records for monitoring tools"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
