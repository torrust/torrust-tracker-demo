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

**⚠️ CRITICAL**: All commands in this guide assume you are running from the
**project root directory**. If you see "command not found" errors, verify you are
in the correct directory.

**Working Directory Indicator**: Commands will be shown with this format:

```bash
# [PROJECT_ROOT] - Run from project root directory
make command

# [TERRAFORM_DIR] - Run from infrastructure/terraform directory
cd infrastructure/terraform && tofu command
```

### 1.2 Check for Existing Resources

⚠️ **WARNING**: The following commands will destroy existing VMs and remove
data. Only proceed if you want to start with a completely clean environment.

```bash
# [PROJECT_ROOT] Check for existing VMs that might conflict
virsh list --all | grep torrust-tracker-demo || echo "✅ No conflicting VM found"

# [PROJECT_ROOT] Check for existing libvirt volumes
virsh vol-list user-default 2>/dev/null | grep torrust-tracker-demo || \
  echo "✅ No conflicting volumes found"

# [PROJECT_ROOT] Check for existing OpenTofu state
ls -la infrastructure/terraform/terraform.tfstate* 2>/dev/null || \
  echo "✅ No existing state files"
```

**Expected Output**: Should show "✅" messages if no conflicts exist.

### 1.3 Clean Up Any Existing Infrastructure

⚠️ **DESTRUCTIVE OPERATION**: This will permanently delete VMs, volumes,
and state files.

```bash
# [PROJECT_ROOT] Complete cleanup - removes VMs, state files, and fixes permissions
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
# [PROJECT_ROOT] Verify no conflicting resources remain
echo "=== Verifying Clean State ==="

# [PROJECT_ROOT] Check VMs
virsh list --all | grep torrust-tracker-demo && \
  echo '❌ VM still exists!' || echo '✅ No VM conflicts'

# [PROJECT_ROOT] Check volumes in user-default pool
virsh vol-list user-default 2>/dev/null | grep torrust-tracker-demo && \
  echo '❌ Volumes still exist!' || echo '✅ No volume conflicts'

# [PROJECT_ROOT] Check OpenTofu state
ls infrastructure/terraform/terraform.tfstate* 2>/dev/null && \
  echo '❌ State files still exist!' || echo '✅ No state file conflicts'
```

**Expected Output**: All checks should show "✅" (no conflicts).

### 1.4.1 Manual Cleanup (if needed)

⚠️ **CRITICAL**: This step is often **required** because `make clean-and-fix`
sometimes misses libvirt volumes, causing deployment failures with errors like:

- `storage volume 'torrust-tracker-demo-cloudinit.iso' exists already`
- `storage volume 'torrust-tracker-demo.qcow2' exists already`

If the verification step shows "❌ Volumes still exist!" **OR** if you encounter
volume conflicts during deployment, perform this manual cleanup:

```bash
# [PROJECT_ROOT] List all volumes to see conflicts
echo "=== Current volumes in user-default pool ==="
virsh vol-list user-default

# [PROJECT_ROOT] List only conflicting volumes
virsh vol-list user-default | grep torrust-tracker-demo || echo "No torrust volumes found"

# [PROJECT_ROOT] Delete ALL torrust-tracker-demo volumes
# Common volumes that need cleanup:
virsh vol-delete torrust-tracker-demo-cloudinit.iso user-default 2>/dev/null || \
  echo "cloudinit.iso not found"
virsh vol-delete torrust-tracker-demo.qcow2 user-default 2>/dev/null || \
  echo "VM disk not found"

# [PROJECT_ROOT] Verify complete cleanup
echo "=== Verifying volume cleanup ==="
virsh vol-list user-default | grep torrust-tracker-demo && \
  echo '❌ Volumes still exist!' || echo '✅ No volume conflicts'
```

**Expected Output**: Should show "✅ No volume conflicts" after manual cleanup.

**What This Fixes**:

