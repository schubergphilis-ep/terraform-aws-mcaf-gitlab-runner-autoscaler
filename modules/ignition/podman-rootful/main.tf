# Rootful Podman Ignition configuration module
# This module creates a complete Ignition config for rootful Podman setup

# Use common systemd units
module "common" {
  source = "../common"

  os_auto_updates = var.os_auto_updates
}

# Enable Podman socket (rootful) for root user
data "ignition_systemd_unit" "podman_socket" {
  name    = "podman.socket"
  enabled = true
}

# Create symlink from /var/run/docker.sock to Podman socket for Docker compatibility
data "ignition_systemd_unit" "docker_sock_symlink" {
  name    = "docker-sock-symlink.service"
  enabled = true

  content = <<-EOF
    [Unit]
    Description=Create symlink from docker.sock to podman.sock
    After=podman.socket
    Requires=podman.socket

    [Service]
    Type=oneshot
    ExecStart=/usr/bin/mkdir -p /var/run
    ExecStart=/usr/bin/ln -sf /run/podman/podman.sock /var/run/docker.sock
    ExecStart=/usr/bin/cp /usr/share/containers/seccomp.json /etc/containers/seccomp.json
    RemainAfterExit=yes

    [Install]
    WantedBy=multi-user.target
  EOF
}

# Assemble complete Ignition config for rootful Podman
data "ignition_config" "default" {
  systemd = compact([
    module.common.setup_instance_store_rendered,
    module.common.container_storage_mount_rendered,
    module.common.relabel_container_storage_rendered,
    module.common.mask_docker_rendered,
    module.common.mask_zincati_rendered,
    module.common.mask_afterburn_sshkeys_rendered,
    module.common.relabel_eic_scripts_rendered,
    data.ignition_systemd_unit.podman_socket.rendered,
    data.ignition_systemd_unit.docker_sock_symlink.rendered
  ])
  files = compact([
    module.common.zincati_config_rendered,
    module.common.eic_run_authorized_keys_rendered,
    module.common.eic_sshd_config_rendered,
  ])
  users = [
    module.common.ec2_instance_connect_user_rendered
  ]
}
