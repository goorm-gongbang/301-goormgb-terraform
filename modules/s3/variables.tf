# modules/s3/variables.tf

variable "name" {
  description = "Project name prefix for buckets"
  type        = string
}

variable "environment" {
  description = "Environment (dev or prod)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "cors_allowed_origins" {
  description = "Allowed origins for CORS (VQA images bucket)"
  type        = list(string)
  default     = ["*"]
}
