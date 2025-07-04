# Integration Testing Guide

This guide provides step-by-step instructions for running complete integration
tests on a fresh virtual machine. All commands are ready to copy and paste.

## Overview

This guide will walk you through:

1. Creating a fresh VM by cleaning up any existing infrastructure
2. Deploying the VM with full Torrust Tracker configuration
3. Waiting for cloud-init to complete (critical step!)
4. Running comprehensive integration tests
5. Verifying all services work correctly
6. Cleaning up resources

**Total Time**: ~8-12 minutes (improved from previous connectivity issues)

---

## Prerequisites

Ensure you have completed the initial setup:

```bash
# Verify prerequisites are met
make test-prereq
```

**Expected Output**: All checks should pass with ✅ marks.

---

## Step 1: Clean Up and Prepare Fresh Environment

### 1.1 Navigate to Project Directory

For example:

```bash
cd /home/yourname/Documents/git/committer/me/github/torrust/torrust-tracker-demo
```

**⚠️ Important**: All commands in this guide assume you are running from the
project root directory. If you see "command not found" errors, verify you are
in the correct directory.

### 1.2 Check for Existing Resources

⚠️ **WARNING**: The following commands will destroy existing VMs and remove
data. Only proceed if you want to start with a completely clean environment.

```bash
# Check for existing VMs that might conflict
virsh list --all | grep torrust-tracker-demo || echo "✅ No conflicting VM found"

# Check for existing libvirt volumes
virsh vol-list user-default 2>/dev/null | grep torrust-tracker-demo || \
  echo "✅ No conflicting volumes found"

# Check for existing OpenTofu state
ls -la infrastructure/terraform/terraform.tfstate* 2>/dev/null || \
  echo "✅ No existing state files"
```

**Expected Output**: Should show "✅" messages if no conflicts exist.

### 1.3 Clean Up Any Existing Infrastructure

⚠️ **DESTRUCTIVE OPERATION**: This will permanently delete VMs, volumes,
and state files.

```bash
# Complete cleanup - removes VMs, state files, and fixes permissions
time make clean-and-fix
```

**Expected Output**:

- VMs destroyed and undefined
- OpenTofu state files removed
- libvirt images cleaned
- Permissions fixed
- **Time**: ~5 seconds (actual: 5.02s)

**What This Creates**: Clean slate with no VMs or state files.

### 1.4 Verify Clean State

```bash
# Verify no conflicting resources remain
echo "=== Verifying Clean State ==="

# Check VMs
virsh list --all | grep torrust-tracker-demo && \
  echo "❌ VM still exists!" || echo "✅ No VM conflicts"

# Check volumes in user-default pool
virsh vol-list user-default 2>/dev/null | grep torrust-tracker-demo && \
  echo "❌ Volumes still exist!" || echo "✅ No volume conflicts"

# Check OpenTofu state
ls infrastructure/terraform/terraform.tfstate* 2>/dev/null && \
  echo "❌ State files still exist!" || echo "✅ No state file conflicts"
```

**Expected Output**: All checks should show "✅" (no conflicts).


### 1.4.1 Manual Cleanup (if needed)

If the verification step shows "❌ Volumes still exist!" then manually clean them:

```bash
# List conflicting volumes
virsh vol-list user-default 2>/dev/null | grep torrust-tracker-demo

# Delete each volume manually
virsh vol-delete torrust-tracker-demo-cloudinit.iso user-default
virsh vol-delete torrust-tracker-demo.qcow2 user-default

# Verify cleanup
virsh vol-list user-default 2>/dev/null | grep torrust-tracker-demo && \
  echo "❌ Volumes still exist!" || echo "✅ No volume conflicts"
```

**Expected Output**: Should show "✅ No volume conflicts" after manual cleanup.

**What This Fixes**: Removes leftover volumes that `make clean-and-fix` sometimes misses.

### 1.5 Set Up SSH Key Configuration

⚠️ **CRITICAL STEP**: This step was **missing** from our initial testing and
caused SSH connection failures!

