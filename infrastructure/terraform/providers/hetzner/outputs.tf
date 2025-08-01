# Hetzner Provider Outputs
# Implements the standard provider interface outputs

# === STANDARD PROVIDER INTERFACE OUTPUTS ===
# These outputs are required by all providers for consistency

output "vm_ip" {
  description = "Public IP address of the virtual machine"
  value       = try(data.hcloud_server.torrust_server.ipv4_address, hcloud_server.torrust_server.ipv4_address, "No IP assigned yet")
}

output "vm_name" {
  description = "Name of the virtual machine"
  value       = hcloud_server.torrust_server.name
}

output "vm_status" {
  description = "Status of the virtual machine"
  value       = try(data.hcloud_server.torrust_server.status, hcloud_server.torrust_server.status, "unknown")
}

output "connection_info" {
  description = "Connection information for the virtual machine"
  value = try(
    data.hcloud_server.torrust_server.ipv4_address != "" ? 
      "SSH: ssh torrust@${data.hcloud_server.torrust_server.ipv4_address}" : 
      "VM created, waiting for IP address...",
    hcloud_server.torrust_server.ipv4_address != "" ?
      "SSH: ssh torrust@${hcloud_server.torrust_server.ipv4_address}" :
      "VM created, waiting for IP address...",
    "VM created, waiting for IP address..."
  )
}

# === HETZNER-SPECIFIC OUTPUTS ===
# Additional outputs specific to Hetzner Cloud

output "server_id" {
  description = "Hetzner server ID"
  value       = hcloud_server.torrust_server.id
}

output "server_type" {
  description = "Hetzner server type used"
  value       = hcloud_server.torrust_server.server_type
}

output "location" {
  description = "Hetzner datacenter location"
  value       = hcloud_server.torrust_server.location
}

output "image" {
  description = "Server image used"
  value       = hcloud_server.torrust_server.image
}

output "ipv6_address" {
  description = "IPv6 address of the server"
  value       = try(data.hcloud_server.torrust_server.ipv6_address, hcloud_server.torrust_server.ipv6_address, "No IPv6 assigned")
}

output "firewall_id" {
  description = "Firewall ID attached to the server"
  value       = hcloud_firewall.torrust_firewall.id
}

output "ssh_key_id" {
  description = "SSH key ID used for the server"
  value       = hcloud_ssh_key.torrust_key.id
}

# === DEBUGGING OUTPUTS ===
# Useful for troubleshooting and monitoring

output "server_info" {
  description = "Complete server information"
  value = {
    id              = hcloud_server.torrust_server.id
    name            = hcloud_server.torrust_server.name
    server_type     = hcloud_server.torrust_server.server_type
    location        = hcloud_server.torrust_server.location
    image           = hcloud_server.torrust_server.image
    status          = try(data.hcloud_server.torrust_server.status, hcloud_server.torrust_server.status, "unknown")
    ipv4_address    = try(data.hcloud_server.torrust_server.ipv4_address, hcloud_server.torrust_server.ipv4_address, "pending")
    ipv6_address    = try(data.hcloud_server.torrust_server.ipv6_address, hcloud_server.torrust_server.ipv6_address, "pending")
    firewall_ids    = hcloud_server.torrust_server.firewall_ids
    ssh_keys        = hcloud_server.torrust_server.ssh_keys
    labels          = hcloud_server.torrust_server.labels
  }
}
