# Torrust Tracker Demo - Local Testing Infrastructure
# OpenTofu configuration for KVM/libvirt local testing

terraform {
  required_version = ">= 1.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7"
    }
  }
}

# Configure the libvirt provider
provider "libvirt" {
  uri = "qemu:///system"
}

# Variables
variable "use_minimal_config" {
  description = "Use minimal cloud-init configuration for debugging"
  type        = bool
  default     = false
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  default     = ""
}

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
  description = "Disk size in GB"
  type        = number
  default     = 20
}

variable "base_image_url" {
  description = "URL for the base Ubuntu cloud image"
  type        = string
  default     = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64-disk-kvm.img"
}

# Download Ubuntu cloud image
resource "libvirt_volume" "base_image" {
  name   = "ubuntu-22.04-base.qcow2"
  source = var.base_image_url
  format = "qcow2"
  pool   = "user-default"

  # Fix permissions after creation
  provisioner "local-exec" {
    command = "${path.module}/../scripts/fix-volume-permissions.sh"
  }
}

# Create a volume for the VM based on the base image
resource "libvirt_volume" "vm_disk" {
  name           = "${var.vm_name}.qcow2"
  base_volume_id = libvirt_volume.base_image.id
  size           = var.vm_disk_size * 1024 * 1024 * 1024  # Convert GB to bytes
  pool           = "user-default"

  # Fix permissions after creation
  provisioner "local-exec" {
    command = "${path.module}/../scripts/fix-volume-permissions.sh"
  }
}

# Create cloud-init disk
resource "libvirt_cloudinit_disk" "commoninit" {
  name           = "${var.vm_name}-cloudinit.iso"
  user_data      = templatefile("${path.module}/../cloud-init/${var.use_minimal_config ? "user-data-minimal.yaml.tpl" : "user-data.yaml.tpl"}", {
    ssh_public_key = var.ssh_public_key
  })
  meta_data      = templatefile("${path.module}/../cloud-init/meta-data.yaml", {
    hostname = var.vm_name
  })
  network_config = file("${path.module}/../cloud-init/network-config.yaml")
  pool           = "user-default"
}

# Create the VM
resource "libvirt_domain" "vm" {
  name   = var.vm_name
  memory = var.vm_memory
  vcpu   = var.vm_vcpus

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  disk {
    volume_id = libvirt_volume.vm_disk.id
  }

  network_interface {
    network_name   = "default"
    wait_for_lease = false
  }

  # Console for debugging
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }

  # Boot configuration
  boot_device {
    dev = ["hd", "network"]
  }
}

# Output the VM's IP address
output "vm_ip" {
  value = length(libvirt_domain.vm.network_interface[0].addresses) > 0 ? libvirt_domain.vm.network_interface[0].addresses[0] : "No IP assigned yet"
  description = "IP address of the created VM"
}

output "vm_name" {
  value = libvirt_domain.vm.name
  description = "Name of the created VM"
}

output "connection_info" {
  value = length(libvirt_domain.vm.network_interface[0].addresses) > 0 ? "SSH to VM: ssh torrust@${libvirt_domain.vm.network_interface[0].addresses[0]}" : "VM created, waiting for IP address..."
  description = "SSH connection command"
}