#### For Default SSH Keys (id_rsa)

```bash
# Set up SSH key configuration for VM access
time make setup-ssh-key
```

#### For Non-Default SSH Keys (e.g., torrust_rsa)

⚠️ **IMPORTANT**: If you're using a non-default SSH key file (e.g.,
`~/.ssh/torrust_rsa` instead of `~/.ssh/id_rsa`), you need to:

1. **Configure the public key in terraform**:

```bash
# Get your non-default public key
cat ~/.ssh/torrust_rsa.pub

# Manually edit the terraform configuration
vim infrastructure/terraform/local.tfvars

# Add your public key content:
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC... your-key-here"
```

1. **Configure SSH client to use the correct private key**:

```bash
# Option 1: Create/edit SSH config
echo "Host 192.168.122.*
    IdentityFile ~/.ssh/torrust_rsa
    IdentitiesOnly yes" >> ~/.ssh/config

# Option 2: Always specify key explicitly when connecting
# ssh -i ~/.ssh/torrust_rsa torrust@VM_IP
```

**Expected Output** (for both methods):

```console
Creating local SSH key configuration...

✓ Created infrastructure/terraform/local.tfvars

Next steps:
1. Get your SSH public key:
   cat ~/.ssh/id_rsa.pub
   # or cat ~/.ssh/torrust_rsa.pub

2. Edit the file and replace the placeholder:
   vim infrastructure/terraform/local.tfvars

3. Deploy the VM:
   make apply
```

**What This Creates**: `infrastructure/terraform/local.tfvars` with SSH key
configuration.

**Verify Configuration**:

```bash
# Ensure the file contains your actual public key (not placeholder)
cat infrastructure/terraform/local.tfvars | grep ssh_public_key

# Should show your full public key, not "REPLACE_WITH_YOUR_SSH_PUBLIC_KEY"
```

### 1.6 Initialize OpenTofu

```bash
# Initialize OpenTofu providers
time make init
```

**Expected Output**:

- Provider plugins downloaded
- Lock file created
- "OpenTofu has been successfully initialized!" message
- **Time**: ~3 seconds (actual: 3.11s)

**What This Creates**: `.terraform.lock.hcl` file in `infrastructure/terraform/`

---

## Step 2: Deploy Fresh Virtual Machine

### 2.1 Plan the Deployment

```bash
# Review what will be created
time make plan
```

**Expected Output**:

- Plan to create 4 resources:
  - `libvirt_volume.base_image` (Ubuntu cloud image)
  - `libvirt_volume.vm_disk` (VM disk)
  - `libvirt_cloudinit_disk.commoninit` (cloud-init configuration)
  - `libvirt_domain.vm` (the actual VM)
- **Time**: ~1 second (actual: 0.63s)

**What This Shows**: Infrastructure plan without making changes.

### 2.2 Deploy the VM

```bash
# Deploy VM with full configuration (this takes time!)
time make apply
```

**Expected During Deployment**:

1. Libvirt permissions check and fixes
2. Download of Ubuntu 22.04 cloud image (~600MB)
3. VM disk creation
4. Cloud-init ISO creation
5. VM startup

**Expected Output**:

- Resources created successfully
- VM IP address in outputs (may show "No IP assigned yet" initially)
- **Time**: ~5 seconds (actual: 4.92s for VM creation after image cached)

**Common Errors and Solutions**:

- "storage volume 'torrust-tracker-demo-cloudinit.iso' exists already"
  Run: `virsh vol-delete torrust-tracker-demo-cloudinit.iso user-default`
- "Inconsistent dependency lock file" → Run: `make init` to reinitialize

**What This Creates**:

- Running VM named `torrust-tracker-demo`
- VM disk and cloud-init ISO in libvirt storage
- OpenTofu state file with VM information

### 2.3 Verify VM is Running

```bash
# Check VM status
virsh list --all
```

**Expected Output**:

```console
 Id   Name                   State
--------------------------------------
 1    torrust-tracker-demo   running
```

---

