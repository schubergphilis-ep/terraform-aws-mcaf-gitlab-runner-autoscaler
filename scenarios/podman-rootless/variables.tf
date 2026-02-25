variable "architecture" {
  type        = string
  description = "CPU architecture for GitLab Runner (arm64 or x86_64)"
  default     = "arm64"
  validation {
    condition     = contains(["arm64", "x86_64"], var.architecture)
    error_message = "Architecture must be either 'arm64' or 'x86_64'"
  }
}

variable "autoscaler_policy" {
  type = list(object({
    idle_count      = number
    idle_time       = string
    preemptive_mode = optional(bool, true)
    periods         = optional(list(string), [])
    timezone        = optional(string, "Europe/Amsterdam")
  }))
  description = "Autoscaler idle policy configuration"
  default = [
    {
      idle_count = 0
      idle_time  = "5m"
      periods    = ["* * * * *"]
    }
  ]
}

variable "capacity_per_instance" {
  type        = number
  description = "Number of jobs each instance can handle concurrently"
  default     = 1

  validation {
    condition     = var.capacity_per_instance >= 1
    error_message = "Capacity per instance must be at least 1."
  }
}

variable "concurrent_jobs" {
  type        = number
  description = "Maximum number of concurrent jobs the runner can handle"
  default     = 4

  validation {
    condition     = var.concurrent_jobs >= 1
    error_message = "Concurrent jobs must be at least 1."
  }
}

variable "ebs_volume_size" {
  type        = number
  description = "Size of the EBS root volume in GB. Defaults to 200"
  default     = null
}

variable "ebs_volume_type" {
  type        = string
  description = "Type of EBS volume (gp3, gp2, io1, io2). Defaults to gp3"
  default     = null
}

variable "gitlab_runner_image" {
  type        = string
  description = "Container image for the GitLab Runner manager (should be pinned to a specific version or digest)"
  default     = null
}

variable "gitlab_runner_token" {
  type        = string
  description = "GitLab Runner registration token for authenticating the runner with GitLab"
  sensitive   = true
}

variable "gitlab_url" {
  type        = string
  description = "GitLab instance URL (e.g., https://gitlab.com)"
}

variable "instance_types" {
  type        = list(string)
  description = "List of EC2 instance types to use (ordered by preference). If not specified, automatically discovers current-generation compute-optimized instances with instance storage for the selected architecture"
  default     = null
}

variable "kms_key_id" {
  type        = string
  description = "Optional KMS key ID for encrypting Secrets Manager secrets. If not provided, uses AWS managed key"
  default     = null
}

variable "max_instances" {
  type        = number
  description = "Maximum number of instances the autoscaler can create"
  default     = 5
}

variable "on_demand_base_capacity" {
  type        = number
  description = "Absolute minimum number of on-demand instances. Defaults to 0 (all spot)"
  default     = null
}

variable "on_demand_percentage_above_base" {
  type        = number
  description = "Percentage of on-demand instances above base capacity (0-100). Defaults to 0 (100% spot)"
  default     = null
}

variable "os_auto_updates" {
  type = object({
    enabled  = optional(bool, true)
    strategy = optional(string, "immediate") # immediate or periodic
    maintenance_windows = optional(list(object({
      days           = list(string) # ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
      start_time     = string       # "22:00" (UTC)
      length_minutes = number       # 60
    })), [])
  })
  description = "OS auto-updater (Zincati) configuration for Fedora CoreOS instances. Set enabled=false to disable auto-updates entirely, or use strategy='periodic' with maintenance_windows to control when updates are applied."
  default     = {}
}

variable "privileged_mode" {
  type        = bool
  description = "Enable Docker privileged mode for runners (required for Docker-in-Docker)"
  default     = true
}

variable "runner_name" {
  type        = string
  description = "Name prefix for the GitLab Runner and AWS resources"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the GitLab Runner infrastructure will be deployed"
}

variable "vpc_subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for deploying the manager and instances"
}
