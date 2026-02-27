variable "docker_credential_helpers" {
  type        = map(string)
  description = "Map of Docker registry hostnames to credential helper names, written to the manager's /root/.docker/config.json as credHelpers"
  default     = {}
}

variable "gitlab_runner_command" {
  type        = list(string)
  description = "Command to run the GitLab Runner"
  default     = ["run"]
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
        volumes                      = optional(list(string), [])
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

variable "gitlab_runner_image" {
  type        = string
  description = "Container image for the GitLab Runner manager (should be pinned to a specific version or digest)"
  default     = "schubergphilis/gitlab-runner-autoscaler:alpine"
}

variable "gitlab_runner_token" {
  type        = string
  description = "GitLab Runner authentication token"
  sensitive   = true
}

variable "kms_key_id" {
  type        = string
  description = "KMS key ID for encrypting Secrets Manager secrets. If not provided, uses AWS managed key (aws/secretsmanager)"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Map of tags to apply to all resources"
  default     = {}
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC where the GitLab Runner manager will be deployed"
}

variable "vpc_subnet_ids" {
  type        = list(string)
  description = "List of VPC subnet IDs where the GitLab Runner manager will be deployed"
}
