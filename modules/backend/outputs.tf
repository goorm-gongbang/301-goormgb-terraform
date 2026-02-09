output "s3_bucket_id" {
  description = "생성된 S3 버킷 ID"
  value       = aws_s3_bucket.tf_state.id
}

output "dynamodb_table_name" {
  description = "생성된 DynamoDB 테이블 이름"
  value       = aws_dynamodb_table.tf_lock.name
}