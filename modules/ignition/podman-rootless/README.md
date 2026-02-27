# Ignition Podman Rootless

Ignition configuration for rootless Podman on Fedora CoreOS. Configures user-level Podman socket, lingering, and Docker socket compatibility symlink.

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

| Name | Source | Version |
|------|--------|---------|
| <a name="module_common"></a> [common](#module\_common) | ../common | n/a |

## Resources

| Name | Type |
|------|------|
| [ignition_config.default](https://registry.terraform.io/providers/community-terraform-providers/ignition/latest/docs/data-sources/config) | data source |
| [ignition_systemd_unit.docker_sock_symlink](https://registry.terraform.io/providers/community-terraform-providers/ignition/latest/docs/data-sources/systemd_unit) | data source |
| [ignition_systemd_unit.enable_linger](https://registry.terraform.io/providers/community-terraform-providers/ignition/latest/docs/data-sources/systemd_unit) | data source |
| [ignition_systemd_unit.podman_user_socket](https://registry.terraform.io/providers/community-terraform-providers/ignition/latest/docs/data-sources/systemd_unit) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_os_auto_updates"></a> [os\_auto\_updates](#input\_os\_auto\_updates) | OS auto-updater (Zincati) configuration for Fedora CoreOS instances | <pre>object({<br/>    enabled  = optional(bool, true)<br/>    strategy = optional(string, "immediate") # immediate or periodic<br/>    maintenance_windows = optional(list(object({<br/>      days           = list(string) # ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]<br/>      start_time     = string       # "22:00" (UTC)<br/>      length_minutes = number       # 60<br/>    })), [])<br/>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_rendered"></a> [rendered](#output\_rendered) | Complete rendered Ignition configuration for rootless Podman |
<!-- END_TF_DOCS -->
