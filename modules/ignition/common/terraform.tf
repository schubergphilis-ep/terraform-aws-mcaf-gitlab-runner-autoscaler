terraform {
  required_version = ">= 1.3"

  required_providers {
    ignition = {
      source  = "community-terraform-providers/ignition"
      version = ">= 2.1"
    }
  }
}
