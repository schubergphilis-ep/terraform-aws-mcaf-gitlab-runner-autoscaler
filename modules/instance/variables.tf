variable "architecture" {
  type        = string
  description = "CPU architecture for the runner instances (arm64 or x86_64)"
  default     = "arm64"
  validation {
    condition     = contains(["arm64", "x86_64"], var.architecture)
    error_message = "Architecture must be either 'arm64' or 'x86_64'"
  }
}

variable "coreos_version" {
  type        = string
  description = "Fedora CoreOS major version to use for the AMI"
  default     = "43"
  nullable    = false
}

variable "ebs_volume_size" {
  type        = number
  description = "Size of the EBS root volume in GB"
  default     = 200
  nullable    = false
}

variable "ebs_volume_type" {
  type        = string
  description = "Type of EBS volume (gp3, gp2, io1, io2)"
  default     = "gp3"
  nullable    = false

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.ebs_volume_type)
    error_message = "EBS volume type must be one of: gp2, gp3, io1, io2."
  }
}

variable "gitlab_manager_security_group_id" {
  type        = string
  description = "Security group ID of the GitLab Runner manager for SSH access to instances"
}

variable "gitlab_runner_config" {
  type = object({
    concurrent = number
    runners = object({
      name        = string
      url         = string
      shell       = optional(string, "sh")
      environment = optional(list(string), ["CONTAINER_HOST=unix:///tmp/podman.sock", "DOCKER_HOST=unix:///tmp/podman.sock"])
      executor    = optional(string, "docker-autoscaler")
      builds_dir  = optional(string, "/var/builds")
      docker = object({
        host                         = optional(string, "unix:///run/podman/podman.sock")
        tls_verify                   = optional(bool, false)
        privileged                   = optional(bool, false)
        disable_entrypoint_overwrite = optional(bool, false)
        oom_kill_disable             = optional(bool, false)
        disable_cache                = optional(bool, false)
        volumes                      = optional(list(string), ["/run/podman/podman.sock:/tmp/podman.sock:z", "/etc/builds:/etc/builds", "/cache"])
        environment                  = optional(list(string), [])
        image                        = optional(string, "alpine:latest")
      })
      autoscaler = object({
        plugin                = string
        capacity_per_instance = number
        max_use_count         = optional(number, 0)
        max_instances         = number
        plugin_config = optional(object({
          name             = optional(string, "")
          profile          = optional(string, "")
          config_file      = optional(string, "")
          credentials_file = optional(string, "")
        }))
        connector_config = object({
          username          = string
          use_external_addr = bool
        })
        policy = list(object({
          idle_count      = number
          idle_time       = string
          preemptive_mode = optional(bool, true)
          periods         = optional(list(string), [])
          timezone        = optional(string, "Europe/Amsterdam")
        }))
      })
    })
  })
  description = "GitLab Runner configuration for Docker Autoscaler"
}

variable "instance_types" {
  type        = list(string)
  description = "List of instance types to use in the ASG (ordered by preference). If not specified, automatically queries AWS for current-generation compute-optimized instances with instance storage matching the selected architecture"
  default     = null
  nullable    = true
}

variable "on_demand_base_capacity" {
  type        = number
  description = "Absolute minimum number of on-demand instances"
  default     = 0
  nullable    = false
}

variable "on_demand_percentage_above_base" {
  type        = number
  description = "Percentage of on-demand instances above base capacity (0-100, where 0 = 100% spot)"
  default     = 0
  nullable    = false

  validation {
    condition     = var.on_demand_percentage_above_base >= 0 && var.on_demand_percentage_above_base <= 100
    error_message = "On-demand percentage must be between 0 and 100."
  }
}

variable "tags" {
  type        = map(string)
  description = "Map of tags to apply to all resources"
  default     = {}
}

variable "user_data" {
  type        = string
  description = "Base64-encoded Ignition configuration for instance initialization"
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC where the runner instances will be deployed"
}

variable "vpc_subnet_ids" {
  type        = list(string)
  description = "List of VPC subnet IDs where runner instances will be deployed"
}
