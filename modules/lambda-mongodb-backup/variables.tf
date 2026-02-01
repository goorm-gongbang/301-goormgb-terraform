# modules/lambda-mongodb-backup/variables.tf

variable "name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Environment (dev or prod)"
  type        = string
}

variable "lambda_zip_path" {
  description = "Path to Lambda deployment package (ZIP)"
  type        = string
}

variable "mongodb_secret_arn" {
  description = "ARN of Secrets Manager secret containing MongoDB URI"
  type        = string
}

variable "trajectory_bucket_id" {
  description = "S3 bucket ID for trajectory data archive"
  type        = string
}

variable "trajectory_bucket_arn" {
  description = "S3 bucket ARN for trajectory data archive"
  type        = string
}

variable "vqa_data_bucket_id" {
  description = "S3 bucket ID for VQA data archive"
  type        = string
}

variable "vqa_data_bucket_arn" {
  description = "S3 bucket ARN for VQA data archive"
  type        = string
}

variable "trajectory_ttl_days" {
  description = "Days before trajectory data TTL expires (backup before this)"
  type        = number
  default     = 7
}

variable "vqa_ttl_days" {
  description = "Days before VQA data TTL expires (backup before this)"
  type        = number
  default     = 30
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for backup failure alerts (optional)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
