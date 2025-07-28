#cloud-config
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
    lock_passwd: true
    ssh_authorized_keys:
      - ${ssh_public_key}

# Disable SSH password authentication for security
ssh_pwauth: false

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
  # NOTE: Rust build dependencies commented out since we're using Docker for all services (see ADR-002)
  # Uncomment the following packages if you need to compile Rust applications (like Torrust Tracker) from source:
  # - pkg-config
  # - libssl-dev
  # - make
  # - build-essential
  # - libsqlite3-dev
  # - sqlite3

# System configuration files
write_files:
  # SSH configuration to enable password authentication
  # Commented out - enable only for debugging/recovery
  # - path: /etc/ssh/sshd_config.d/50-cloud-init.conf
  #   content: |
  #     PasswordAuthentication yes
  #     PubkeyAuthentication yes
  #   permissions: "0644"
  #   owner: root:root

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

  # Install Docker using official method
  # Remove any old Docker packages
  - >
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    apt-get remove -y $pkg || true; done

  # Add Docker's official GPG key
  - mkdir -p /etc/apt/keyrings
  - >
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg
    -o /etc/apt/keyrings/docker.asc
  - chmod a+r /etc/apt/keyrings/docker.asc
  # Add Docker repository
  - >
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Update package index and install Docker
  - apt-get update
  - >
    apt-get install -y docker-ce docker-ce-cli containerd.io
    docker-buildx-plugin docker-compose-plugin

  # Configure Docker
  - systemctl enable docker
  - systemctl start docker
  - usermod -aG docker torrust

  # Verify Docker installation
  - docker --version
  - docker compose version

  # NOTE: Rust installation commented out since we're using Docker for all services (see ADR-002)
  # Uncomment the following section if you need to compile Rust applications from source:
  # # Install Rust using rustup (official method)
  # # Install as torrust user to ensure proper ownership
  # - >
  #   sudo -u torrust bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
  #
  # # Add Rust to PATH for torrust user
  # - >
  #   echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> /home/torrust/.bashrc
  # - >
  #   echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> /home/torrust/.profile
  #
  # # Verify Rust installation
  # - sudo -u torrust bash -c 'source ~/.cargo/env && rustc --version'
  # - sudo -u torrust bash -c 'source ~/.cargo/env && cargo --version'

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

  # Create completion marker for robust cloud-init status detection
  # This file indicates that ALL cloud-init setup tasks have completed successfully
  - echo "Cloud-init setup completed at $(date)" > /var/lib/cloud/torrust-setup-complete
  - chmod 644 /var/lib/cloud/torrust-setup-complete

# Final message
final_message: |
  Torrust Tracker Demo VM setup completed!

  System Information:
  - OS: Ubuntu 24.04 LTS
  - User: torrust (with sudo privileges and SSH key access only)
  - Docker: Installed and configured
  - Firewall: UFW enabled with proper SSH rules
  - Security: Automatic updates enabled
  - Note: All Torrust Tracker services run in Docker containers (see ADR-002)
    Rust build dependencies are commented out but can be enabled if needed

  SSH Access:
  - SSH Key: ssh torrust@VM_IP
  - Password: Disabled for security (can be re-enabled in cloud-init config if needed)

  Next steps:
  1. SSH into the VM as user 'torrust'
  2. Clone the torrust-tracker-demo repository
  3. Run the deployment scripts using Docker Compose

  The VM is ready for Torrust Tracker deployment!

# Power state - reboot after setup
power_state:
  mode: reboot
  message: "Rebooting after initial setup"
  timeout: 60
  condition: true
