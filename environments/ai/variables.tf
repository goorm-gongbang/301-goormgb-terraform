# environments/ai/variables.tf

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment (dev or prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be dev or prod"
  }
}

variable "ai_container_image" {
  description = "AI Control Plane container image"
  type        = string
  default     = "public.ecr.aws/docker/library/python:3.12-slim"
}
