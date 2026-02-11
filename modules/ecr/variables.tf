variable "repository_name" {
  description = "생성할 ECR 레포의 이름"
  type = string
}

variable "tags" {
  description = "리소스에 부여할 태그 맵"
  type = map(string)
  default = {}
}