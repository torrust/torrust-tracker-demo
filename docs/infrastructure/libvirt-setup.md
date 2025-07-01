# libvirt Setup and Troubleshooting Guide

This guide covers the installation, configuration, and troubleshooting of
libvirt for the Torrust Tracker local testing infrastructure.

## 📦 Installation

### Ubuntu/Debian

```bash
# Update package list
sudo apt update

# Install KVM and libvirt packages
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients \
  bridge-utils virt-manager genisoimage

# Add your user to required groups
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER

# Start and enable libvirt service
sudo systemctl enable libvirtd
sudo systemctl start libvirtd
```

### Fedora/RHEL/CentOS

```bash
# Install packages
sudo dnf install -y qemu-kvm libvirt libvirt-daemon-config-network \
  libvirt-daemon-kvm virt-install

# Add user to groups
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER

# Start and enable services
sudo systemctl enable libvirtd
sudo systemctl start libvirtd
```

### Arch Linux

```bash
# Install packages
sudo pacman -S qemu-desktop libvirt virt-manager bridge-utils \
  dnsmasq

# Add user to groups
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER

# Start and enable services
sudo systemctl enable libvirtd
sudo systemctl start libvirtd
```

## ✅ Verification

### Automated Check

```bash
# Use our custom checker
make check-libvirt

# Run prerequisite tests
make test-prereq
```

### Manual Verification

```bash
# 1. Check if KVM is working
sudo kvm-ok

# 2. Check libvirt service status
sudo systemctl status libvirtd

# 3. Verify user permissions (should work without sudo)
virsh list --all

# 4. Check if default network exists and is active
virsh net-list --all

# 5. Verify KVM module is loaded
lsmod | grep kvm

# 6. Check virtualization support
egrep -c '(vmx|svm)' /proc/cpuinfo  # Should return > 0

# 7. Test libvirt connection
virsh uri
```

## 🔧 Common Issues and Fixes

### Issue 1: Permission Denied Errors

**Symptoms:**

```text
error: Failed to connect to socket /var/run/libvirt/libvirt-sock: Permission denied
```

**Solutions:**

```bash
# Check current groups
groups

# Add user to libvirt group if missing
sudo usermod -aG libvirt $USER

# Refresh group membership (choose one):
# Option A: Log out and log back in
# Option B: Start new shell with group
newgrp libvirt
# Option C: Restart login shell
exec su -l $USER

# Verify fix
virsh list --all
```

### Issue 2: libvirtd Service Not Running

**Symptoms:**

```text
error: failed to connect to the hypervisor
```

**Solutions:**

```bash
# Check service status
sudo systemctl status libvirtd

# Start the service
sudo systemctl start libvirtd

# Enable automatic startup
sudo systemctl enable libvirtd

# If it fails to start, check logs
sudo journalctl -u libvirtd -f
```

### Issue 3: Default Network Not Available

**Symptoms:**

```text
error: Network 'default' is not active
```

**Solutions:**

```bash
# Check network status
virsh net-list --all

# Start default network
virsh net-start default

# Enable automatic startup
virsh net-autostart default

# If default network doesn't exist, create it
sudo virsh net-define /etc/libvirt/qemu/networks/default.xml
sudo virsh net-start default
sudo virsh net-autostart default
```

### Issue 4: Missing Default Storage Pool

**Symptoms:**

```text
Error: can't find storage pool 'default'
```

**Solutions:**

```bash
# Check current storage pools
virsh pool-list --all

# If no default pool exists, create it
sudo virsh pool-define-as default dir \
  --target /var/lib/libvirt/images
sudo virsh pool-autostart default
sudo virsh pool-start default

# Verify the pool is active
virsh pool-list --all
```

### Issue 5: Missing mkisofs Command

**Symptoms:**

```text
error while starting the creation of CloudInit's ISO image:
exec: "mkisofs": executable file not found in $PATH
```

**Solutions:**

```bash
# Install genisoimage package (which provides mkisofs)
sudo apt update
sudo apt install -y genisoimage

# Verify mkisofs is available
which mkisofs
mkisofs --version
```

### Issue 6: KVM Not Available

**Symptoms:**

```text
error: KVM is not available
```

**Solutions:**

```bash
# Check if KVM modules are loaded
lsmod | grep kvm

# Load KVM modules manually
sudo modprobe kvm
sudo modprobe kvm_intel  # For Intel CPUs
# OR
sudo modprobe kvm_amd    # For AMD CPUs

# Check CPU virtualization support
egrep -c '(vmx|svm)' /proc/cpuinfo

# If output is 0, virtualization is not supported or not enabled in BIOS
```

### Issue 7: BIOS Virtualization Disabled

**Symptoms:**

- KVM modules won't load
- `/dev/kvm` doesn't exist
- `kvm-ok` reports virtualization disabled

**Solutions:**

1. Reboot and enter BIOS/UEFI settings
2. Look for virtualization options:
   - Intel: "Intel VT-x" or "Virtualization Technology"
   - AMD: "AMD-V" or "SVM Mode"
3. Enable the option
4. Save and reboot

### Issue 8: Nested Virtualization Issues

**Symptoms:**

- Running inside a VM and can't create VMs
- Poor performance in nested VMs

**Solutions:**

