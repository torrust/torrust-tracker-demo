# LibVirt Provider - Terraform Configuration
# Local KVM/libvirt virtualization for development and testing

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7"
    }
  }
}

# Note: Provider configuration is handled at the root level

# Download Ubuntu cloud image
resource "libvirt_volume" "base_image" {
  name   = "${var.vm_name}-ubuntu-24.04-base.qcow2"
  source = var.base_image_url
  format = "qcow2"
  pool   = var.libvirt_pool

  # Fix permissions after creation
  provisioner "local-exec" {
    command = "${path.module}/../../../scripts/fix-volume-permissions.sh"
  }
}

# Create a volume for the VM based on the base image
resource "libvirt_volume" "vm_disk" {
  name           = "${var.vm_name}.qcow2"
  base_volume_id = libvirt_volume.base_image.id
  size           = var.vm_disk_size * 1024 * 1024 * 1024  # Convert GB to bytes
  pool           = var.libvirt_pool

  # Fix permissions after creation
  provisioner "local-exec" {
    command = "${path.module}/../../../scripts/fix-volume-permissions.sh"
  }
}

# Create persistent data volume for application storage
resource "libvirt_volume" "persistent_data" {
  name   = "${var.vm_name}-data.qcow2"
  format = "qcow2"
  size   = var.persistent_data_size * 1024 * 1024 * 1024  # Convert GB to bytes
  pool   = var.libvirt_pool

  # Fix permissions after creation
  provisioner "local-exec" {
    command = "${path.module}/../../../scripts/fix-volume-permissions.sh"
  }
}

# Create cloud-init disk
resource "libvirt_cloudinit_disk" "commoninit" {
  name           = "${var.vm_name}-cloudinit.iso"
  user_data      = templatefile("${path.module}/../../../cloud-init/${var.use_minimal_config ? "user-data-minimal.yaml.tpl" : "user-data.yaml.tpl"}", {
    ssh_public_key = var.ssh_public_key
  })
  meta_data      = templatefile("${path.module}/../../../cloud-init/meta-data.yaml", {
    hostname = var.vm_name
  })
  network_config = file("${path.module}/../../../cloud-init/network-config.yaml")
  pool           = var.libvirt_pool
}

# Create the VM
resource "libvirt_domain" "vm" {
  name   = var.vm_name
  memory = var.vm_memory
  vcpu   = var.vm_vcpus

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  # CPU configuration - use a modern CPU model that supports x86-64-v2
  # Enable modern CPU model for x86-64-v2 instruction set support (required by MySQL 8.0)
  # Reference: https://github.com/docker-library/mysql/issues/1055
  cpu {
    mode = "host-model"
  }

  disk {
    volume_id = libvirt_volume.vm_disk.id
  }

  # Attach persistent data volume as second disk
  disk {
    volume_id = libvirt_volume.persistent_data.id
  }

  network_interface {
    network_name   = var.libvirt_network
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
