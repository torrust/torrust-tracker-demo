# Torrust Tracker Demo - Multi-Provider Infrastructure
# Provider-agnostic orchestration with pluggable provider modules

terraform {
  required_version = ">= 1.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7"
    }
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

# Variables for provider selection
variable "infrastructure_provider" {
  description = "Infrastructure provider to use (libvirt, hetzner, aws, etc.)"
  type        = string
  default     = "libvirt"
}

# Standard interface variables (passed to all providers)
variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  default     = "torrust-tracker-demo"
}

variable "vm_memory" {
  description = "Memory allocation for VM in MB"
  type        = number
  default     = 2048
}

variable "vm_vcpus" {
  description = "Number of vCPUs for the VM"
  type        = number
  default     = 2
}

variable "vm_disk_size" {
  description = "Primary disk size in GB"
  type        = number
  default     = 20
}

variable "persistent_data_size" {
  description = "Persistent data volume size in GB"
  type        = number
  default     = 20
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "development"
}

variable "use_minimal_config" {
  description = "Use minimal cloud-init configuration for debugging"
  type        = bool
  default     = false
}

# Additional variables that might be used by specific providers
# These will be ignored by providers that don't need them

# LibVirt-specific variables
variable "libvirt_uri" {
  description = "LibVirt connection URI"
  type        = string
  default     = "qemu:///system"
}

variable "libvirt_pool" {
  description = "LibVirt storage pool name"
  type        = string
  default     = "user-default"
}

variable "libvirt_network" {
  description = "LibVirt network name"
  type        = string
  default     = "default"
}

variable "base_image_url" {
  description = "URL for the base Ubuntu cloud image (LibVirt)"
  type        = string
  default     = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
}

# Hetzner-specific variables (for future use)
variable "hetzner_token" {
  description = "Hetzner Cloud API token"
  type        = string
  default     = ""
  sensitive   = true
}

variable "hetzner_server_type" {
  description = "Hetzner server type"
  type        = string
  default     = "cx31"
}

variable "hetzner_location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "nbg1"
}

variable "hetzner_image" {
  description = "Hetzner server image"
  type        = string
  default     = "ubuntu-24.04"
}

# Provider-specific configurations
# We'll use the provider selection through tfvars rather than count

# Configure libvirt provider when using libvirt
provider "libvirt" {
  uri = var.infrastructure_provider == "libvirt" ? var.libvirt_uri : null
}

# Configure hetzner provider when using hetzner
provider "hcloud" {
  token = var.infrastructure_provider == "hetzner" ? var.hetzner_token : "0000000000000000000000000000000000000000000000000000000000000000"
}

# LibVirt Infrastructure Module
module "libvirt_infrastructure" {
  source = "./providers/libvirt"
  
  # Only create when using libvirt provider
  count = var.infrastructure_provider == "libvirt" ? 1 : 0

  # Standard interface variables
  vm_name              = var.vm_name
  vm_memory            = var.vm_memory
  vm_vcpus             = var.vm_vcpus
  vm_disk_size         = var.vm_disk_size
  persistent_data_size = var.persistent_data_size
  ssh_public_key       = var.ssh_public_key
  use_minimal_config   = var.use_minimal_config
  infrastructure_provider = var.infrastructure_provider

  # LibVirt-specific variables
  libvirt_uri     = var.libvirt_uri
  libvirt_pool    = var.libvirt_pool
  libvirt_network = var.libvirt_network
  base_image_url  = var.base_image_url
}

# Hetzner Cloud provider module
module "hetzner_infrastructure" {
  source = "./providers/hetzner"
  count  = var.infrastructure_provider == "hetzner" ? 1 : 0

  # Standard interface variables
  infrastructure_provider = var.infrastructure_provider
  environment            = var.environment
  vm_name               = var.vm_name
  vm_memory             = var.vm_memory
  vm_vcpus              = var.vm_vcpus
  vm_disk_size          = var.vm_disk_size
  ssh_public_key        = var.ssh_public_key
  use_minimal_config    = var.use_minimal_config

  # Hetzner-specific variables
  hetzner_token       = var.hetzner_token
  hetzner_server_type = var.hetzner_server_type
  hetzner_location    = var.hetzner_location
  hetzner_image       = var.hetzner_image
}

# Standard outputs (available regardless of provider)
output "vm_ip" {
  value = var.infrastructure_provider == "libvirt" ? (
    length(module.libvirt_infrastructure) > 0 ? module.libvirt_infrastructure[0].vm_ip : "No provider module"
  ) : var.infrastructure_provider == "hetzner" ? (
    length(module.hetzner_infrastructure) > 0 ? module.hetzner_infrastructure[0].vm_ip : "No provider module"
  ) : "Unsupported provider"
  description = "IP address of the created VM"
}

output "vm_name" {
  value = var.infrastructure_provider == "libvirt" ? (
    length(module.libvirt_infrastructure) > 0 ? module.libvirt_infrastructure[0].vm_name : "No provider module"
  ) : var.infrastructure_provider == "hetzner" ? (
    length(module.hetzner_infrastructure) > 0 ? module.hetzner_infrastructure[0].vm_name : "No provider module"  
  ) : "Unsupported provider"
  description = "Name of the created VM"
}

output "connection_info" {
  value = var.infrastructure_provider == "libvirt" ? (
    length(module.libvirt_infrastructure) > 0 ? module.libvirt_infrastructure[0].connection_info : "No provider module"
  ) : var.infrastructure_provider == "hetzner" ? (
    length(module.hetzner_infrastructure) > 0 ? module.hetzner_infrastructure[0].connection_info : "No provider module"
  ) : "Unsupported provider"
  description = "SSH connection command"
}

output "infrastructure_provider" {
  value = var.infrastructure_provider
  description = "Infrastructure provider used for deployment"
}
