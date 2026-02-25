output "rendered" {
  description = "Complete rendered Ignition configuration for rootful Podman"
  value       = data.ignition_config.default.rendered
}
