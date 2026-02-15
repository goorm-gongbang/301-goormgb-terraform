variable "environment" {
  description = "환경 이름 (k3s, eks-dev, eks-prod 등)"
  type        = string
}

variable "secrets" {
  description = "생성할 시크릿 맵"
  type = map(object({
    description = string
    value       = map(string)
  }))
}

variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
