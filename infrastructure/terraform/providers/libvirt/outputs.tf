# LibVirt Provider - Outputs
# Implements the standard provider interface outputs

# Standard interface outputs (required by all providers)
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

# Provider-specific outputs
output "provider" {
  value = "libvirt"
  description = "Infrastructure provider used"
}

output "vm_id" {
  value = libvirt_domain.vm.id
  description = "LibVirt domain ID"
}

output "vm_disk_id" {
  value = libvirt_volume.vm_disk.id
  description = "Primary disk volume ID"
}

output "persistent_data_id" {
  value = libvirt_volume.persistent_data.id
  description = "Persistent data volume ID"
}

output "network_interface" {
  value = {
    network = libvirt_domain.vm.network_interface[0].network_name
    mac     = libvirt_domain.vm.network_interface[0].mac
  }
  description = "Network interface information"
}
