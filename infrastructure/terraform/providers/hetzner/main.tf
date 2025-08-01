# Hetzner Cloud Provider Implementation
# This module implements the standard provider interface for Hetzner Cloud

# SSH Key Resource
resource "hcloud_ssh_key" "torrust_key" {
  name       = "${var.vm_name}-key"
  public_key = var.ssh_public_key
}

# Firewall Resource
resource "hcloud_firewall" "torrust_firewall" {
  name = "${var.vm_name}-firewall"

  # SSH Access
  rule {
    direction = "in"
    port      = "22"
    protocol  = "tcp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # HTTP/HTTPS
  rule {
    direction = "in"
    port      = "80"
    protocol  = "tcp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    port      = "443"
    protocol  = "tcp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # Torrust Tracker UDP Ports
  rule {
    direction = "in"
    port      = "6868"
    protocol  = "udp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    port      = "6969"
    protocol  = "udp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # Torrust Tracker HTTP Port
  rule {
    direction = "in"
    port      = "7070"
    protocol  = "tcp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # Torrust Tracker API/Metrics Port
  rule {
    direction = "in"
    port      = "1212"
    protocol  = "tcp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}

# Cloud-init configuration
locals {
  cloud_init_config = templatefile("${path.module}/../../../cloud-init/user-data.yaml.tpl", {
    ssh_public_key = var.ssh_public_key
    vm_name        = var.vm_name
    environment    = var.environment
    use_minimal    = var.use_minimal_config
  })
}

# Server Resource
resource "hcloud_server" "torrust_server" {
  name         = var.vm_name
  image        = var.hetzner_image
  server_type  = var.hetzner_server_type
  location     = var.hetzner_location
  ssh_keys     = [hcloud_ssh_key.torrust_key.id]
  firewall_ids = [hcloud_firewall.torrust_firewall.id]

  user_data = local.cloud_init_config

  labels = {
    environment = var.environment
    purpose     = "torrust-tracker-demo"
    managed_by  = "terraform"
  }

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = false  # Set to true for production
  }
}

# Wait for server to be ready
resource "time_sleep" "wait_for_server" {
  depends_on = [hcloud_server.torrust_server]

  create_duration = "30s"
}

# Data source to get server info after creation
data "hcloud_server" "torrust_server" {
  depends_on = [time_sleep.wait_for_server]
  id         = hcloud_server.torrust_server.id
}
