# Rootful Podman Ignition configuration module
# This module creates a complete Ignition config for rootful Podman setup

locals {
  podman_proxy_values = {
    http_proxy  = trimspace(var.http_proxy != null ? var.http_proxy : "")
    https_proxy = trimspace(var.https_proxy != null ? var.https_proxy : "")
    no_proxy    = trimspace(var.no_proxy != null ? var.no_proxy : "")
  }

  podman_proxy_enabled = (
    local.podman_proxy_values.http_proxy != "" ||
    local.podman_proxy_values.https_proxy != ""
  )
}

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

data "ignition_directory" "podman_system_config_dir" {
  count = local.podman_proxy_enabled ? 1 : 0

  path      = "/etc/containers/containers.conf.d"
  mode      = 493 # 0755
  overwrite = true
}

data "ignition_file" "podman_engine_proxy_config" {
  count = local.podman_proxy_enabled ? 1 : 0

  path      = "/etc/containers/containers.conf.d/10-proxy.conf"
  mode      = 420 # 0644
  overwrite = true

  contents {
    source = "data:text/plain;charset=utf-8;base64,${base64encode(<<-EOF
[engine]
env = [${join(", ", [for key, value in local.podman_proxy_values : "\"${key}=${value}\"" if value != ""])}]
EOF
    )}"
  }
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
    length(data.ignition_file.podman_engine_proxy_config) > 0 ? data.ignition_file.podman_engine_proxy_config[0].rendered : null,
  ])
  users = compact([
    module.common.ec2_instance_connect_user_rendered,
  ])
  directories = compact([
    length(data.ignition_directory.podman_system_config_dir) > 0 ? data.ignition_directory.podman_system_config_dir[0].rendered : null
  ])
}
