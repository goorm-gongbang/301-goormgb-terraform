variable "bucket_name" {
  description = "테라폼 상태를 저장할 S3 버킷의 이름"
  type        = string
}

variable "dynamodb_table_name" {
  description = "테라폼 Lock을 위한 DynamoDB의 테이블 이름"
  type        = string
}