- Removes leftover volumes that `make clean-and-fix` consistently misses
- Prevents "volume already exists" errors during deployment
- Ensures a truly clean state for fresh deployments

**Why This Happens**: The `make clean-and-fix` command primarily handles
OpenTofu state and VM definitions, but libvirt volumes can persist independently.
This is especially common when:

- Previous deployments were interrupted
- Manual VM deletion was performed
- OpenTofu state was corrupted or manually removed

### 1.5 Set Up SSH Key Configuration

⚠️ **CRITICAL STEP**: This step was **missing** from our initial testing and
caused SSH connection failures!

#### For Default SSH Keys (id_rsa)

```bash
# [PROJECT_ROOT] Set up SSH key configuration for VM access
time make setup-ssh-key
```

#### For Non-Default SSH Keys (e.g., torrust_rsa)

⚠️ **IMPORTANT**: If you're using a non-default SSH key file (e.g.,
`~/.ssh/torrust_rsa` instead of `~/.ssh/id_rsa`), you need to:

1. **Configure the public key in terraform**:

```bash
# [PROJECT_ROOT] Get your non-default public key
cat ~/.ssh/torrust_rsa.pub

# [PROJECT_ROOT] Manually edit the terraform configuration
vim infrastructure/terraform/local.tfvars

# Add your public key content:
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC... your-key-here"
```

1. **Configure SSH client to use the correct private key**:

```bash
# [PROJECT_ROOT] Option 1: Create/edit SSH config
echo "Host 192.168.122.*
    IdentityFile ~/.ssh/torrust_rsa
    IdentitiesOnly yes" >> ~/.ssh/config

# [PROJECT_ROOT] Option 2: Always specify key explicitly when connecting
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
# [PROJECT_ROOT] Ensure the file contains your actual public key (not placeholder)
cat infrastructure/terraform/local.tfvars | grep ssh_public_key

# Should show your full public key, not "REPLACE_WITH_YOUR_SSH_PUBLIC_KEY"
```

### 1.6 Initialize OpenTofu

```bash
# [PROJECT_ROOT] Initialize OpenTofu providers
time make init
```

**Expected Output**:

- Provider plugins downloaded
- Lock file created
- "OpenTofu has been successfully initialized!" message
- **Time**: ~3 seconds (actual: 3.11s)

**What This Creates**: `.terraform.lock.hcl` file in `infrastructure/terraform/`

---

## Step 1.7: Generate Configuration Files (New Workflow)

⚠️ **IMPORTANT**: Recent changes introduced a new configuration management system
that generates final configuration files from templates and environment values.

### 1.7.1 Generate Local Environment Configuration

```bash
# [PROJECT_ROOT] Generate local environment configuration
time make configure-local
```

**Expected Output**:

- Configuration files generated from templates
- Environment values applied to templates
- **Time**: ~2 seconds

**What This Creates**: Final configuration files in `infrastructure/cloud-init/`
from templates in `infrastructure/config/templates/` using values from
`infrastructure/config/environments/local.env`.

### 1.7.2 Validate Generated Configuration

```bash
# [PROJECT_ROOT] Validate generated configuration files
time make validate-config
```

**Expected Output**:

- All configuration files pass validation
- YAML syntax checks pass
- Template rendering successful
- **Time**: ~3 seconds

**What This Verifies**: Generated configuration files are syntactically correct
and ready for deployment.

---

## Step 2: Deploy Fresh Virtual Machine

### 2.1 Plan the Deployment

```bash
# [PROJECT_ROOT] Review what will be created
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
# [PROJECT_ROOT] Deploy VM with full configuration (this takes time!)
time make apply
```

**Expected During Deployment**:

1. Libvirt permissions check and fixes
2. Download of Ubuntu 24.04 cloud image (~600MB)
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
# [PROJECT_ROOT] Check VM status
virsh list --all
```

**Expected Output**:

```console
 Id   Name                   State
