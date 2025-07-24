# Quick Start Guide - Local Testing Infrastructure

This guide will get you up and running with the Torrust Tracker local testing
environment in minutes.

## 🚀 Quick Setup

### 1. Prerequisites Check

Ensure you have a Linux system (Ubuntu 20.04+ recommended) with:

- 4GB+ RAM available
- 30GB+ free disk space
- Virtualization enabled in BIOS

### 2. One-Command Setup

```bash
make dev-setup
```

This will install all required tools:

- KVM/libvirt for virtualization
- OpenTofu for infrastructure management
- Configure user permissions

**Important:** After this command completes, log out and log back in for
group permissions to take effect.

### 3. Configure SSH Access

Edit your SSH public key into the cloud-init configuration:

```bash
# Generate SSH key if needed
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"

# Copy your public key
cat ~/.ssh/torrust_rsa.pub

# Edit the cloud-init file and replace the placeholder SSH key
vim infrastructure/cloud-init/user-data.yaml
```

### 4. Verify Setup

```bash
make test-prereq
```

The output should be something like:

```console
Testing prerequisites...
infrastructure/tests/test-unit-infrastructure.sh prerequisites
[INFO] Testing prerequisites...
[SUCCESS] OpenTofu is installed: OpenTofu v1.10.1
[SUCCESS] libvirtd service is running
[SUCCESS] User has libvirt access
[SUCCESS] Default libvirt network is active
[SUCCESS] KVM support available
```

**If you get libvirt permission errors:**

```bash
# Check if you're in the libvirt group
groups | grep libvirt

# If not, re-add yourself and refresh session
sudo usermod -aG libvirt $USER

# Then either:
# Option 1: Log out and back in
# Option 2: Use newgrp to activate the group
newgrp libvirt

# Option 3: Start a new login shell
exec su -l $USER

# Verify libvirt access
virsh list --all
```

## 🏃 Deploy and Test

### Deploy VM

```bash
# Initialize OpenTofu (first time only)
make init

# Review what will be created
make plan

# Deploy the VM
make apply
```

### Connect to VM

```bash
# SSH into the VM
make ssh
```

### Test Torrust Tracker

Inside the VM:

```bash
# Clone the repository
cd /home/torrust/github/torrust
git clone https://github.com/torrust/torrust-tracker-demo.git
cd torrust-tracker-demo

# Set up environment
cp .env.production .env

# Start services
docker compose up -d

# Check status
docker compose ps
```

### Cleanup

```bash
# Destroy the VM when done
make destroy
```

## 📋 Available Commands

| Command              | Description                                  |
| -------------------- | -------------------------------------------- |
| `make help`          | Show all available commands                  |
| `make test`          | Run complete test suite                      |
| `make apply`         | Deploy VM                                    |
| `make ssh`           | Connect to VM                                |
| `make destroy`       | Remove VM                                    |
| `make status`        | Show infrastructure status                   |
| `make refresh-state` | Refresh Terraform state to detect IP changes |

## 🔧 Troubleshooting

### Common Issues

1. **Permission errors**: Make sure you logged out/in after `make dev-setup`
2. **VM won't start**: Check with `sudo kvm-ok` that virtualization is enabled
3. **SSH connection fails**: VM might still be booting, wait 2-3 minutes
4. **libvirt file ownership errors**: Run `make fix-libvirt` to fix permissions
5. **"No IP assigned yet" issue**: If `make status` shows no IP but VM is running:

   ```bash
   # Check if VM actually has an IP
   virsh domifaddr torrust-tracker-demo

   # If IP is shown, refresh Terraform state
   make refresh-state
   ```

   **Why this happens**: Terraform's state can become stale after cloud-init completes.
   The VM gets its IP from DHCP, but Terraform doesn't automatically detect this change.
   See [detailed troubleshooting](local-testing-setup.md#troubleshooting) for more info.

### Getting Help

```bash
# Fix libvirt permissions automatically
make fix-libvirt

# Check test logs
make logs

# Access VM console directly
make vm-console

# Show detailed workflow help
make workflow-help
```

## 🎯 What's Next?

Once your VM is running:

1. **Deploy Torrust Tracker** - Follow the steps above to get the tracker running
2. **Test functionality** - Try accessing the tracker endpoints
3. **Monitor services** - Check Grafana dashboards
4. **Iterate** - Make changes and redeploy quickly

## 📚 Full Documentation

For detailed information, see:

- [Complete Setup Guide](local-testing-setup.md)
- [Test Documentation](../tests/README.md)

## 🧪 Test Everything

Run the full automated test suite:

```bash
make test
```

This will:

- Verify all prerequisites
- Validate configurations
- Deploy a VM
- Test connectivity and services
- Clean up automatically

Perfect for CI/CD or validating changes!
