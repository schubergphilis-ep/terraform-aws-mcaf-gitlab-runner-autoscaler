variable "container_storage_path" {
  type        = string
  description = "Mount path for container storage (e.g., /var/lib/containers or /var/lib/docker)"
  default     = "/var/lib/containers"
}

variable "container_storage_label" {
  type        = string
  description = "Filesystem label for the container storage volume"
  default     = "containers"
}

variable "container_storage_owner" {
  type        = string
  description = "Owner user for the container storage directory (e.g., root or core)"
  default     = "root"
}

variable "container_storage_group" {
  type        = string
  description = "Owner group for the container storage directory (e.g., root or core)"
  default     = "root"
}

variable "container_storage_mode" {
  type        = string
  description = "Permission mode for the container storage directory (e.g., 0755)"
  default     = "0755"
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
  description = "OS auto-updater (Zincati) configuration for Fedora CoreOS instances"
  default     = {}

  validation {
    condition     = contains(["immediate", "periodic"], var.os_auto_updates.strategy)
    error_message = "Zincati strategy must be either 'immediate' or 'periodic'"
  }

  validation {
    condition     = var.os_auto_updates.strategy != "periodic" || length(var.os_auto_updates.maintenance_windows) > 0
    error_message = "Zincati maintenance_windows must be specified when strategy is 'periodic'"
  }
}
