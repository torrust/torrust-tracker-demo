# LibVirt Provider - Variables
# Implements the standard provider interface

# Standard interface variables (required by all providers)
variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
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

variable "use_minimal_config" {
  description = "Use minimal cloud-init configuration for debugging"
  type        = bool
  default     = false
}

variable "infrastructure_provider" {
  description = "Infrastructure provider identifier"
  type        = string
  default     = "libvirt"
  
  validation {
    condition     = var.infrastructure_provider == "libvirt"
    error_message = "This module only supports infrastructure_provider = 'libvirt'."
  }
}

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
  description = "URL for the base Ubuntu cloud image"
  type        = string
  default     = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
}
