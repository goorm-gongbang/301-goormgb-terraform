# outputs.tf

output "github_actions_role_arn" {
  value       = module.oidc.role_arn
}
