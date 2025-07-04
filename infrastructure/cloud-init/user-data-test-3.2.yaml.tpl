#cloud-config
# Test 3.2: Add SSH service restart commands
# Based on Test 3.1 + SSH service restart

# Basic system configuration
hostname: torrust-tracker-demo
locale: en_US.UTF-8
timezone: UTC

# User configuration
users:
  - name: torrust
    groups:
      [
        adm,
        audio,
        cdrom,
        dialout,
        dip,
        floppy,
        lxd,
        netdev,
        plugdev,
        sudo,
        video,
      ]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
    lock_passwd: false
    ssh_authorized_keys:
      - ${ssh_public_key}

# Set password using chpasswd (most reliable method)
chpasswd:
  list: |
    torrust:torrust123
  expire: false

# Enable SSH password authentication for debugging
ssh_pwauth: true

# Package updates and installations
package_update: true
package_upgrade: true

# Install basic packages
packages:
  - curl
  - wget
  - git
  - htop
  - vim
  - net-tools

# System configuration files
write_files:
  # SSH configuration to enable password authentication
  - path: /etc/ssh/sshd_config.d/50-cloud-init.conf
    content: |
      PasswordAuthentication yes
      PubkeyAuthentication yes
    permissions: "0644"
    owner: root:root

# Commands to run after package installation - ADDED
runcmd:
  # Create torrust user directories - ADDED
  - mkdir -p /home/torrust/github/torrust
  - chown -R torrust:torrust /home/torrust/github

  # Configure SSH first (restart sshd with new config) - ADDED
  - systemctl restart sshd
  - systemctl enable ssh
