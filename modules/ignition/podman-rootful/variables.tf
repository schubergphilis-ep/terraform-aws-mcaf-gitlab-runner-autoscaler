variable "ssh_authorized_key" {
  type        = string
  description = "SSH public key to authorize for root user access. Required for GitLab Runner autoscaler to connect as root."
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
}
