# Hetzner Provider Version Requirements

terraform {
  required_version = ">= 1.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.47"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}
