# Ignition Common

Shared systemd units and Ignition configuration used by all Podman scenarios.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_ignition"></a> [ignition](#requirement\_ignition) | >= 2.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_ignition"></a> [ignition](#provider\_ignition) | 2.6.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [ignition_file.zincati_config](https://registry.terraform.io/providers/community-terraform-providers/ignition/latest/docs/data-sources/file) | data source |
| [ignition_systemd_unit.container_storage_mount](https://registry.terraform.io/providers/community-terraform-providers/ignition/latest/docs/data-sources/systemd_unit) | data source |
| [ignition_systemd_unit.mask_docker](https://registry.terraform.io/providers/community-terraform-providers/ignition/latest/docs/data-sources/systemd_unit) | data source |
| [ignition_systemd_unit.mask_zincati](https://registry.terraform.io/providers/community-terraform-providers/ignition/latest/docs/data-sources/systemd_unit) | data source |
| [ignition_systemd_unit.relabel_container_storage](https://registry.terraform.io/providers/community-terraform-providers/ignition/latest/docs/data-sources/systemd_unit) | data source |
| [ignition_systemd_unit.setup_instance_store](https://registry.terraform.io/providers/community-terraform-providers/ignition/latest/docs/data-sources/systemd_unit) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_container_storage_group"></a> [container\_storage\_group](#input\_container\_storage\_group) | Owner group for the container storage directory (e.g., root or core) | `string` | `"root"` | no |
| <a name="input_container_storage_label"></a> [container\_storage\_label](#input\_container\_storage\_label) | Filesystem label for the container storage volume | `string` | `"containers"` | no |
| <a name="input_container_storage_mode"></a> [container\_storage\_mode](#input\_container\_storage\_mode) | Permission mode for the container storage directory (e.g., 0755) | `string` | `"0755"` | no |
| <a name="input_container_storage_owner"></a> [container\_storage\_owner](#input\_container\_storage\_owner) | Owner user for the container storage directory (e.g., root or core) | `string` | `"root"` | no |
| <a name="input_container_storage_path"></a> [container\_storage\_path](#input\_container\_storage\_path) | Mount path for container storage (e.g., /var/lib/containers or /var/lib/docker) | `string` | `"/var/lib/containers"` | no |
| <a name="input_os_auto_updates"></a> [os\_auto\_updates](#input\_os\_auto\_updates) | OS auto-updater (Zincati) configuration for Fedora CoreOS instances | <pre>object({<br/>    enabled  = optional(bool, true)<br/>    strategy = optional(string, "immediate") # immediate or periodic<br/>    maintenance_windows = optional(list(object({<br/>      days           = list(string) # ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]<br/>      start_time     = string       # "22:00" (UTC)<br/>      length_minutes = number       # 60<br/>    })), [])<br/>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_container_storage_mount_rendered"></a> [container\_storage\_mount\_rendered](#output\_container\_storage\_mount\_rendered) | Rendered systemd unit for container storage mount |
| <a name="output_mask_docker_rendered"></a> [mask\_docker\_rendered](#output\_mask\_docker\_rendered) | Rendered systemd unit for masking Docker service |
| <a name="output_mask_zincati_rendered"></a> [mask\_zincati\_rendered](#output\_mask\_zincati\_rendered) | Rendered systemd unit for masking Zincati service (null if zincati is enabled) |
| <a name="output_relabel_container_storage_rendered"></a> [relabel\_container\_storage\_rendered](#output\_relabel\_container\_storage\_rendered) | Rendered systemd unit for SELinux relabeling of container storage |
| <a name="output_setup_instance_store_rendered"></a> [setup\_instance\_store\_rendered](#output\_setup\_instance\_store\_rendered) | Rendered systemd unit for NVMe instance store setup |
| <a name="output_zincati_config_rendered"></a> [zincati\_config\_rendered](#output\_zincati\_config\_rendered) | Rendered Zincati config file (null if not using periodic strategy) |
<!-- END_TF_DOCS -->
