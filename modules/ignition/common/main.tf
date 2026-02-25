# Common Ignition systemd units shared across all container runtime scenarios
# This module is parameterized to support both Docker and Podman configurations

# Conditional NVMe instance store provisioning service
# This service runs at boot and:
# 1. Detects if NVMe instance store exists (/dev/nvme1n1)
# 2. If present: partitions, formats as XFS, and labels it
# 3. If absent: does nothing (instances without instance store use EBS)
data "ignition_systemd_unit" "setup_instance_store" {
  name    = "setup-instance-store.service"
  enabled = true

  content = <<-EOT
    [Unit]
    Description=Setup NVMe instance store for container storage if available
    DefaultDependencies=no
    After=local-fs-pre.target
    Before=local-fs.target
    ConditionPathExistsGlob=/dev/disk/by-id/nvme-Amazon_EC2_NVMe_Instance_Storage_*

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStart=/bin/sh -c '\
      DEVICE=$$(readlink -f $$(ls /dev/disk/by-id/nvme-Amazon_EC2_NVMe_Instance_Storage_* | head -n1)); \
      PART="$$DEVICE"p1; \
      echo "label: gpt\ntype=linux" | /usr/sbin/sfdisk "$$DEVICE"; \
      /usr/sbin/partx -u "$$DEVICE"; \
      /usr/sbin/mkfs.xfs -f -L ${var.container_storage_label} "$$PART"; \
      /usr/bin/udevadm settle'

    [Install]
    WantedBy=local-fs.target
  EOT
}

# Conditional mount unit for NVMe instance store
# Only mounts if the labeled device exists (created by setup-instance-store.service)
# Unit name is derived from the mount path (systemd requirement)
locals {
  # Convert mount path to systemd unit name format
  # e.g., /var/lib/containers -> var-lib-containers.mount
  mount_unit_name = "${replace(trimprefix(trimsuffix(var.container_storage_path, "/"), "/"), "/", "-")}.mount"
}

data "ignition_systemd_unit" "container_storage_mount" {
  name    = local.mount_unit_name
  enabled = true

  content = <<-EOT
    [Unit]
    Description=Mount NVMe instance store to ${var.container_storage_path}
    After=setup-instance-store.service
    ConditionPathExists=/dev/disk/by-label/${var.container_storage_label}

    [Mount]
    What=/dev/disk/by-label/${var.container_storage_label}
    Where=${var.container_storage_path}
    Type=xfs
    Options=defaults,noatime,nofail,x-systemd.device-timeout=5

    [Install]
    WantedBy=local-fs.target
  EOT
}

# Apply SELinux labels to mounted instance store
# This must run after the mount to ensure files created on the instance store have correct labels
data "ignition_systemd_unit" "relabel_container_storage" {
  name    = "relabel-container-storage.service"
  enabled = true

  content = <<-EOT
    [Unit]
    Description=Setup ownership and SELinux labels for ${var.container_storage_path}
    After=${local.mount_unit_name}
    ConditionPathIsMountPoint=${var.container_storage_path}

    [Service]
    Type=oneshot
    ExecStart=/usr/bin/chown ${var.container_storage_owner}:${var.container_storage_group} ${var.container_storage_path}
    ExecStart=/usr/bin/chmod ${var.container_storage_mode} ${var.container_storage_path}
    ExecStart=/usr/sbin/restorecon -R ${var.container_storage_path}
    RemainAfterExit=yes

    [Install]
    WantedBy=multi-user.target
  EOT
}

data "ignition_systemd_unit" "mask_docker" {
  name = "docker.service"
  mask = true
}

# Mask Zincati auto-updater when disabled
data "ignition_systemd_unit" "mask_zincati" {
  count = var.os_auto_updates.enabled ? 0 : 1

  name = "zincati.service"
  mask = true
}

# Zincati configuration file for update strategy
# Only created when zincati is enabled and strategy is periodic
data "ignition_file" "zincati_config" {
  count = var.os_auto_updates.enabled && var.os_auto_updates.strategy == "periodic" ? 1 : 0

  path      = "/etc/zincati/config.d/55-updates-strategy.toml"
  mode      = 420 # 0644
  overwrite = true

  contents {
    source = "data:text/plain;charset=utf-8;base64,${base64encode(<<-EOT
[updates]
strategy = "periodic"

%{for window in var.os_auto_updates.maintenance_windows~}
[[updates.periodic.window]]
days = [${join(", ", [for d in window.days : "\"${d}\""])}]
start_time = "${window.start_time}"
length_minutes = ${window.length_minutes}

%{endfor~}
EOT
    )}"
  }
}