--------------------------------------
 1    torrust-tracker-demo   running
```

### 2.4 Refresh OpenTofu State (Important!)

⚠️ **CRITICAL STEP**: After VM deployment, OpenTofu's state may not immediately
reflect the VM's IP address assigned by DHCP. This is a known issue where the
libvirt provider state becomes stale after cloud-init completes.

```bash
# [PROJECT_ROOT] Refresh OpenTofu state to detect IP assignment
time make refresh-state
```

**Expected Output**:

- OpenTofu state refreshed successfully
- VM IP address properly detected
- **Time**: ~3 seconds

**What This Fixes**: Ensures OpenTofu knows the VM's actual IP address, preventing
"No IP assigned yet" issues in subsequent commands.

---

## Step 3: Wait for Cloud-Init Completion (Critical!)

**⏱️ Timing Update**: Based on recent testing, cloud-init completes much faster
than originally estimated. The VM is typically ready for SSH connections within
2-3 minutes. Previous issues were caused by firewall configuration blocking SSH
connections during cloud-init, preventing proper completion. The firewall setup
has been improved to allow SSH access throughout the process.

### 3.1 Get VM IP Address

```bash
# [PROJECT_ROOT] Get IP from libvirt (more reliable during cloud-init)
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

#### Method 2: Use virt-viewer for graphical console access

```bash
# Connect to VM graphical console (shows login prompt)
virt-viewer spice://127.0.0.1:5900

# Alternative using VM name
virt-viewer torrust-tracker-demo
```

**Note**: The virt-viewer method provides a graphical console where you should
see a login prompt. This is particularly useful when the text-based virsh
console doesn't work or when you need to see the full boot process.

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
       'echo "SSH works!"' 2>/dev/null; then
        echo '✅ SSH connection successful!'
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
# [PROJECT_ROOT] Test basic VM connectivity
time ./infrastructure/tests/test-integration.sh access
```

**Expected Output**:

- SSH connectivity test passes
- VM accessible message
- **Time**: ~5 seconds

### 4.2 Test Docker Installation

```bash
# [PROJECT_ROOT] Test Docker functionality
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
# [PROJECT_ROOT] Clone and setup the Torrust Tracker repository
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
# [PROJECT_ROOT] Pull images and start all services
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
# [PROJECT_ROOT] Test all API endpoints
time ./infrastructure/tests/test-integration.sh endpoints
```

**Expected Output**:

- HTTP API responding through nginx proxy on port 80
- Health check API accessible without authentication
- Stats API requires authentication token
- UDP ports listening (6868, 6969)
- **Time**: ~15 seconds

**Note**: The integration test script may fail on endpoint testing due to authentication
requirements. For manual testing, see Step 5.2 for the correct endpoint testing procedures.

### 4.6 Test Monitoring Services

```bash
# [PROJECT_ROOT] Test Prometheus and Grafana
time ./infrastructure/tests/test-integration.sh monitoring
```

**Expected Output**:

- Prometheus health check passes
- Grafana health check passes
- **Time**: ~10 seconds

### 4.7 Run Complete Integration Test Suite

```bash
# [PROJECT_ROOT] Run all tests in sequence
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
# [PROJECT_ROOT] Connect to VM for manual inspection
make ssh
```

**Inside the VM, you can run**:

```bash
# [VM_REMOTE] Check cloud-init logs
sudo cat /var/log/cloud-init-output.log | tail -20

# [VM_REMOTE] Check running services
docker compose ps

# [VM_REMOTE] Check service logs
docker compose logs --tail=20

# [VM_REMOTE] Check system status
sudo systemctl status docker
sudo ufw status verbose

# [VM_REMOTE] Check Torrust Tracker logs
docker compose logs torrust-tracker --tail=20

