# modules/elasticache/variables.tf

variable "name" {
  description = "ElastiCache cluster name"
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

variable "subnet_group_name" {
  description = "ElastiCache subnet group name"
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
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.r6g.large"
}

variable "num_shards" {
  description = "Number of shards (node groups) for cluster mode"
  type        = number
  default     = 3
}

variable "replicas_per_shard" {
  description = "Number of replicas per shard"
  type        = number
  default     = 1
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for notifications"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
