# modules/rds/variables.tf

variable "name" {
  description = "RDS instance name"
  type        = string
}

variable "environment" {
  description = "Environment (dev or prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "db_subnet_group_name" {
  description = "DB subnet group name"
  type        = string
}

variable "eks_security_group_id" {
  description = "EKS node security group ID"
  type        = string
  default     = ""
}

variable "ecs_security_group_id" {
  description = "ECS tasks security group ID"
  type        = string
  default     = ""
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "instance_class" {
  description = "RDS instance class (Graviton recommended)"
  type        = string
  default     = "db.t4g.medium"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Max allocated storage in GB (autoscaling)"
  type        = number
  default     = 100
}

variable "database_name" {
  description = "Initial database name"
  type        = string
  default     = "goormgb"
}

variable "master_username" {
  description = "Master username"
  type        = string
  default     = "postgres"
}

variable "master_password" {
  description = "Master password"
  type        = string
  sensitive   = true
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
