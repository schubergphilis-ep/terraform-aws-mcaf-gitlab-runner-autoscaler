# Rootless Podman Ignition configuration module
# This module creates a complete Ignition config for rootless Podman setup

# Use common systemd units with rootless Podman storage path
# Mount at /var/home/core so core user has fast storage for container data
module "common" {
  source = "../common"

  container_storage_path  = "/var/home/core/.local/share/containers"
  container_storage_label = "containers"
  container_storage_owner = "core"
  container_storage_group = "core"
  container_storage_mode  = "0700"
  os_auto_updates         = var.os_auto_updates
}

# Note: For rootless Podman, we don't enable the system-level podman.socket
# The user-level socket is managed by podman-user.service below

# Enable lingering for core user to ensure user systemd instance runs at boot
data "ignition_systemd_unit" "enable_linger" {
  name    = "enable-linger-core.service"
  enabled = true

  content = <<-EOF
    [Unit]
    Description=Enable lingering for core user
    Before=podman-user.service
    ConditionPathExists=!/var/lib/systemd/linger/core

    [Service]
    Type=oneshot
    ExecStart=/usr/bin/loginctl enable-linger core
    RemainAfterExit=yes

    [Install]
    WantedBy=multi-user.target
  EOF
}

# Enable rootless Podman for core user at boot
data "ignition_systemd_unit" "podman_user_socket" {
  name    = "podman-user.service"
  enabled = true

  content = <<-EOF
    [Unit]
    Description=Enable rootless Podman for core user
    After=network-online.target enable-linger-core.service
    Wants=network-online.target
    Requires=enable-linger-core.service

    [Service]
    Type=oneshot
    ExecStart=/usr/bin/runuser -l core -c 'systemctl --user enable --now podman.socket'
    ExecStartPost=/usr/bin/sleep 2
    ExecStartPost=/usr/bin/runuser -l core -c 'systemctl --user is-active podman.socket'
    RemainAfterExit=yes
    TimeoutStartSec=60

    [Install]
    WantedBy=multi-user.target
  EOF
}

# Create symlink from /var/run/docker.sock to Podman socket for Docker compatibility
data "ignition_systemd_unit" "docker_sock_symlink" {
  name    = "docker-sock-symlink.service"
  enabled = true

  content = <<-EOF
    [Unit]
    Description=Create symlink from docker.sock to podman.sock (rootless)
    After=podman-user.service
    Requires=podman-user.service

    [Service]
    Type=oneshot
    ExecStart=/usr/bin/ln -sf /run/user/1000/podman/podman.sock /var/run/docker.sock
    RemainAfterExit=yes

    [Install]
    WantedBy=multi-user.target
  EOF
}

# Assemble complete Ignition config for rootless Podman
# Note: SSH key for 'core' user is automatically configured by AWS via key_pair in launch template
data "ignition_config" "default" {
  systemd = compact([
    module.common.setup_instance_store_rendered,
    module.common.container_storage_mount_rendered,
    module.common.relabel_container_storage_rendered,
    module.common.mask_docker_rendered,
    module.common.mask_zincati_rendered,
    data.ignition_systemd_unit.enable_linger.rendered,
    data.ignition_systemd_unit.podman_user_socket.rendered,
    data.ignition_systemd_unit.docker_sock_symlink.rendered
  ])
  files = compact([
    module.common.zincati_config_rendered
  ])
}
