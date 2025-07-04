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

# Set password using chpasswd (most reliable method)
chpasswd:
  list: |
    torrust:torrust123
  expire: false

# Enable SSH password authentication for debugging
ssh_pwauth: true

# Write SSH configuration to explicitly enable password auth
write_files:
  - path: /etc/ssh/sshd_config.d/99-cloud-init-debug.conf
    content: |
      PasswordAuthentication yes
      PubkeyAuthentication yes
      AuthenticationMethods publickey password
    permissions: '0644'
    owner: root:root
  - path: /tmp/cloud-init-completed
    content: |
      Cloud-init configuration applied successfully
      Timestamp: $(date)
    permissions: '0644'

# Package updates (minimal)
package_update: true

packages:
  - curl
  - vim

# Commands to run after package installation
runcmd:
  - systemctl restart ssh
  - echo "SSH service restarted at $(date)" >> /tmp/cloud-init-completed

# Minimal final message
final_message: |
  Minimal VM setup completed!
  Ready for SSH access.
