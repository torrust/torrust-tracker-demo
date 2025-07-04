#cloud-config
# Test 11.1: Add unattended-upgrades configuration (SUSPECT TEST)
# Based on Test 10.1 + unattended-upgrades package and configuration

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

# Install packages including UFW, fail2ban, Docker, and unattended-upgrades
packages:
  - curl
  - wget
  - git
  - htop
  - vim
  - net-tools
  - ufw
  - fail2ban
  - docker.io
  - ca-certificates
  - gnupg
  - lsb-release
  - unattended-upgrades

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

  # Docker daemon configuration
  - path: /etc/docker/daemon.json
    content: |
      {
        "log-driver": "json-file",
        "log-opts": {
          "max-size": "10m",
          "max-file": "3"
        }
      }
    permissions: "0644"
    owner: root:root

  # Sysctl optimizations for network performance
  - path: /etc/sysctl.d/99-torrust.conf
    content: |
      # Network optimizations for BitTorrent tracker
      net.core.rmem_max = 268435456
      net.core.wmem_max = 268435456
      net.core.netdev_max_backlog = 5000
      net.ipv4.tcp_rmem = 4096 65536 16777216
      net.ipv4.tcp_wmem = 4096 65536 16777216
      net.ipv4.tcp_congestion_control = bbr
      net.ipv4.ip_local_port_range = 1024 65535
      net.core.somaxconn = 1024
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

  # Configure Docker
  - systemctl enable docker
  - systemctl start docker
  - usermod -aG docker torrust

  # Install Docker Compose V2 plugin
  - mkdir -p /usr/local/lib/docker/cli-plugins
  - >
    curl -SL
    "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-linux-x86_64"
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  - chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
  - >
    ln -sf /usr/local/lib/docker/cli-plugins/docker-compose
    /usr/local/bin/docker-compose

  # Apply sysctl settings
  - sysctl -p /etc/sysctl.d/99-torrust.conf

  # Configure automatic security updates (NEW - SUSPECT)
  - >
    echo 'Unattended-Upgrade::Automatic-Reboot "false";' >>
    /etc/apt/apt.conf.d/50unattended-upgrades
  - systemctl enable unattended-upgrades

# Final message
final_message: |
  Test 11.1 VM setup completed!
  SSH Access: ssh torrust@VM_IP or sshpass -p 'torrust123' ssh torrust@VM_IP

# Power state - reboot after setup
power_state:
  mode: reboot
  message: "Rebooting after initial setup"
  timeout: 60
  condition: true
