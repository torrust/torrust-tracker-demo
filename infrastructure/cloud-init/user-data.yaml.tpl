---
# cloud-config
# Optimized cloud-init configuration based on manual testing

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

# Install packages (verified working order)
packages:
  - curl
  - wget
  - git
  - htop
  - vim
  - net-tools
  - ca-certificates
  - gnupg
  - lsb-release
  - ufw
  - fail2ban
  - unattended-upgrades
  - docker.io
  # Torrust Tracker dependencies for future source compilation
  # Currently using Docker, but planning to compile from source for better performance
  - pkg-config
  - libssl-dev
  - make
  - build-essential
  - libsqlite3-dev
  - sqlite3

# System configuration files
write_files:
  # SSH configuration to enable password authentication
  - path: /etc/ssh/sshd_config.d/50-cloud-init.conf
    content: |
      PasswordAuthentication yes
      PubkeyAuthentication yes
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

  # UFW basic configuration
  - path: /etc/ufw/ufw.conf
    content: |
      ENABLED=yes
      LOGLEVEL=low
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

  # Configure Docker
  - systemctl enable docker
  - systemctl start docker
  - usermod -aG docker torrust

  # Install Docker Compose V2 plugin (compatible with compose.yaml format)
  - mkdir -p /usr/local/lib/docker/cli-plugins
  - >
    curl -SL
    "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-linux-x86_64"
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  - chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
  - >
    ln -sf /usr/local/lib/docker/cli-plugins/docker-compose
    /usr/local/bin/docker-compose

  # CRITICAL: Configure UFW firewall SAFELY (allow SSH BEFORE enabling)
  - ufw --force reset
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow ssh
  - ufw allow 22/tcp
  - ufw allow 80/tcp
  - ufw allow 443/tcp
  - ufw allow 6868/udp
  - ufw allow 6969/udp
  - ufw allow 7070/tcp
  - ufw allow 1212/tcp
  - ufw --force enable

  # Apply sysctl settings
  - sysctl -p /etc/sysctl.d/99-torrust.conf

  # Configure automatic security updates
  - >
    echo 'Unattended-Upgrade::Automatic-Reboot "false";' >>
    /etc/apt/apt.conf.d/50unattended-upgrades
  - systemctl enable unattended-upgrades
  # Set up log rotation for Docker
  - systemctl restart docker

# Final message
final_message: |
  Torrust Tracker Demo VM setup completed!

  System Information:
  - OS: Ubuntu 22.04 LTS
  - User: torrust (with sudo privileges and password login)
  - Docker: Installed and configured
  - Firewall: UFW enabled with proper SSH rules
  - Security: Automatic updates enabled
  - Torrust Tracker dependencies: pkg-config, libssl-dev, make, build-essential, libsqlite3-dev, sqlite3
    (for future source compilation)

  SSH Access:
  - SSH Key: ssh torrust@VM_IP
  - Password: sshpass -p 'torrust123' ssh torrust@VM_IP

  Next steps:
  1. SSH into the VM as user 'torrust'
  2. Clone the torrust-tracker-demo repository
  3. Run the deployment scripts

  The VM is ready for Torrust Tracker deployment!

# Power state - reboot after setup
power_state:
  mode: reboot
  message: "Rebooting after initial setup"
  timeout: 60
  condition: true
