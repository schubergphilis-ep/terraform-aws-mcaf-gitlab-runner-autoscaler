terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    ignition = {
      source  = "community-terraform-providers/ignition"
      version = "~> 2.1"
    }
  }
}