```bash
# Check if nested virtualization is enabled
cat /sys/module/kvm_intel/parameters/nested  # Intel
cat /sys/module/kvm_amd/parameters/nested    # AMD

# Enable nested virtualization (Intel)
echo 'options kvm_intel nested=1' | sudo tee /etc/modprobe.d/kvm.conf

# Enable nested virtualization (AMD)
echo 'options kvm_amd nested=1' | sudo tee /etc/modprobe.d/kvm.conf

# Reload modules
sudo modprobe -r kvm_intel && sudo modprobe kvm_intel  # Intel
sudo modprobe -r kvm_amd && sudo modprobe kvm_amd      # AMD
```

### Issue 9: File Ownership Problems in libvirt Images Directory

**Symptoms:**

```text
Error: virError(Code=1, Domain=10, Message='internal error:
process exited while connecting to monitor: ... Permission denied')
```

**Cause:**
Sometimes libvirt downloads or creates VM images with incorrect ownership
(root:root instead of libvirt-qemu:libvirt), causing permission errors
when trying to start VMs.

**Solutions:**

```bash
# Quick fix using Makefile
make fix-libvirt

# Manual fix
sudo chown -R libvirt-qemu:libvirt /var/lib/libvirt/images/
sudo chmod -R 755 /var/lib/libvirt/images/
sudo systemctl restart libvirtd

# Verify ownership is correct
ls -la /var/lib/libvirt/images/
```

**Prevention:**
The `make apply` command now automatically fixes these permissions before
deploying VMs.

### Issue 10: AppArmor Permission Denied Errors

**Symptoms:**

```text
Could not open '/path/to/file.qcow2': Permission denied
error creating libvirt domain: internal error: process exited while
connecting to monitor
```

**Cause:**

AppArmor security policies restrict libvirt-qemu access to storage
directories. This is a common issue with the terraform-provider-libvirt
when using custom storage locations.

**Reference:** [terraform-provider-libvirt Issue #1163](https://github.com/dmacvicar/terraform-provider-libvirt/issues/1163)

**Solutions:**

```bash
# Quick fix using our automated script
make fix-libvirt

# Manual fix - Create AppArmor override
sudo mkdir -p /etc/apparmor.d/abstractions/libvirt-qemu.d

sudo tee /etc/apparmor.d/abstractions/libvirt-qemu.d/override << 'EOF'
# AppArmor override for libvirt-qemu storage access
# Fixes terraform-provider-libvirt permission issues

# Allow access to default libvirt images directory
/var/lib/libvirt/images/** rwk,

# Allow access to user-specific libvirt storage
/home/*/libvirt/images/** rwk,
EOF

# Restart AppArmor to apply changes
sudo systemctl restart apparmor

# Ensure parent directories have execute permissions
chmod o+x /home/$USER
chmod o+x /home/$USER/libvirt
```

**Prevention:**

Our setup scripts automatically create this override to prevent the issue.

## 🚀 Quick Fix Commands

### Automated Fix

```bash
# Use our automated fixer
make fix-libvirt

# Then logout/login or use:
newgrp libvirt

# Verify the fix
make check-libvirt
```

### Manual Fix Script

```bash
#!/bin/bash
# Quick libvirt fix script

echo "Fixing libvirt setup..."

# Install packages (Ubuntu/Debian)
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils

# Add user to groups
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER

# Start services
sudo systemctl enable libvirtd
sudo systemctl start libvirtd

# Start default network
sudo virsh net-start default 2>/dev/null || true
sudo virsh net-autostart default 2>/dev/null || true

echo "Fix completed! Please log out and log back in."
```

## 📋 Diagnostic Commands

```bash
# System information
uname -a
lscpu | grep Virtualization

# Service status
sudo systemctl status libvirtd
sudo systemctl is-enabled libvirtd

# User groups
groups
id $USER

# libvirt version and connection
virsh version
virsh uri
virsh capabilities | head -20

# Network information
virsh net-list --all
ip link show virbr0

# VM information
virsh list --all
virsh pool-list --all

# Log analysis
sudo journalctl -u libvirtd --since "1 hour ago"
```

## 🆘 Emergency Reset

If nothing else works, completely reset libvirt:

```bash
# WARNING: This will destroy all VMs and networks!

# Stop all VMs
for vm in $(virsh list --name); do virsh destroy "$vm"; done

# Stop libvirt
sudo systemctl stop libvirtd

# Remove configuration (backup first!)
sudo cp -r /etc/libvirt /etc/libvirt.backup
sudo rm -rf /var/lib/libvirt/images/*
sudo rm -rf /var/lib/libvirt/qemu/*

# Reinstall packages
sudo apt remove --purge libvirt-daemon-system libvirt-clients
sudo apt install libvirt-daemon-system libvirt-clients

# Restart service
sudo systemctl start libvirtd
sudo systemctl enable libvirtd

# Recreate default network
sudo virsh net-start default
sudo virsh net-autostart default
```

## 📞 Getting Help

If you're still having issues:

1. Check system logs: `sudo journalctl -u libvirtd`
2. Verify hardware: `sudo kvm-ok`
3. Check our test output: `make test-prereq`
4. Review libvirt documentation: `man libvirtd`
5. Check Ubuntu/Debian wiki: [KVM/Installation](https://help.ubuntu.com/community/KVM/Installation)

## 🔍 Related Files

- `/etc/libvirt/qemu.conf` - QEMU configuration
- `/etc/libvirt/libvirtd.conf` - libvirt daemon configuration
- `/var/log/libvirt/` - libvirt logs
- `/var/lib/libvirt/` - libvirt data directory
