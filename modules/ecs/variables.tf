# modules/ecs/variables.tf

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "environment" {
  description = "Environment (dev or prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be dev or prod"
  }
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "container_image" {
  description = "Container image for AI Control Plane"
  type        = string
  default     = "public.ecr.aws/docker/library/python:3.12-slim"
}

variable "test_container_image" {
  description = "Container image for Test Automation (optional)"
  type        = string
  default     = ""
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 8000
}

variable "task_cpu" {
  description = "Task CPU units"
  type        = number
  default     = 1024 # 1 vCPU
}

variable "task_memory" {
  description = "Task memory in MB"
  type        = number
  default     = 2048 # 2 GB
}

variable "container_secrets" {
  description = "Container secrets from Secrets Manager"
  type = list(object({
    name       = string
    value_from = string
  }))
  default = []
}

variable "secrets_arns" {
  description = "Secrets Manager ARNs for task execution role"
  type        = list(string)
  default     = ["arn:aws:secretsmanager:*:*:secret:*"]
}

variable "alb_security_group_id" {
  description = "ALB security group ID (optional)"
  type        = string
  default     = ""
}

variable "eks_security_group_id" {
  description = "EKS node security group ID for internal communication"
  type        = string
  default     = ""
}

variable "target_group_arn" {
  description = "ALB target group ARN (optional)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
