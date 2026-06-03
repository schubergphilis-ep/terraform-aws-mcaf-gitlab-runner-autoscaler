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

variable "http_proxy" {
  description = "HTTP proxy for Podman systemd service environment for use in air-gapped environments"
  type        = string
  default     = ""
}

variable "https_proxy" {
  description = "HTTPS proxy for Podman systemd service environment for use in air-gapped environments"
  type        = string
  default     = ""
}

variable "no_proxy" {
  description = "No-proxy list for Podman systemd service environment for use in air-gapped environments"
  type        = string
  default     = ""
}
