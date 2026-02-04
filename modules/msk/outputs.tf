# modules/msk/outputs.tf

output "cluster_arn" {
  description = "MSK cluster ARN"
  value       = aws_msk_serverless_cluster.this.arn
}

output "cluster_name" {
  description = "MSK cluster name"
  value       = aws_msk_serverless_cluster.this.cluster_name
}

output "bootstrap_brokers_sasl_iam" {
  description = "Bootstrap brokers for SASL/IAM authentication"
  value       = aws_msk_serverless_cluster.this.cluster_uuid
}

output "security_group_id" {
  description = "Security group ID for MSK"
  value       = aws_security_group.this.id
}
