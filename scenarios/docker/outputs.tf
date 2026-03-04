output "instance_security_group_id" {
  description = "Security group ID of the GitLab Runner instance"
  value       = module.instance.security_group_id
}

output "manager_security_group_id" {
  description = "Security group ID of the GitLab Runner manager"
  value       = module.manager.security_group_id
}