# [VM_REMOTE] Exit the VM
exit
```

### 5.2 Test External Access (from Host)

**⚠️ CRITICAL NETWORK ARCHITECTURE UNDERSTANDING:**

The deployment uses **double virtualization**:

1. **VM Level**: VM has IP (e.g., `192.168.122.253`) with specific ports exposed
2. **Docker Network Level**: Inside VM, Docker Compose creates internal network
3. **Nginx Proxy**: Routes external traffic from port 80 to internal services

**Port Access Rules**:

- ✅ **Port 80**: Nginx proxy (accessible from host) → routes to internal services
- ✅ **UDP ports 6868, 6969**: Direct tracker access (accessible from host)
- ❌ **Internal ports** (1212, 7070, 3000, 9090): Only accessible within Docker network

#### 5.2.1 Get VM IP and Test API Endpoints

```bash
# [PROJECT_ROOT] Get VM IP for external testing
VM_IP=$(cd infrastructure/terraform && tofu output -raw vm_ip)
echo "VM IP: $VM_IP"

# [PROJECT_ROOT] Test health check API (no authentication required)
curl -s http://$VM_IP/api/health_check | jq .

# [PROJECT_ROOT] Test stats API (requires authentication token)
# Note: Get the token from the .env file in the VM
TOKEN="local-dev-admin-token-12345"
curl -s "http://$VM_IP/api/v1/stats?token=$TOKEN" | jq .
```

**Expected Output**:

- **Health check**:

  ```json
  {
    "status": "Ok"
  }
  ```

- **Stats API** (with pretty JSON formatting):

  ```json
  {
    "torrents": 0,
    "seeders": 0,
    "completed": 0,
    "leechers": 0,
    "tcp4_connections_handled": 0,
    "tcp4_announces_handled": 0,
    "tcp4_scrapes_handled": 0,
    "tcp6_connections_handled": 0,
    "tcp6_announces_handled": 0,
    "tcp6_scrapes_handled": 0,
    "udp_requests_aborted": 0,
    "udp_requests_banned": 0,
    "udp_banned_ips_total": 0,
    "udp_avg_connect_processing_time_ns": 0,
    "udp_avg_announce_processing_time_ns": 0,
    "udp_avg_scrape_processing_time_ns": 0,
    "udp4_requests": 0,
    "udp4_connections_handled": 0,
    "udp4_announces_handled": 0,
    "udp4_scrapes_handled": 0,
    "udp4_responses": 0,
    "udp4_errors_handled": 0,
    "udp6_requests": 0,
    "udp6_connections_handled": 0,
    "udp6_announces_handled": 0,
    "udp6_scrapes_handled": 0,
    "udp6_responses": 0,
    "udp6_errors_handled": 0
  }
  ```

#### 5.2.2 Test Monitoring Services

```bash
# [PROJECT_ROOT] Test Prometheus (accessible through nginx proxy)
curl -s http://$VM_IP/prometheus/api/v1/targets | jq .

# [PROJECT_ROOT] Test Grafana web interface
curl -s -I http://$VM_IP:3100/ | head -5

# [PROJECT_ROOT] Alternative: Check if services are responding
curl -s -o /dev/null -w "%{http_code}\n" http://$VM_IP/prometheus/
curl -s -o /dev/null -w "%{http_code}\n" http://$VM_IP:3100/
```

#### 5.2.3 Common Endpoint Testing Mistakes

❌ **Wrong - Trying to access internal ports directly**:

```bash
# These will fail - internal ports not exposed outside Docker network
curl http://$VM_IP:1212/api/health_check  # Port 1212 not accessible
curl http://$VM_IP:7070/api/v1/stats      # Port 7070 not accessible
curl http://$VM_IP:9090/                  # Port 9090 not accessible
```

✅ **Correct - Using nginx proxy on port 80**:

```bash
# All API access goes through nginx proxy on port 80
curl http://$VM_IP/api/health_check           # Health check
curl "http://$VM_IP/api/v1/stats?token=TOKEN" # Stats with auth
curl http://$VM_IP/prometheus/                # Prometheus UI
```

#### 5.2.4 Getting the Authentication Token

```bash
# [PROJECT_ROOT] Get the authentication token from the VM
ssh torrust@$VM_IP \
  "grep TRACKER_ADMIN_TOKEN /home/torrust/github/torrust/torrust-tracker-demo/application/.env"