## Step 3: Wait for Cloud-Init Completion (Critical!)

**⏱️ Timing Update**: Based on recent testing, cloud-init completes much faster
than originally estimated. The VM is typically ready for SSH connections within
2-3 minutes. Previous issues were caused by firewall configuration blocking SSH
connections during cloud-init, preventing proper completion. The firewall setup
has been improved to allow SSH access throughout the process.

### 3.1 Get VM IP Address

```bash
# Get IP from libvirt (more reliable during cloud-init)
VM_IP=$(virsh domifaddr torrust-tracker-demo | grep ipv4 | \
        awk '{print $4}' | cut -d'/' -f1)
echo "VM IP: $VM_IP"
```

**Expected Output**: IP address like `192.168.122.XXX`

### 3.2 Debug Cloud-Init Issues (When SSH Fails)

If SSH connections are failing after 5+ minutes, use these debugging
techniques based on [cloud-init debugging documentation](https://cloudinit.readthedocs.io/en/latest/howto/debugging.html):

#### Access VM Console

```bash
# Method 1: Connect to VM console via virsh (text-based)
virsh console torrust-tracker-demo

# Login as 'ubuntu' (default user) with no password, then:
sudo cloud-init status --long
sudo cat /var/log/cloud-init.log | tail -20
sudo cat /var/log/cloud-init-output.log | tail -20
sudo systemctl status cloud-init-local cloud-init cloud-config cloud-final

# Exit console: Ctrl+]
```

**Method 2: Use virt-viewer for graphical console access**

```bash
# Connect to VM graphical console (shows login prompt)
virt-viewer spice://127.0.0.1:5900

# Alternative using VM name
virt-viewer torrust-tracker-demo
```

**Note**: The virt-viewer method provides a graphical console where you should see a login prompt. This is particularly useful when the text-based virsh console doesn't work or when you need to see the full boot process.

#### Check from Host System

```bash
# Check if SSH port is responding
timeout 5 nc -zv $VM_IP 22

# Check VM system status
virsh dominfo torrust-tracker-demo

# Check VM console output
virsh console torrust-tracker-demo --force
```

#### Minimal Configuration Testing

If cloud-init takes too long, test with minimal configuration:

```bash
# Backup original configuration
cp infrastructure/cloud-init/user-data.yaml.tpl infrastructure/cloud-init/user-data.yaml.tpl.backup

# Use minimal configuration (edit manually or restore from backup)
# Then redeploy:
make destroy && make apply
```

### 3.3 Monitor Cloud-Init Progress

Cloud-init typically completes in 2-3 minutes because it:

- Downloads and installs 15+ packages (Docker, git, htop, ufw, fail2ban, etc.)
- Configures firewall with multiple rules
- Sets up system optimizations
- Creates directory structures
- May reboot the system for clean state

**Note**: Previous versions of this guide estimated 5-10 minutes, but the issue
was firewall configuration blocking SSH access during cloud-init. The improved
firewall setup now allows SSH connections throughout the process, enabling
faster and more reliable completion.

```bash
# Monitor cloud-init in real-time (opens in separate terminal)
make monitor-cloud-init &

# OR manually check SSH connectivity every 30 seconds
while true; do
    echo "$(date): Testing SSH to $VM_IP..."
    if timeout 10 ssh -o StrictHostKeyChecking=no \
       -o ConnectTimeout=10 torrust@$VM_IP \
       "echo 'SSH works!'" 2>/dev/null; then
        echo "✅ SSH connection successful!"
        break
    fi
    echo "⏳ Cloud-init still running... waiting 30 seconds"
    sleep 30
done
```

**Expected Behavior**:

- SSH connections will fail initially with "Connection refused" or
  "Permission denied"
- After 2-3 minutes, SSH will start working (faster if no reboot is required)
- **Time**: ~2-3 minutes for full cloud-init completion

### 3.3 Verify Cloud-Init Completion

```bash
# Check cloud-init final status
ssh -o StrictHostKeyChecking=no torrust@$VM_IP "cloud-init status --long"
```

**Expected Output**:

```console
status: done
time: [timestamp]
detail: DataSource DataSourceNoCloud [seed=/dev/sr0][dsmode=net]
```

### 3.4 Verify VM Configuration

```bash
# Test basic VM readiness
echo "=== Testing VM Configuration ==="

# Check Docker installation
ssh torrust@$VM_IP "docker --version"
ssh torrust@$VM_IP "docker compose version || docker-compose --version"

# Check firewall status
ssh torrust@$VM_IP "sudo ufw status"

# Check if directories are created
ssh torrust@$VM_IP "ls -la /home/torrust/github/"

# Check system packages
ssh torrust@$VM_IP "which git curl wget htop"
```

**Expected Output**:

- Docker version information
- Docker Compose version information (V2 plugin preferred, standalone
  version also supported)
- UFW firewall showing "Status: active" with configured rules
- `/home/torrust/github/torrust` directory exists
- All system packages available

**What This Verifies**: VM is fully configured and ready for integration tests.

**Note**: The cloud-init configuration now installs Docker Compose V2 plugin
for better compatibility with modern compose.yaml files.

---

## Step 4: Run Integration Tests

### 4.1 Test VM Access

```bash
# Test basic VM connectivity
time ./infrastructure/tests/test-integration.sh access
```

**Expected Output**:

- SSH connectivity test passes
- VM accessible message
- **Time**: ~5 seconds

### 4.2 Test Docker Installation

```bash
# Test Docker functionality
time ./infrastructure/tests/test-integration.sh docker
```

**Expected Output**:

- Docker version check passes
- Docker Compose version check passes (automatically detects V2 plugin or
  standalone version)
- **Time**: ~10 seconds

**Note**: The test script automatically detects whether Docker Compose V2
plugin (`docker compose`) or standalone version (`docker-compose`) is
available and uses the appropriate command.

### 4.3 Setup Torrust Tracker Demo

```bash
# Clone and setup the Torrust Tracker repository
time ./infrastructure/tests/test-integration.sh setup
```

**Expected Output**:

- Repository cloned to `/home/torrust/github/torrust/torrust-tracker-demo`
- Environment file `.env` created from `.env.production`
- **Time**: ~30 seconds

**What This Creates**: Torrust Tracker Demo repository with environment
configuration.

### 4.4 Start Torrust Tracker Services

```bash
# Pull images and start all services
time ./infrastructure/tests/test-integration.sh start
```

**Expected Output**:

- Docker images pulled successfully
- All services started in background
- Service status showing all containers running
- **Time**: ~2-3 minutes (pulling images)

**What This Creates**: Running Docker stack with:

- Torrust Tracker (HTTP and UDP)
- Prometheus (metrics collection)
- Grafana (monitoring dashboard)
- Nginx (reverse proxy)

### 4.5 Test Service Endpoints

```bash
# Test all API endpoints
time ./infrastructure/tests/test-integration.sh endpoints
```

**Expected Output**:

- HTTP API responding on port 7070
- Metrics endpoint responding on port 1212
- UDP ports listening (6868, 6969)
- **Time**: ~15 seconds

### 4.6 Test Monitoring Services

```bash
# Test Prometheus and Grafana
time ./infrastructure/tests/test-integration.sh monitoring
```

**Expected Output**:

- Prometheus health check passes
- Grafana health check passes
- **Time**: ~10 seconds

### 4.7 Run Complete Integration Test Suite

```bash
# Run all tests in sequence
time ./infrastructure/tests/test-integration.sh full-test
```

**Expected Output**:

- All individual tests pass in sequence
- Services stopped cleanly at the end
- "All integration tests passed!" message
- **Time**: ~3-5 minutes total

**What This Verifies**: Complete end-to-end functionality of the Torrust
Tracker deployment.

---

## Step 5: Manual Verification (Optional)

### 5.1 SSH Into VM and Explore

```bash
# Connect to VM for manual inspection
make ssh
```

**Inside the VM, you can run**:

```bash
# Check cloud-init logs
sudo cat /var/log/cloud-init-output.log | tail -20

# Check running services
docker compose ps

# Check service logs
docker compose logs --tail=20

# Check system status
sudo systemctl status docker
sudo ufw status verbose

# Check Torrust Tracker logs
docker compose logs torrust-tracker --tail=20

# Exit the VM
exit
```

### 5.2 Test External Access (from Host)

```bash
# Get VM IP for external testing
VM_IP=$(cd infrastructure/terraform && tofu output -raw vm_ip)
echo "VM IP: $VM_IP"

# Test HTTP API from host
curl -s http://$VM_IP:7070/api/v1/stats | jq . || echo "API test failed"

# Test metrics endpoint from host
curl -s http://$VM_IP:1212/metrics | head -10
```

**Expected Output**:

- JSON response from stats API
- Prometheus metrics data

---

## Step 6: Performance and Load Testing (Optional)

### 6.1 Measure Service Response Times

```bash
# Test API response time
ssh torrust@$VM_IP \
  "time curl -s http://localhost:7070/api/v1/stats >/dev/null"

# Test metrics response time
ssh torrust@$VM_IP \
  "time curl -s http://localhost:1212/metrics >/dev/null"

# Test multiple concurrent requests
ssh torrust@$VM_IP \
  "for i in {1..10}; do \
    curl -s http://localhost:7070/api/v1/stats >/dev/null & \
  done; wait"
```

### 6.2 Check Resource Usage

```bash
# Monitor system resources
ssh torrust@$VM_IP "top -b -n1 | head -20"
ssh torrust@$VM_IP "df -h"
ssh torrust@$VM_IP "free -h"
ssh torrust@$VM_IP "docker stats --no-stream"
```

---

## Step 7: Cleanup

### 7.1 Stop Services (if needed)

```bash
# Stop all services cleanly
./infrastructure/tests/test-integration.sh stop
```

### 7.2 Destroy VM and Clean Up

```bash
# Destroy the VM and clean up resources
time make destroy
```

**Expected Output**:

- All resources destroyed
- State files cleaned
- **Time**: ~30 seconds

### 7.3 Final Cleanup

```bash
# Complete cleanup
make clean
```

**Expected Output**:

- Temporary files removed
- Lock files cleaned

---

## Troubleshooting

### Resource Conflicts During Deployment

#### Cloud-init ISO Already Exists

```bash
# Check if cloud-init ISO exists
virsh vol-list user-default | grep cloudinit

# Remove the conflicting cloud-init ISO
virsh vol-delete torrust-tracker-demo-cloudinit.iso user-default

# Then retry: make apply
```

#### OpenTofu State Conflicts

```bash
# If you get "Inconsistent dependency lock file"
make init

# If you get state conflicts, clean and restart
make clean-and-fix
make init
make apply
```

#### VM Already Exists

```bash
# Check existing VMs
virsh list --all | grep torrust-tracker-demo

# Force cleanup if VM exists but not in OpenTofu state
virsh destroy torrust-tracker-demo
virsh undefine torrust-tracker-demo
virsh vol-delete torrust-tracker-demo.qcow2 user-default
```

### Common Issues and Solutions

#### SSH Connection Fails

**MOST COMMON CAUSES**:

1. **Missing SSH key configuration**:

```bash
# Check if SSH key was configured
cat infrastructure/terraform/local.tfvars

# If file doesn't exist or contains "REPLACE_WITH_YOUR_SSH_PUBLIC_KEY":
make setup-ssh-key
# Then redeploy: make destroy && make apply
```

1. **Using non-default SSH key** (e.g., `torrust_rsa` instead of `id_rsa`):

```bash
# Check which keys exist
ls -la ~/.ssh/

# Check which key is configured in VM
grep ssh_public_key infrastructure/terraform/local.tfvars

# Test with explicit key specification
ssh -i ~/.ssh/torrust_rsa -o StrictHostKeyChecking=no torrust@$VM_IP "echo 'Test'"

# Configure SSH client permanently
echo "Host 192.168.122.*
    IdentityFile ~/.ssh/torrust_rsa
    IdentitiesOnly yes" >> ~/.ssh/config
```

1. **Cloud-init still running**:

```bash
# Check if cloud-init is still running
virsh console torrust-tracker-demo --force
# Press Ctrl+] to exit console

# Check VM IP again
virsh domifaddr torrust-tracker-demo

# Test SSH port availability
timeout 5 nc -zv $VM_IP 22

# Wait longer - cloud-init typically completes in 2-3 minutes
# but may take up to 5 minutes in some cases
```

#### Services Don't Start

```bash
# SSH into VM and check Docker
ssh torrust@$VM_IP "docker ps -a"

# Check Docker Compose logs (try both commands)
ssh torrust@$VM_IP "cd /home/torrust/github/torrust/torrust-tracker-demo && \
  docker compose logs || docker-compose logs"

# Check if Docker daemon is running
ssh torrust@$VM_IP "sudo systemctl status docker"

# Verify Docker Compose version compatibility
ssh torrust@$VM_IP "docker compose version || docker-compose --version"
```

**Common Docker Compose Issues**:

- **"compose.yaml format not supported"**: This indicates an older docker-compose
  version. The integration tests automatically detect and use the correct command.
- **"docker: 'compose' is not a docker command"**: VM has standalone docker-compose
  instead of Docker Compose V2 plugin. Both are supported.

#### Integration Tests Fail

```bash
# Check test logs
cat /tmp/torrust-integration-test.log

# Collect system logs
ssh torrust@$VM_IP \
  "sudo journalctl --since='1 hour ago' --no-pager | tail -50"

# Check VM resources
ssh torrust@$VM_IP "free -h && df -h"
```

#### Cloud-Init Issues

```bash
# Check cloud-init status and logs
ssh torrust@$VM_IP "cloud-init status --long"
ssh torrust@$VM_IP "sudo cat /var/log/cloud-init-output.log | tail -50"
ssh torrust@$VM_IP "sudo cloud-init analyze show"
```

---

## Summary

This guide provides a complete integration testing workflow that:

1. **Creates fresh infrastructure** in ~3-5 minutes
2. **Waits for cloud-init** to complete (~2-3 minutes)
3. **Runs comprehensive tests** covering all services (~3-5 minutes)
4. **Verifies end-to-end functionality** of the Torrust Tracker
5. **Cleans up resources** when complete

**Total Time**: ~8-12 minutes for complete cycle

### Key Lessons Learned

During the development of this guide, we identified several critical issues:

1. **SSH Key Configuration**: The most common failure is missing or incorrect SSH
   key setup. The `make setup-ssh-key` step is **mandatory**.

2. **Non-Default SSH Keys**: If using custom SSH keys (like `torrust_rsa`
   instead of `id_rsa`), you must:

   - Configure the public key in `infrastructure/terraform/local.tfvars`
   - Set up SSH client configuration or use `-i` flag explicitly

3. **Docker Compose Compatibility**: Cloud-init now installs Docker Compose V2
   plugin for better compatibility with modern compose.yaml files. Integration
   tests automatically detect and use the appropriate command (`docker compose`
   or `docker-compose`).

4. **Cloud-Init Timing**: Cloud-init performs many operations including:

   - Package downloads and installations
   - System configuration
   - **System reboot** (in full configuration)
   - Service startup after reboot

   The main improvement was fixing firewall configuration to allow SSH access
   during cloud-init, preventing connectivity blocks that caused completion
   delays. Actual completion time is typically 2-3 minutes.

5. **Debugging Techniques**: Use `virsh console` and cloud-init logs to debug
   issues when SSH fails.

### Success Factors

The key to success is **proper SSH key configuration** and **allowing cloud-init
to complete** - it installs many packages and configures the system, which
typically takes 2-3 minutes but ensures a production-ready environment.

All commands are designed to be copy-pasteable and include realistic timing
information to set proper expectations.
