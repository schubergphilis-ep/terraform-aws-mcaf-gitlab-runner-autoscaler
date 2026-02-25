output "setup_instance_store_rendered" {
  description = "Rendered systemd unit for NVMe instance store setup"
  value       = data.ignition_systemd_unit.setup_instance_store.rendered
}

output "container_storage_mount_rendered" {
  description = "Rendered systemd unit for container storage mount"
  value       = data.ignition_systemd_unit.container_storage_mount.rendered
}

output "relabel_container_storage_rendered" {
  description = "Rendered systemd unit for SELinux relabeling of container storage"
  value       = data.ignition_systemd_unit.relabel_container_storage.rendered
}

output "mask_docker_rendered" {
  description = "Rendered systemd unit for masking Docker service"
  value       = data.ignition_systemd_unit.mask_docker.rendered
}

output "mask_zincati_rendered" {
  description = "Rendered systemd unit for masking Zincati service (null if zincati is enabled)"
  value       = var.os_auto_updates.enabled ? null : data.ignition_systemd_unit.mask_zincati[0].rendered
}

output "zincati_config_rendered" {
  description = "Rendered Zincati config file (null if not using periodic strategy)"
  value       = var.os_auto_updates.enabled && var.os_auto_updates.strategy == "periodic" ? data.ignition_file.zincati_config[0].rendered : null
}
