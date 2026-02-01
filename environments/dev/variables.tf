# environments/dev/variables.tf

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "domain_name" {
  description = "Domain name"
  type        = string
  default     = "goormgb.space"
}

variable "dev_minipc_ip" {
  description = "Dev mini PC public IP address"
  type        = string
}
