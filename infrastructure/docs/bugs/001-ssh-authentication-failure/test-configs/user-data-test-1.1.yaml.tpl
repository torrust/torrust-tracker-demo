#cloud-config
# Test 1.1: Change from testuser to torrust user
# Based on minimal config + torrust user configuration

# Basic system configuration
hostname: torrust-tracker-demo
locale: en_US.UTF-8
timezone: UTC

# User configuration - CHANGED: torrust user instead of testuser
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
