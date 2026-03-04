locals {
  gitlab_runner_config = {
    concurrent = var.concurrent_jobs
    runners = {
      name = var.runner_name
      url  = var.gitlab_url
      docker = {
        host       = "unix:///run/podman/podman.sock"
        privileged = var.privileged_mode
        volumes    = ["/run/podman/podman.sock:/tmp/podman.sock:z", "/var/builds:/var/builds", "/cache"]
      }
      autoscaler = {
        plugin                = "aws"
        capacity_per_instance = var.capacity_per_instance
        max_instances         = var.max_instances
        connector_config = {
          username          = "root"
          use_external_addr = false
        }
        policy = var.autoscaler_policy
      }
    }
  }
}

module "manager" {
  source = "../../modules/manager"

  docker_credential_helpers = var.docker_credential_helpers
  gitlab_runner_config      = local.gitlab_runner_config
  gitlab_runner_image       = var.gitlab_runner_image
  gitlab_runner_token       = var.gitlab_runner_token
  kms_key_id                = var.kms_key_id
  vpc_id                    = var.vpc_id
  vpc_subnet_ids            = var.vpc_subnet_ids
  tags                      = var.tags
}

# Use rootful Podman Ignition module
module "ignition" {
  source = "../../modules/ignition/podman-rootful"

  os_auto_updates = var.os_auto_updates
}

module "instance" {
  source = "../../modules/instance"

  architecture                     = var.architecture
  ebs_volume_size                  = var.ebs_volume_size
  ebs_volume_type                  = var.ebs_volume_type
  gitlab_manager_security_group_id = module.manager.security_group_id
  gitlab_runner_config             = local.gitlab_runner_config
  instance_types                   = var.instance_types
  kms_key_id                       = var.kms_key_id
  on_demand_base_capacity          = var.on_demand_base_capacity
  on_demand_percentage_above_base  = var.on_demand_percentage_above_base
  user_data                        = base64encode(module.ignition.rendered)
  vpc_id                           = var.vpc_id
  vpc_subnet_ids                   = var.vpc_subnet_ids
  tags                             = var.tags
}
