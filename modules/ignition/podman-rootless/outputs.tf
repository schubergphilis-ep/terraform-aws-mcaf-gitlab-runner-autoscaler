output "rendered" {
  description = "Complete rendered Ignition configuration for rootless Podman"
  value       = data.ignition_config.default.rendered
}
