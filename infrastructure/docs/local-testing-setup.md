# Local Testing Infrastructure Setup

This document describes how to set up a local testing environment for the
Torrust Tracker using OpenTofu and cloud-init with KVM/libvirt virtualization.

## Prerequisites

### System Requirements

- Linux system (Ubuntu 20.04+ or similar)
- At least 4GB RAM (2GB will be allocated to the VM)
- 30GB free disk space
- Virtualization support enabled in BIOS/UEFI

### Required Tools Installation

#### 1. Install KVM/libvirt

**Quick installation:**

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager

# Add your user to libvirt group
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER

# Start and enable libvirt service
sudo systemctl enable libvirtd
sudo systemctl start libvirtd

# Log out and log back in for group changes to take effect
```

**For detailed instructions, troubleshooting, and other distributions, see:**
[libvirt Setup Guide](libvirt-setup.md)

#### 2. Install OpenTofu

```bash
# Download and install OpenTofu
curl -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh
chmod +x install-opentofu.sh
sudo ./install-opentofu.sh --install-method deb

# Verify installation
tofu version
```

#### 3. Verify KVM Setup

```bash
# Check if KVM is working
sudo kvm-ok

# Check libvirt status
sudo systemctl status libvirtd

# Verify user permissions (should work without sudo after group setup)
virsh list --all

# If the above fails, try with sudo to verify libvirt is working
sudo virsh list --all

# Check if default network exists and is active
virsh net-list --all

# If default network is not active, start it
virsh net-start default
virsh net-autostart default

# Verify KVM module is loaded
lsmod | grep kvm

# Check virtualization support
egrep -c '(vmx|svm)' /proc/cpuinfo  # Should return > 0

# Test libvirt connection
virsh uri
```

**Troubleshooting libvirt group permissions:**

If `virsh list` fails with permission errors:

```bash
# Check current groups
groups

# If libvirt group is not listed, re-add user and refresh session
sudo usermod -aG libvirt $USER

# Option 1: Log out and log back in
# Option 2: Start new shell with libvirt group
newgrp libvirt

# Option 3: Restart session
exec su -l $USER
```

## Configuration

### 1. SSH Key Setup

Before deploying, you need to add your SSH public key to the cloud-init configuration:

```bash
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"

# Copy your public key
cat ~/.ssh/id_rsa.pub
```

Edit `infrastructure/cloud-init/user-data.yaml` and replace the placeholder SSH
key with your actual public key.

### 2. Customize VM Configuration (Optional)

You can customize the VM specifications by editing variables in
`infrastructure/terraform/main.tf` or creating a `terraform.tfvars` file:

```hcl
# infrastructure/terraform/terraform.tfvars
vm_name     = "torrust-tracker-test"
vm_memory   = 4096  # 4GB RAM
vm_vcpus    = 4     # 4 CPU cores
vm_disk_size = 30   # 30GB disk
```

## Deployment

### 1. Initialize OpenTofu

```bash
cd infrastructure/terraform
tofu init
```

### 2. Plan the Deployment

```bash
tofu plan
```

### 3. Deploy the VM

```bash
tofu apply
```

The deployment will:

- Download Ubuntu 22.04 cloud image
- Create a VM with specified resources
- Apply cloud-init configuration
- Set up basic system requirements
- Install Docker and configure firewall

### 4. Connect to the VM

After deployment completes, OpenTofu will output the VM's IP address:

```bash
# SSH to the VM (replace IP with actual IP from output)
ssh torrust@<VM_IP>
```

## VM Features

The deployed VM includes:

### System Configuration

- Ubuntu 22.04 LTS
- User `torrust` with sudo privileges
- SSH key authentication
- Automatic security updates enabled

### Software Installed

- Docker and Docker Compose
- Basic development tools (git, curl, vim, htop)
- Network utilities
- UFW firewall (configured)
- Fail2ban for SSH protection

### Network Configuration

- UFW firewall enabled with rules for:
  - SSH (22/tcp)
  - HTTP (80/tcp) and HTTPS (443/tcp)
  - Torrust Tracker ports (6868/udp, 6969/udp, 7070/tcp, 1212/tcp)
  - See [detailed port documentation](../../application/docs/firewall-requirements.md#torrust-tracker-ports)

### Performance Optimizations

- Network tuning for BitTorrent traffic
- Docker logging configured
- BBR congestion control enabled

## Post-Deployment Steps

### 1. Clone the Repository

```bash
ssh torrust@<VM_IP>
cd /home/torrust/github/torrust
git clone https://github.com/torrust/torrust-tracker-demo.git
cd torrust-tracker-demo
```

### 2. Set up Environment

```bash
# Copy and configure environment file
cp .env.production .env.local
# Edit .env.local as needed
```

### 3. Deploy Torrust Tracker

```bash
# Start the services
docker compose up -d
```

## Management Commands

### VM Lifecycle

```bash
# Start VM
virsh start torrust-tracker-demo

# Stop VM
virsh shutdown torrust-tracker-demo

# Force stop VM
virsh destroy torrust-tracker-demo

# Check VM status
virsh list --all

# Get VM info
virsh dominfo torrust-tracker-demo
```

### OpenTofu Management

```bash
# Show current state
tofu show

# Destroy infrastructure
tofu destroy

# Refresh state
tofu refresh
```

## Troubleshooting

### Common Issues

1. **libvirt permission errors**

   - Ensure your user is in the `libvirt` and `kvm` groups
   - Log out and log back in after adding groups

2. **AppArmor blocking libvirt-qemu (Permission denied errors)**

   - **Symptoms**: `Could not open '/path/to/file.qcow2': Permission denied`
   - **Root cause**: AppArmor security policies restrict libvirt-qemu access
     to storage directories
   - **Solution**: Create AppArmor override (automatically done by our setup scripts)

   ```bash
   # Manual fix if needed:
   sudo mkdir -p /etc/apparmor.d/abstractions/libvirt-qemu.d
   sudo tee /etc/apparmor.d/abstractions/libvirt-qemu.d/override << 'EOF'
   # AppArmor override for libvirt-qemu storage access
   # Fixes terraform-provider-libvirt permission issues
   /var/lib/libvirt/images/** rwk,
   /home/*/libvirt/images/** rwk,
   EOF
   sudo systemctl restart apparmor

   # Ensure parent directories have execute permissions
   chmod o+x /home/$USER
   chmod o+x /home/$USER/libvirt
   ```

3. **VM fails to start**

   - Check libvirt logs: `journalctl -u libvirtd`
   - Verify KVM support: `sudo kvm-ok`

4. **Cloud-init not working**

   - Check cloud-init logs in VM: `sudo cloud-init status --long`
   - Verify cloud-init files syntax

5. **SSH connection refused**

   - VM might still be booting/configuring
   - Check VM console: `virsh console torrust-tracker-demo` or `virt-viewer spice://127.0.0.1:5900`
   - Verify firewall rules

6. **VM deployment timeout (can't get IP address)**
   - **Symptoms**: VM starts but times out waiting for DHCP lease
   - **Cause**: Cloud-init setup takes time (package installation, system
     configuration, reboot)
   - **Solution**: This is normal; VM will get IP after cloud-init completes
     (~5-10 minutes)
   - **Check**: Use `virsh console torrust-tracker-demo` or
     `virt-viewer spice://127.0.0.1:5900` to monitor boot progress

### Logs and Debugging
