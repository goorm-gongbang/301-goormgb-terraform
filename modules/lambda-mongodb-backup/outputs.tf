# modules/lambda-mongodb-backup/outputs.tf

output "function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.mongodb_backup.function_name
}

output "function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.mongodb_backup.arn
}

output "role_arn" {
  description = "Lambda execution role ARN"
  value       = aws_iam_role.lambda.arn
}

output "schedule_rule_arn" {
  description = "EventBridge schedule rule ARN"
  value       = aws_cloudwatch_event_rule.daily_backup.arn
}
