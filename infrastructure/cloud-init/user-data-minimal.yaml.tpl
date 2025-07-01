# cloud-config
# Minimal cloud-init configuration for debugging

# Basic system configuration
hostname: torrust-tracker-demo
locale: en_US.UTF-8
timezone: UTC

# User configuration
users:
  - name: torrust
    groups: [adm, sudo]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
    ssh_authorized_keys:
      - ${ssh_public_key}

# Package updates (minimal)
package_update: true

packages:
  - curl
  - vim

# Minimal final message
final_message: |
  Minimal VM setup completed!
  Ready for SSH access.
