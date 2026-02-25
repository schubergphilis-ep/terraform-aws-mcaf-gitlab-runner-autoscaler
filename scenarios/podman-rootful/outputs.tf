output "instance_security_group_id" {
  description = "Security group ID of the GitLab Runner instance"
  value       = module.instance.security_group_id
}

output "manager_security_group_id" {
  description = "Security group ID of the GitLab Runner manager"
  value       = module.manager.security_group_id
}

output "public_ssh_key" {
  description = "Public SSH key for accessing runner instances"
  value       = module.manager.public_ssh_key
}