# Should output: TRACKER_ADMIN_TOKEN=local-dev-admin-token-12345
```

#### 5.2.5 Advanced Testing with jq

```bash
# [PROJECT_ROOT] Extract specific metrics with jq
curl -s "http://$VM_IP/api/v1/stats?token=$TOKEN" | jq '.torrents, .seeders, .leechers'

# [PROJECT_ROOT] Check if tracker is healthy
curl -s http://$VM_IP/api/health_check | jq -r '.status'

# [PROJECT_ROOT] Pretty print with color (if jq supports it)
curl -s "http://$VM_IP/api/v1/stats?token=$TOKEN" | jq --color-output .
```

---

## Step 6: Performance and Load Testing (Optional)

### Alternative: External Smoke Testing

For quick external validation without infrastructure complexity, consider using
the dedicated [Smoke Testing Guide](smoke-testing-guide.md). This approach
uses the Torrust Tracker Client tools to test your deployment from an external
perspective:

- ✅ **Quick validation** (~5 minutes vs full integration testing)
- ✅ **External black-box testing** using official client tools
- ✅ **Protocol-level verification** (UDP, HTTP, API endpoints)
- ✅ **No infrastructure knowledge required** - just test the deployed services
- ✅ **Perfect for post-deployment validation** and sanity checks

The smoke testing approach complements this integration guide by providing a
simpler alternative when you only need to verify that the deployed tracker
is working correctly.

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
# [PROJECT_ROOT] Stop all services cleanly
./infrastructure/tests/test-integration.sh stop
```

### 7.2 Destroy VM and Clean Up

```bash
# [PROJECT_ROOT] Destroy the VM and clean up resources
time make destroy
```

**Expected Output**:

- All resources destroyed
- State files cleaned
- **Time**: ~30 seconds

### 7.3 Final Cleanup

```bash
# [PROJECT_ROOT] Complete cleanup
make clean
```

**Expected Output**:

- Temporary files removed
- Lock files cleaned

---

---

## Step 8: Key Testing Insights and Best Practices

### 8.1 Critical Architecture Understanding

During testing, several important architectural details were discovered:

#### Network Architecture (Double Virtualization)

The deployment uses **two layers of virtualization**:

1. **Host → VM**: KVM/libvirt provides VM with IP `192.168.122.X`
2. **VM → Docker Compose**: Creates internal Docker network for services

**Port Mapping Flow**:

```text
Host (192.168.122.1)
    ↓ SSH/HTTP requests
VM (192.168.122.253:80)
    ↓ nginx proxy
Docker Network (tracker:1212, prometheus:9090, grafana:3000)
```

#### Authentication Requirements

- **Health Check API**: `/api/health_check` - No authentication required
- **Stats API**: `/api/v1/stats` - Requires `?token=ADMIN_TOKEN` parameter
- **Admin Token**: Located in `/application/.env` as `TRACKER_ADMIN_TOKEN`

### 8.2 Correct Testing Procedures

#### ✅ Proper API Testing

```bash
# Get VM IP
VM_IP=$(cd infrastructure/terraform && tofu output -raw vm_ip)

# Test health (no auth needed)
curl -s http://$VM_IP/api/health_check | jq .

# Test stats (auth required)
TOKEN="local-dev-admin-token-12345"
curl -s "http://$VM_IP/api/v1/stats?token=$TOKEN" | jq .

# Test specific metrics with jq filtering
curl -s "http://$VM_IP/api/v1/stats?token=$TOKEN" | jq '.torrents, .seeders'
```

#### ✅ Monitoring Service Testing

