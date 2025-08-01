# Hetzner Provider Variables
# Implements the standard provider interface

# === STANDARD PROVIDER INTERFACE ===
# These variables are required by all providers to ensure consistency

variable "infrastructure_provider" {
  description = "The infrastructure provider name"
  type        = string
  default     = "hetzner"
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
}

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
}

variable "vm_memory" {
  description = "Memory allocation in MB (mapped to server_type)"
  type        = number
  default     = 4096
}

variable "vm_vcpus" {
  description = "Number of vCPUs (mapped to server_type)"
  type        = number
  default     = 2
}

variable "vm_disk_size" {
  description = "Disk size in GB (Hetzner uses fixed sizes per server type)"
  type        = number
  default     = 40
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  sensitive   = true
}

variable "use_minimal_config" {
  description = "Use minimal cloud-init configuration for debugging"
  type        = bool
  default     = false
}

# === HETZNER-SPECIFIC VARIABLES ===
# These variables are specific to Hetzner Cloud

variable "hetzner_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "hetzner_server_type" {
  description = "Hetzner server type (cx22, cx32, cx42, cx52, etc.)"
  type        = string
  default     = "cx32"  # 4 vCPU, 8GB RAM, 80GB SSD

  validation {
    condition = contains([
      "cx22", "cx32", "cx42", "cx52",
      "cpx11", "cpx21", "cpx31", "cpx41", "cpx51",
      "cax11", "cax21", "cax31", "cax41",
      "ccx13", "ccx23", "ccx33", "ccx43", "ccx53", "ccx63"
    ], var.hetzner_server_type)
    error_message = "Server type must be a valid Hetzner server type."
  }
}

variable "hetzner_location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "nbg1"  # Nuremberg, Germany

  validation {
    condition = contains([
      "nbg1",   # Nuremberg, Germany
      "fsn1",   # Falkenstein, Germany
      "hel1",   # Helsinki, Finland
      "ash",    # Ashburn, VA, USA
      "hil"     # Hillsboro, OR, USA
    ], var.hetzner_location)
    error_message = "Location must be a valid Hetzner datacenter location."
  }
}

variable "hetzner_image" {
  description = "Hetzner server image"
  type        = string
  default     = "ubuntu-24.04"

  validation {
    condition = contains([
      "ubuntu-20.04", "ubuntu-22.04", "ubuntu-24.04",
      "debian-11", "debian-12",
      "centos-stream-8", "centos-stream-9",
      "rocky-8", "rocky-9"
    ], var.hetzner_image)
    error_message = "Image must be a valid Hetzner image."
  }
}

# === SERVER TYPE MAPPINGS ===
# Map standard interface variables to Hetzner server types
# This allows the standard interface to work while using Hetzner's predefined sizes

locals {
  # Map memory requirements to appropriate Hetzner server types
  server_type_by_memory = {
    # Small configurations
    1024  = "cx11"   # 1 vCPU, 4GB RAM, 25GB SSD
    2048  = "cx21"   # 2 vCPU, 8GB RAM, 40GB SSD
    # Medium configurations  
    4096  = "cx31"   # 2 vCPU, 8GB RAM, 80GB SSD
    8192  = "cx41"   # 4 vCPU, 16GB RAM, 160GB SSD
    # Large configurations
    16384 = "cx51"   # 8 vCPU, 32GB RAM, 320GB SSD
  }

  # Use explicit server_type if provided, otherwise map from memory
  actual_server_type = var.hetzner_server_type != "cx31" ? var.hetzner_server_type : lookup(
    local.server_type_by_memory,
    var.vm_memory,
    "cx31"  # Default fallback
  )
}
