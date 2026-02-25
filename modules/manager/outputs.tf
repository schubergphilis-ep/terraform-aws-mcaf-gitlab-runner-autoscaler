output "public_ssh_key" {
  description = "Public SSH key for accessing GitLab Runner instances"
  value       = trimspace(tls_private_key.default.public_key_openssh)
}

output "security_group_id" {
  description = "Security group ID of the GitLab Runner manager for allowing instance communication"
  value       = module.runner_manager.security_group_id
}