```bash
# Prometheus (through nginx proxy)
curl -s http://$VM_IP/prometheus/api/v1/targets | jq .

# Grafana (direct port access allowed)
curl -I http://$VM_IP:3100/

# Check HTTP response codes
curl -s -o /dev/null -w "%{http_code}\n" http://$VM_IP/prometheus/
```

### 8.3 Common Testing Mistakes

#### ❌ Port Confusion

**Wrong**: Trying to access internal Docker ports directly from host:

```bash
curl http://$VM_IP:1212/api/health_check    # 1212 not exposed
curl http://$VM_IP:7070/api/v1/stats        # 7070 not exposed
curl http://$VM_IP:9090/                    # 9090 not exposed
```

**Correct**: Using nginx proxy on port 80:

```bash
curl http://$VM_IP/api/health_check         # Proxied to tracker:1212
curl http://$VM_IP/api/v1/stats?token=X     # Proxied to tracker:1212
curl http://$VM_IP/prometheus/              # Proxied to prometheus:9090
```

#### ❌ Missing Authentication

**Wrong**: Testing stats API without token:

```bash
curl http://$VM_IP/api/v1/stats
# Returns: Unhandled rejection: Err { reason: "unauthorized" }
```

**Correct**: Including authentication token:

```bash
curl "http://$VM_IP/api/v1/stats?token=local-dev-admin-token-12345"
```

### 8.4 Integration Test Script Limitations

The automated integration test script (`./infrastructure/tests/test-integration.sh endpoints`)
may fail because:

1. **Authentication**: Script doesn't include token for stats API
2. **Port Assumptions**: May test internal ports instead of nginx proxy
3. **JSON Parsing**: Doesn't use `jq` for response validation

**Manual testing** (as shown in this guide) provides more reliable results and
better insight into the actual API functionality.

### 8.5 Useful Testing Commands

#### JSON Processing with jq

```bash
# Pretty print with colors
curl -s "http://$VM_IP/api/v1/stats?token=$TOKEN" | jq --color-output .

# Extract specific fields
curl -s "http://$VM_IP/api/v1/stats?token=$TOKEN" | jq '.torrents, .seeders, .leechers'

# Check if service is healthy
curl -s http://$VM_IP/api/health_check | jq -r '.status'

# Count total UDP requests
curl -s "http://$VM_IP/api/v1/stats?token=$TOKEN" | jq '.udp4_requests + .udp6_requests'
```

#### Service Status Verification

```bash
# Check all Docker services
ssh torrust@$VM_IP \
  'cd /home/torrust/github/torrust/torrust-tracker-demo/application && docker compose ps'

# Check specific service logs
ssh torrust@$VM_IP \
  'cd /home/torrust/github/torrust/torrust-tracker-demo/application && \
   docker compose logs tracker --tail=20'

# Check service health status
ssh torrust@$VM_IP 'docker ps --format "table {{.Names}}\t{{.Status}}"'
```

---

## Troubleshooting

### Resource Conflicts During Deployment

#### Cloud-init ISO Already Exists

**Error**: `storage volume 'torrust-tracker-demo-cloudinit.iso' exists already`

**Root Cause**: Previous deployment cleanup was incomplete, leaving libvirt volumes.

**Solution**:

```bash
# Check if cloud-init ISO exists
virsh vol-list user-default | grep cloudinit

# Remove the conflicting cloud-init ISO
virsh vol-delete torrust-tracker-demo-cloudinit.iso user-default

# Check for VM disk volume too
virsh vol-list user-default | grep torrust-tracker-demo

# Remove VM disk if it exists
virsh vol-delete torrust-tracker-demo.qcow2 user-default 2>/dev/null || echo "VM disk not found"

# Verify cleanup
virsh vol-list user-default | grep torrust-tracker-demo || echo "✅ All volumes cleaned"

# Then retry: make apply
```

