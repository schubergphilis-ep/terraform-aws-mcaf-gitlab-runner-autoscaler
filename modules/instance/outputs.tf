output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group for GitLab Runner instances"
  value       = aws_autoscaling_group.default.name
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group for GitLab Runner instances"
  value       = aws_autoscaling_group.default.arn
}

output "security_group_id" {
  description = "ID of the security group attached to runner instances"
  value       = aws_security_group.default.id
}

output "launch_template_id" {
  description = "ID of the launch template used by the Auto Scaling Group"
  value       = aws_launch_template.default.id
}
