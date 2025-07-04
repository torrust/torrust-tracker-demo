#cloud-config
# Test 8.1: Add fail2ban configuration (SUSPECT TEST)
# Based on Test 7.1 + fail2ban package and basic configuration

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

# Install packages including UFW and fail2ban
packages:
  - curl
  - wget
  - git
  - htop
  - vim
  - net-tools
  - ufw
  - fail2ban

# System configuration files
write_files:
  # SSH configuration to enable password authentication
  - path: /etc/ssh/sshd_config.d/50-cloud-init.conf
    content: |
      PasswordAuthentication yes
      PubkeyAuthentication yes
    permissions: "0644"
    owner: root:root

  # UFW basic configuration
  - path: /etc/ufw/ufw.conf
    content: |
      ENABLED=yes
      LOGLEVEL=low
    permissions: "0644"
    owner: root:root

  # fail2ban configuration
  - path: /etc/fail2ban/jail.local
    content: |
      [DEFAULT]
      # Default ban time (10 minutes)
      bantime = 600
      # Find time window (10 minutes)
      findtime = 600
      # Max retries before ban
      maxretry = 5
      # Backend to use
      backend = systemd
      
      [sshd]
      enabled = true
      port = ssh
      filter = sshd
      logpath = /var/log/auth.log
      maxretry = 5
      bantime = 600
      findtime = 600
    permissions: "0644"
    owner: root:root

# Commands to run after package installation
runcmd:
  # Create torrust user directories
  - mkdir -p /home/torrust/github/torrust
  - chown -R torrust:torrust /home/torrust/github

  # Configure SSH first (restart sshd with new config)
  - systemctl restart sshd
  - systemctl enable ssh

  # CRITICAL: Configure UFW firewall SAFELY (allow SSH BEFORE enabling)
  - ufw --force reset
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow ssh
  - ufw allow 22/tcp
  - ufw --force enable

  # Configure and start fail2ban service
  - systemctl enable fail2ban
  - systemctl start fail2ban

# Final message
final_message: |
  Test 8.1 VM setup completed!
  SSH Access: ssh torrust@VM_IP or sshpass -p 'torrust123' ssh torrust@VM_IP

# Power state - reboot after setup
power_state:
  mode: reboot
  message: "Rebooting after initial setup"
  timeout: 60
  condition: true
