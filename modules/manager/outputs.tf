output "security_group_id" {
  description = "Security group ID of the GitLab Runner manager for allowing instance communication"
  value       = module.runner_manager.security_group_id
}