**Prevention**: Always run the complete cleanup verification (Step 1.4.1) before
starting fresh deployments.

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

#### Working Directory Confusion

**MOST COMMON ISSUE**: Commands failing due to being in the wrong directory.

```bash
# [PROJECT_ROOT] Check current directory
pwd
# Should output: /path/to/torrust-tracker-demo

# [PROJECT_ROOT] If you're in the wrong directory, navigate to project root
cd /home/yourname/Documents/git/committer/me/github/torrust/torrust-tracker-demo

# [PROJECT_ROOT] Verify you're in the right place
ls -la | grep -E "(Makefile|infrastructure|application)"
# Should show all three: Makefile, infrastructure/, application/
```

**Symptoms**:

- `make: *** No rule to make target 'configure-local'. Stop.`
- `make: *** No such file or directory. Stop.`
- `./infrastructure/tests/test-integration.sh: No such file or directory`

**Solution**: Always ensure you're in the project root directory before running commands.

#### SSH Connection Fails

**MOST COMMON CAUSES**:

1. **Missing SSH key configuration**:

```bash
# [PROJECT_ROOT] Check if SSH key was configured
cat infrastructure/terraform/local.tfvars

# [PROJECT_ROOT] If file doesn't exist or contains "REPLACE_WITH_YOUR_SSH_PUBLIC_KEY":
make setup-ssh-key
# [PROJECT_ROOT] Then redeploy: make destroy && make apply
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
2. **Generates configuration files** from templates (~2 seconds)
3. **Refreshes OpenTofu state** to detect VM IP (~3 seconds)
4. **Waits for cloud-init** to complete (~2-3 minutes)
5. **Runs comprehensive tests** covering all services (~3-5 minutes)
6. **Verifies end-to-end functionality** of the Torrust Tracker
7. **Cleans up resources** when complete

**Total Time**: ~8-12 minutes for complete cycle

### Key Lessons Learned

During the development of this guide, we identified several critical issues:

1. **Working Directory Requirements**: The most common failure is running commands
   from the wrong directory. All `make` commands and test scripts must be run from
   the **project root directory**, not from subdirectories like `infrastructure/terraform/`.

2. **New Configuration Workflow**: Recent changes introduced a template-based
   configuration system. You must run `make configure-local` to generate final
   configuration files before deployment.

3. **SSH Key Configuration**: SSH key setup is **mandatory**. The `make setup-ssh-key`
   step must be completed before deployment.

4. **OpenTofu State Refresh**: After VM deployment, the OpenTofu state may not
   immediately reflect the VM's IP address. The `make refresh-state` step (Section 2.4)
   prevents "No IP assigned yet" issues in subsequent commands.

5. **Non-Default SSH Keys**: If using custom SSH keys (like `torrust_rsa`
   instead of `id_rsa`), you must:

   - Configure the public key in `infrastructure/terraform/local.tfvars`
   - Set up SSH client configuration or use `-i` flag explicitly

6. **Docker Compose Compatibility**: Cloud-init now installs Docker Compose V2
   plugin for better compatibility with modern compose.yaml files. Integration
   tests automatically detect and use the appropriate command (`docker compose`
   or `docker-compose`).

7. **Cloud-Init Timing**: Cloud-init performs many operations including:

   - Package downloads and installations
   - System configuration
   - **System reboot** (in full configuration)
   - Service startup after reboot

   The main improvement was fixing firewall configuration to allow SSH access
   during cloud-init, preventing connectivity blocks that caused completion
   delays. Actual completion time is typically 2-3 minutes.

8. **Debugging Techniques**: Use `virsh console` and cloud-init logs to debug
   issues when SSH fails.

### Success Factors

The key to success is **proper SSH key configuration** and **allowing cloud-init
to complete** - it installs many packages and configures the system, which
typically takes 2-3 minutes but ensures a production-ready environment.

All commands are designed to be copy-pasteable and include realistic timing
information to set proper expectations.
