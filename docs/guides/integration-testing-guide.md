# Integration Testing Guide - Twelve-Factor Deployment

This guide provides step-by-step instructions for testing the complete twelve-factor
deployment workflow on a fresh virtual machine. All commands are ready to copy and paste.

## Overview

This guide will walk you through the deployment process with separated infrastructure and
application concerns:

1. **Infrastructure Provisioning**: Setting up the platform (`make infra-apply`)
2. **Application Deployment**: Twelve-factor Build + Release + Run stages (`make app-deploy`)
3. **Validation**: Health checking (`make app-health-check`)
4. **Cleanup**: Resource management (`make infra-destroy`)

The new workflow separates infrastructure provisioning from application deployment,
following twelve-factor principles for better maintainability and deployment reliability.

**Total Time**: ~5-8 minutes (streamlined with separated stages)

---

## Automated Testing Alternative

**For automated testing**, you can use the end-to-end test script that implements this exact workflow:

```bash
# Run the automated version of this guide
./tests/test-e2e.sh
```

The automated test script (`tests/test-e2e.sh`) follows the same steps described in this guide:

- **Step 1**: Prerequisites validation
- **Step 2**: Infrastructure provisioning (`make infra-apply`)
- **Step 3**: Application deployment (`make app-deploy`)
- **Step 4**: Health validation (`make app-health-check`)
- **Step 5**: Smoke testing (basic functionality validation)
- **Step 6**: Cleanup (`make infra-destroy`)

**Benefits of the automated test**:

- ✅ **Consistent execution** - No manual errors or missed steps
- ✅ **Comprehensive logging** - All output saved to `/tmp/torrust-e2e-test.log`
- ✅ **Smoke testing included** - Additional tracker functionality validation
- ✅ **Time tracking** - Reports duration of each stage
- ✅ **CI/CD integration** - Can be used in automated pipelines

**When to use automated vs manual**:

- **Use automated** (`./tests/test-e2e.sh`) for: CI/CD, quick validation, consistent testing
- **Use this manual guide** for: Learning the workflow, debugging issues, understanding individual steps

**Environment variables for automated testing**:

```bash
# Skip cleanup (leave infrastructure running for inspection)
SKIP_CLEANUP=true ./tests/test-e2e.sh

# Skip confirmation prompt (for CI/CD)
SKIP_CONFIRMATION=true ./tests/test-e2e.sh
```

Continue with the manual guide below if you want to understand each step in detail
or need to debug specific issues.

---

## Prerequisites

Ensure you have completed the initial setup:

```bash
# Verify prerequisites are met
make test-syntax
```

**Expected Output**: All syntax validation should pass.

---

## Step 1: Prepare Environment

### 1.1 Navigate to Project Directory

For example:

```bash
cd /home/yourname/Documents/git/committer/me/github/torrust/torrust-tracker-demo
```

**⚠️ CRITICAL**: All commands in this guide assume you are running from the
**project root directory**. The new twelve-factor workflow requires correct
working directory for script execution.

**Working Directory Indicator**: Commands will be shown with this format:

```bash
# [PROJECT_ROOT] - Run from project root directory
make command
```

### 1.2 Clean Up Any Existing Infrastructure (Optional)

⚠️ **DESTRUCTIVE OPERATION**: Only run if you want to start completely fresh.

```bash
# [PROJECT_ROOT] Destroy any existing infrastructure
make infra-destroy ENVIRONMENT=local

# [PROJECT_ROOT] Clean up Terraform state and caches
make clean
```

**Expected Output**: Infrastructure cleaned up or "No infrastructure found" message.

---

## Step 2: Infrastructure Provisioning

Infrastructure provisioning sets up the platform (VM) without deploying
the application. This follows twelve-factor separation of concerns.

### 2.1 Initialize Infrastructure

```bash
# [PROJECT_ROOT] Initialize Terraform/OpenTofu (first time only)
make infra-init ENVIRONMENT=local
```

**Expected Output**:

```text
Initializing infrastructure for local...
[INFO] Loading environment configuration: local
[SUCCESS] Prerequisites validation passed
[INFO] Terraform already initialized
```

### 2.2 Plan Infrastructure Changes

```bash
# [PROJECT_ROOT] Review what will be created
make infra-plan ENVIRONMENT=local
```

**Expected Output**: Terraform plan showing VM, volumes, and network resources to be created.

### 2.3 Provision Infrastructure

```bash
# [PROJECT_ROOT] Create the VM infrastructure
time make infra-apply ENVIRONMENT=local
```

**Expected Output**:

```text
Provisioning infrastructure for local...
[INFO] Starting infrastructure provisioning (Twelve-Factor Build Stage)
[INFO] Environment: local, Action: apply
[SUCCESS] Prerequisites validation passed
[INFO] Loading environment configuration: local
[INFO] Applying infrastructure changes
[SUCCESS] Infrastructure provisioned successfully
[INFO] VM IP: 192.168.122.XXX
[INFO] SSH Access: ssh torrust@192.168.122.XXX
[INFO] Next step: make app-deploy ENVIRONMENT=local
```

**Time**: ~2-3 minutes (VM creation and cloud-init base setup)

**What This Creates**:

- VM with Ubuntu 24.04
- Basic system setup (Docker, users, firewall)
- SSH access ready
- **No application deployed yet**

### 2.4 Verify Infrastructure

```bash
# [PROJECT_ROOT] Check infrastructure status
make infra-status ENVIRONMENT=local

# [PROJECT_ROOT] Test SSH connectivity
make vm-ssh
# (type 'exit' to return)
```

**Expected Output**: VM IP address and successful SSH connection.

---

## Step 3: Application Deployment - Deploy Application

The **Release Stage** combines the application code with environment-specific
configuration. The **Run Stage** starts the application processes.

### 3.1 Deploy Application

```bash
# [PROJECT_ROOT] Deploy application to the provisioned infrastructure
time make app-deploy ENVIRONMENT=local
```

**Expected Output**:

```text
Deploying application for local...
[INFO] Starting application deployment (Twelve-Factor Build + Release + Run Stages)
[INFO] Environment: local
[SUCCESS] SSH connection established
[INFO] === TWELVE-FACTOR RELEASE STAGE ===
[INFO] Deploying application with environment: local
[INFO] Setting up application repository
[INFO] Processing configuration for environment: local
[INFO] Setting up application storage
[SUCCESS] Release stage completed
[INFO] === TWELVE-FACTOR RUN STAGE ===
[INFO] Starting application services
[INFO] Stopping existing services
[INFO] Starting application services
[INFO] Waiting for services to initialize (30 seconds)...
[SUCCESS] Run stage completed
[INFO] === DEPLOYMENT VALIDATION ===
[INFO] Checking service status
[INFO] Testing application endpoints
✅ Health check endpoint: OK
✅ API stats endpoint: OK
✅ HTTP tracker endpoint: OK
✅ All endpoints are responding
[SUCCESS] Deployment validation passed
[SUCCESS] Application deployment completed successfully!
```

**Time**: ~3-4 minutes (application deployment and service startup)

**What This Does**:

- Clones/updates application repository
- Processes environment configuration
- Starts Docker services
- Validates deployment health

### 3.2 Verify Application Deployment

```bash
# [PROJECT_ROOT] Get VM connection info
make infra-status ENVIRONMENT=local
```

**Expected Output**: Shows VM IP and connection information.

---

## Step 4: Validation Stage - Health Checks

### 4.1 Run Comprehensive Health Check

```bash
# [PROJECT_ROOT] Run full health validation
time make app-health-check ENVIRONMENT=local
```

**Expected Output**:

```text
Running health check for local...
[INFO] Starting health check for Torrust Tracker Demo
[INFO] Environment: local
[INFO] Target VM: 192.168.122.XXX
[INFO] Testing SSH connectivity to 192.168.122.XXX
✅ SSH connectivity
[INFO] Testing Docker services
✅ Docker daemon
✅ Docker Compose services accessible
✅ Services are running (6 services)
[INFO] Testing application endpoints
✅ Health check endpoint (port 1313)
✅ API stats endpoint (port 1212)
✅ HTTP tracker endpoint (port 7070)
✅ Grafana endpoint (port 3000)
[INFO] Testing UDP tracker connectivity
✅ UDP tracker port 6868
✅ UDP tracker port 6969
[INFO] Testing storage and persistence
✅ Storage directory exists
✅ SQLite database file exists
[INFO] Testing logging and monitoring
✅ Prometheus metrics endpoint
✅ Docker logs accessible

=== HEALTH CHECK REPORT ===
Environment:      local
VM IP:           192.168.122.XXX
Total Tests:     12
Passed:          12
Failed:          0
Success Rate:    100%

[SUCCESS] All health checks passed! Application is healthy.
```

**Time**: ~1 minute

### 4.2 Manual Verification (Optional)

```bash
# [PROJECT_ROOT] SSH into VM for manual inspection
make ssh

# [VM] Check service status
cd /home/torrust/github/torrust/torrust-tracker-demo/application
docker compose ps

# [VM] Check application logs
docker compose logs --tail=20

# [VM] Test endpoints manually
curl http://localhost:1313/health_check
curl http://localhost:1212/api/v1/stats

# Exit back to host
exit
```

---

## Step 5: Integration Testing Results

### 5.1 Expected Service Status

After successful deployment, you should see these services running:

| Service                  | Port       | Status     | Purpose               |
| ------------------------ | ---------- | ---------- | --------------------- |
| Torrust Tracker (Health) | 1313       | ✅ Running | Health check endpoint |
| Torrust Tracker (API)    | 1212       | ✅ Running | REST API and stats    |
| Torrust Tracker (HTTP)   | 7070       | ✅ Running | HTTP tracker protocol |
| Torrust Tracker (UDP)    | 6868, 6969 | ✅ Running | UDP tracker protocol  |
| Grafana                  | 3000       | ✅ Running | Monitoring dashboard  |
| Prometheus               | 9090       | ✅ Running | Metrics collection    |

### 5.2 Test Endpoints

You can test these endpoints from the host machine:

```bash
# Get VM IP first
VM_IP=$(cd infrastructure/terraform && tofu output -raw vm_ip)

# Test endpoints (replace with actual VM IP)
curl http://$VM_IP:1313/health_check
curl http://$VM_IP:1212/api/v1/stats
curl http://$VM_IP:7070
```

---

## Step 6: Cleanup

### 6.1 Destroy Infrastructure

When you're done testing, clean up the resources:

```bash
# [PROJECT_ROOT] Destroy the entire infrastructure
time make infra-destroy ENVIRONMENT=local
```

**Expected Output**:

```text
Destroying infrastructure for local...
[INFO] Starting infrastructure provisioning (Twelve-Factor Build Stage)
[INFO] Environment: local, Action: destroy
[SUCCESS] Prerequisites validation passed
[INFO] Loading environment configuration: local
[INFO] Destroying infrastructure
[SUCCESS] Infrastructure destroyed
```

**Time**: ~1 minute

### 6.2 Verify Cleanup

```bash
# [PROJECT_ROOT] Verify no resources remain
make infra-status ENVIRONMENT=local

# Should show: "No infrastructure found"
```

---

## Summary

### Twelve-Factor Deployment Workflow

This integration test demonstrates the complete twelve-factor deployment workflow:

1. **Build Stage** (`make infra-apply`):

   - ✅ Infrastructure provisioning only
   - ✅ VM creation with base system
   - ✅ No application coupling

2. **Release Stage** (`make app-deploy`):

   - ✅ Application code deployment
   - ✅ Environment-specific configuration
   - ✅ Service orchestration

3. **Run Stage** (`make app-deploy`):

   - ✅ Process startup
   - ✅ Health validation
   - ✅ Monitoring setup

4. **Validation** (`make health-check`):
   - ✅ Comprehensive health checks
   - ✅ Endpoint testing
   - ✅ Service verification

### Total Time Breakdown

| Stage          | Time         | Description                         |
| -------------- | ------------ | ----------------------------------- |
| Infrastructure | ~2-3 min     | VM provisioning and base setup      |
| Application    | ~3-4 min     | Code deployment and service startup |
| Health Check   | ~1 min       | Comprehensive validation            |
| **Total**      | **~6-8 min** | Complete deployment cycle           |

### Key Benefits

- **Separation of Concerns**: Infrastructure and application are deployed independently
- **Environment Parity**: Same process works for local, staging, and production
- **Configuration as Code**: All configuration via environment variables
- **Immutable Infrastructure**: VMs can be destroyed and recreated easily
- **Health Validation**: Comprehensive testing ensures deployment quality

### Next Steps

- **Production Deployment**: Use `ENVIRONMENT=production` for production deployments
- **Configuration Changes**: Modify environment files in `infrastructure/config/environments/`
- **Application Updates**: Use `make app-redeploy` for application-only updates
- **Monitoring**: Access Grafana at `http://VM_IP:3000` (admin/admin)

### Troubleshooting

If any step fails, see the troubleshooting section in each script's help:

```bash
./infrastructure/scripts/provision-infrastructure.sh help
./infrastructure/scripts/deploy-app.sh help
./infrastructure/scripts/health-check.sh help
```

---

**✅ Integration Test Complete!**

You have successfully tested the complete twelve-factor deployment workflow
for the Torrust Tracker Demo. The application is now running and validated
on a fresh virtual machine.

## Automated Testing

**Tip**: For future testing, consider using the automated version of this guide:

```bash
# Run the same workflow automatically
./tests/test-e2e.sh

# With cleanup skipped (for inspection)
SKIP_CLEANUP=true ./tests/test-e2e.sh
```

The automated test (`tests/test-e2e.sh`) performs the exact same steps as this manual guide,
with additional smoke testing and comprehensive logging. It's perfect for:

- **CI/CD pipelines** - Automated validation
- **Quick testing** - Consistent execution without manual errors
- **Regression testing** - Verify changes don't break the workflow

---

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

**What This Creates**: Final configuration files including:

- `application/.env` - Docker Compose environment file
- `application/storage/tracker/etc/tracker.toml` - Tracker configuration
- `application/storage/prometheus/etc/prometheus.yml` - Prometheus configuration
- `infrastructure/cloud-init/` - VM provisioning files

These files are generated from templates in `infrastructure/config/templates/` using
values from `infrastructure/config/environments/local.env`.

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

## Step 1.8: Clean Application Storage (Optional but Recommended)

⚠️ **DESTRUCTIVE OPERATION WARNING**: This step permanently deletes all
application data including:

- **Database data** (MySQL databases, user accounts, torrents)
- **SSL certificates** (Let's Encrypt certificates, private keys)
- **Configuration files** (tracker.toml, prometheus.yml, etc.)
- **Application logs** and persistent data

**When to use this step**:

- ✅ Starting completely fresh integration test
- ✅ Previous test left corrupted data
- ✅ Database schema changes require clean slate
- ✅ SSL certificate issues need reset
- ❌ **NEVER** on production systems

### 1.8.1 Remove Application Storage

```bash
# [PROJECT_ROOT] Remove all application storage (DESTRUCTIVE!)
echo "=== WARNING: About to delete all application data ==="
echo "This will permanently remove:"
echo "  - Database data (MySQL)"
echo "  - SSL certificates"
echo "  - Configuration files"
echo "  - Application logs"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm

if [ "$confirm" = "yes" ]; then
    echo "Removing application storage..."
    rm -rf application/storage/
    echo "✅ Application storage deleted"
else
    echo "❌ Operation cancelled"
fi
```

**Alternative non-interactive approach**:

```bash
# [PROJECT_ROOT] Force remove without confirmation (use carefully!)
rm -rf application/storage/
echo "✅ Application storage deleted"
```

### 1.8.2 Verify Storage Cleanup

```bash
# [PROJECT_ROOT] Verify storage folder is gone
ls -la application/storage/ 2>/dev/null && \
  echo '❌ Storage folder still exists!' || echo '✅ Storage folder removed'

# [PROJECT_ROOT] Verify Docker volumes are clean (if Docker is running)
docker volume ls | grep torrust-tracker-demo && \
  echo '❌ Docker volumes still exist!' || echo '✅ No Docker volumes remain'
```

**Expected Output**: Both checks should show "✅" (clean state).

**What This Achieves**: Ensures a completely clean application state for testing,
preventing issues caused by:

- Corrupted database data from previous tests
- Expired or invalid SSL certificates
- Configuration conflicts from previous deployments
- Stale application logs affecting debugging

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
# [PROJECT_ROOT] Test basic VM connectivity using SSH
make ssh

# Or test connectivity manually
VM_IP=$(cd infrastructure/terraform && tofu output -raw vm_ip)
ssh torrust@$VM_IP "echo 'VM is accessible'"
```

**Expected Output**:

- SSH connectivity test passes
- VM accessible message
- **Time**: ~5 seconds

### 4.2 Test Docker Installation

```bash
# [PROJECT_ROOT] Test Docker functionality via health check
make health-check

# Or test Docker manually via SSH
make ssh
# Then inside VM:
docker --version
docker compose version
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
# [PROJECT_ROOT] Deploy the application using twelve-factor workflow
make app-deploy
```

**Expected Output**:

- Repository cloned to `/home/torrust/github/torrust/torrust-tracker-demo`
- Environment file `.env` created from `.env.production`
- **Time**: ~30 seconds

**What This Creates**: Torrust Tracker Demo repository with environment
configuration.

### 4.4 Start Torrust Tracker Services

```bash
# [PROJECT_ROOT] Application deployment includes starting services
# Services are automatically started by 'make app-deploy'
# To verify services are running:
make health-check
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
# [PROJECT_ROOT] Test all endpoints via comprehensive health check
make health-check
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
# [PROJECT_ROOT] Test Prometheus and Grafana via health check
make health-check

# For detailed monitoring, connect via SSH to inspect services directly
make ssh
```

**Expected Output**:

- Prometheus health check passes
- Grafana health check passes
- **Time**: ~10 seconds

### 4.7 Run Complete Integration Test Suite

```bash
# [PROJECT_ROOT] Run complete E2E test (infrastructure + application + health)
make test
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
TOKEN="MyAccessToken"
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

# Should output: TRACKER_ADMIN_TOKEN=MyAccessToken
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

## Step 7: External Smoke Testing with Official Client Tools

This step validates the Torrust Tracker deployment using the official Torrust
Tracker Client tools from an external perspective, simulating real BitTorrent
client interactions.

### 7.1 Setup Torrust Tracker Client Tools

The smoke tests require the official `torrust-tracker-client` tools. These are
**not published on crates.io** and must be compiled from the tracker repository source.

#### 7.1.1 Check for Existing Torrust Tracker Repository

**Priority**: Use existing local installation to avoid long compilation times.

```bash
# [PROJECT_ROOT] Check for torrust-tracker in parent directory (preferred)
if [ -d "../torrust-tracker" ]; then
    echo "✅ Found torrust-tracker in parent directory"
    TRACKER_DIR="../torrust-tracker"
elif [ -d "/home/$(whoami)/Documents/git/committer/me/github/torrust/torrust-tracker" ]; then
    echo "✅ Found torrust-tracker in standard location"
    TRACKER_DIR="/home/$(whoami)/Documents/git/committer/me/github/torrust/torrust-tracker"
else
    echo "❌ torrust-tracker repository not found"
    echo "Please clone it first or specify the path manually"
    TRACKER_DIR=""
fi

echo "Using tracker directory: $TRACKER_DIR"
```

#### 7.1.2 Verify Client Tools Availability

```bash
# [PROJECT_ROOT] Check if client tools are available
if [ -n "$TRACKER_DIR" ] && [ -d "$TRACKER_DIR" ]; then
    cd "$TRACKER_DIR"

    # Verify we're in the right directory
    ls Cargo.toml >/dev/null 2>&1 || (echo "❌ Not a valid torrust-tracker directory" && exit 1)

    # Check available client binaries
    echo "=== Available client tools ==="
    ls -la src/bin/ | grep -E "(client|checker)" || echo "No client tools found"

    # Test that client tools can be run (shows help/usage)
    echo "=== Testing client tool availability ==="
    cargo run -p torrust-tracker-client --bin udp_tracker_client -- --help >/dev/null 2>&1 && \
        echo "✅ udp_tracker_client available" || echo "❌ udp_tracker_client not available"

    cargo run -p torrust-tracker-client --bin http_tracker_client -- --help >/dev/null 2>&1 && \
        echo "✅ http_tracker_client available" || echo "❌ http_tracker_client not available"

    cargo run -p torrust-tracker-client --bin tracker_checker -- --help >/dev/null 2>&1 && \
        echo "✅ tracker_checker available" || echo "❌ tracker_checker not available"

    # Return to original directory
    cd - >/dev/null
else
    echo "❌ Cannot verify client tools - tracker directory not found"
    echo "Please clone torrust-tracker repository:"
    echo "git clone https://github.com/torrust/torrust-tracker"
fi
```

#### 7.1.3 Alternative: Clone if Not Available

```bash
# [PROJECT_ROOT] Clone torrust-tracker if not found locally
if [ -z "$TRACKER_DIR" ]; then
    echo "=== Cloning torrust-tracker repository ==="
    git clone https://github.com/torrust/torrust-tracker
    TRACKER_DIR="./torrust-tracker"
    echo "✅ Repository cloned to $TRACKER_DIR"
    echo "⚠️  Note: First compilation will take significant time"
fi
```

### 7.2 Run UDP Tracker Smoke Tests

```bash
# [PROJECT_ROOT] Get VM IP for testing
VM_IP=$(cd infrastructure/terraform && tofu output -raw vm_ip)
echo "Testing against VM: $VM_IP"

# [PROJECT_ROOT] Test UDP tracker on port 6868
echo "=== Testing UDP Tracker (6868) ==="
cd "$TRACKER_DIR"
cargo run -p torrust-tracker-client --bin udp_tracker_client announce \
  udp://$VM_IP:6868/announce \
  9c38422213e30bff212b30c360d26f9a02136422 | jq

# [PROJECT_ROOT] Test UDP tracker on port 6969
echo "=== Testing UDP Tracker (6969) ==="
cargo run -p torrust-tracker-client --bin udp_tracker_client announce \
  udp://$VM_IP:6969/announce \
  9c38422213e30bff212b30c360d26f9a02136422 | jq

cd - >/dev/null
```

**Expected Output** (for both UDP trackers):

```json
{
  "transaction_id": 2425393296,
  "announce_response": {
    "interval": 120,
    "leechers": 0,
    "seeders": 0,
    "peers": []
  }
}
```

### 7.3 Run HTTP Tracker Smoke Tests

#### 7.3.1 Test Through Nginx Proxy (Expected to Work)

```bash
# [PROJECT_ROOT] Test HTTP tracker through nginx proxy on port 80
echo "=== Testing HTTP Tracker through Nginx Proxy (80) ==="
cd "$TRACKER_DIR"
cargo run -p torrust-tracker-client --bin http_tracker_client announce \
  http://$VM_IP:80 \
  9c38422213e30bff212b30c360d26f9a02136422 | jq

cd - >/dev/null
```

**Expected Output**:

```json
{
  "complete": 1,
  "incomplete": 0,
  "interval": 300,
  "min interval": 300,
  "peers": [
    {
      "ip": "192.168.122.1",
      "peer id": [
        45, 113, 66, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48,
        48, 49
      ],
      "port": 47401
    }
  ]
}
```

#### 7.3.2 Test Direct Access (Expected to Fail)

```bash
# [PROJECT_ROOT] Test HTTP tracker directly on port 7070 (expected to fail)
echo "=== Testing HTTP Tracker Direct (7070) - Expected to fail ==="
cd "$TRACKER_DIR"
cargo run -p torrust-tracker-client --bin http_tracker_client announce \
  http://$VM_IP:7070 \
  9c38422213e30bff212b30c360d26f9a02136422 | jq || \
  echo "✅ Expected failure - tracker correctly configured for reverse proxy mode"

cd - >/dev/null
```

**Expected Behavior**: Should fail with an error about missing `X-Forwarded-For`
header, confirming the tracker is correctly configured for reverse proxy mode.

### 7.4 Run Comprehensive Tracker Checker

```bash
# [PROJECT_ROOT] Run comprehensive checker
echo "=== Running Comprehensive Tracker Checker ==="
cd "$TRACKER_DIR"

# Configure tracker checker for the test environment
export TORRUST_CHECKER_CONFIG='{
    "udp_trackers": ["udp://'$VM_IP':6969/announce"],
    "http_trackers": ["http://'$VM_IP':80"],
    "health_checks": ["http://'$VM_IP'/api/health_check"]
}'

cargo run -p torrust-tracker-client --bin tracker_checker

cd - >/dev/null
```

**Expected Output**: Status report for all configured endpoints showing
successful connections and responses.

### 7.5 Smoke Test Results Interpretation

#### ✅ Success Indicators

All smoke tests should show:

- **UDP Trackers**: JSON responses with interval/peer data and transaction IDs
- **HTTP Tracker** (via proxy): JSON response with tracker statistics and peer information
- **Health Check**: Successful connection through comprehensive checker
- **Response Times**: Sub-second response times for all endpoints

#### ❌ Common Issues and Solutions

**Compilation Errors**:

```bash
# If Rust compilation fails, ensure Rust is installed
cargo --version || curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Update Rust if compilation issues persist
rustup update
```

**Connection Refused**:

```bash
# Verify VM is running and services are up
ssh torrust@$VM_IP \
  'cd /home/torrust/github/torrust/torrust-tracker-demo/application && docker compose ps'

# Check if tracker ports are accessible
nc -zv $VM_IP 6868  # UDP tracker port 1
nc -zv $VM_IP 6969  # UDP tracker port 2
nc -zv $VM_IP 80    # HTTP proxy port
```

**UDP Connection Issues**:

```bash
# Check firewall rules on VM
ssh torrust@$VM_IP "sudo ufw status | grep -E '(6868|6969)'"

# Verify UDP ports are bound
ssh torrust@$VM_IP "sudo netstat -ulnp | grep -E '(6868|6969)'"
```

### 7.6 Performance Validation

```bash
# [PROJECT_ROOT] Measure response times for performance validation
echo "=== Performance Testing ==="

# Time UDP responses
time (cd "$TRACKER_DIR" && cargo run -p torrust-tracker-client --bin udp_tracker_client announce \
  udp://$VM_IP:6969/announce \
  9c38422213e30bff212b30c360d26f9a02136422 >/dev/null)

# Time HTTP responses
time (cd "$TRACKER_DIR" && cargo run -p torrust-tracker-client --bin http_tracker_client announce \
  http://$VM_IP:80 \
  9c38422213e30bff212b30c360d26f9a02136422 >/dev/null)
```

**Expected Performance**:

- **UDP requests**: < 1 second response time
- **HTTP requests**: < 2 seconds response time
- **No errors**: All requests should complete successfully

---

## Step 8: Cleanup

### 8.1 Stop Services (if needed)

```bash
# [PROJECT_ROOT] Stop services via SSH if needed
make ssh
# Then inside VM:
cd /home/torrust/github/torrust/torrust-tracker-demo/application
docker compose down
```

### 8.2 Destroy VM and Clean Up

```bash
# [PROJECT_ROOT] Destroy the VM and clean up resources
time make destroy
```

**Expected Output**:

- All resources destroyed
- State files cleaned
- **Time**: ~30 seconds

### 8.3 Final Cleanup

```bash
# [PROJECT_ROOT] Complete cleanup
make clean
```

**Expected Output**:

- Temporary files removed
- Lock files cleaned

---

---

## Step 9: Key Testing Insights and Best Practices

### 9.1 Critical Architecture Understanding

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

### 9.2 Correct Testing Procedures

#### ✅ Proper API Testing

```bash
# Get VM IP
VM_IP=$(cd infrastructure/terraform && tofu output -raw vm_ip)

# Test health (no auth needed)
curl -s http://$VM_IP/api/health_check | jq .

# Test stats (auth required)
curl -s "http://$VM_IP/api/v1/stats?token=MyAccessToken" | jq .

# Test specific metrics with jq filtering
curl -s "http://$VM_IP/api/v1/stats?token=MyAccessToken" | jq '.torrents, .seeders, .leechers'
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

### 9.3 Common Testing Mistakes

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
curl "http://$VM_IP/api/v1/stats?token=MyAccessToken"
```

### 9.4 Health Check Limitations

The automated health check script (`make health-check`) provides comprehensive
validation but may need tuning for specific scenarios:

1. **Timeouts**: Some tests use conservative timeouts that may be slow
2. **Test Coverage**: Focuses on connectivity rather than functional testing
3. **Verbose Output**: Use `VERBOSE=true make health-check` for detailed results

**Manual testing** (as shown in this guide) provides more detailed functional
validation and better insight into the actual API behavior.

### 9.5 Useful Testing Commands

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
- Commands like `make infra-apply` failing with file not found errors

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

**Total Time**: ~8-12 minutes for complete cycle (including external smoke testing)

### Integration Testing Results Summary

✅ **INTEGRATION TESTS NOW PASS COMPLETELY!**

This guide provides a complete integration testing workflow that:

1. **Creates fresh infrastructure** in ~3-5 minutes
2. **Generates configuration files** from templates (~2 seconds)
3. **Refreshes OpenTofu state** to detect VM IP (~3 seconds)
4. **Waits for cloud-init** to complete (~2-3 minutes)
5. **Runs comprehensive tests** covering all services (~3-5 minutes)
6. **Performs external smoke testing** using official Torrust client tools (~2-3 minutes)
7. **Verifies end-to-end functionality** of the Torrust Tracker
8. **Cleans up resources** when complete (~1 minute)

**Total Time**: ~8-12 minutes for complete cycle

### ✅ Successful Test Results (Latest Run)

During the most recent testing cycle, the following components were validated successfully:

#### Infrastructure Tests

- ✅ **VM Access**: SSH connectivity working at `192.168.122.54`
- ✅ **Docker Installation**: Docker 28.3.1 and Docker Compose V2.38.1 working
- ✅ **Service Health**: All containers running with healthy status

#### Service Deployment

- ✅ **MySQL**: Database running healthy with proper credentials
- ✅ **Tracker**: Torrust Tracker running with all endpoints active
- ✅ **Prometheus**: Metrics collection working
- ✅ **Grafana**: Dashboard service healthy (version 11.4.0)
- ✅ **Nginx Proxy**: Reverse proxy routing working correctly

#### API and Endpoint Tests

- ✅ **Health Check API**: `{"status":"Ok"}` via nginx proxy on port 80
- ✅ **Statistics API**: Full stats JSON with admin token authentication
- ✅ **UDP Tracker Ports**: 6868 and 6969 listening on both IPv4 and IPv6
- ✅ **Monitoring Services**: Grafana and Prometheus both healthy

#### Final Test Output

```console
[SUCCESS] All integration tests passed!
```

### Critical Configuration Details

#### Authentication Requirements

- **Health Check API**: `/api/health_check` - No authentication required
- **Stats API**: `/api/v1/stats` - **Requires authentication token**
- **Admin Token**: `MyAccessToken` (from `.env` file)

#### Correct API Testing Examples

```bash
# Health check (no auth needed)
curl -s http://$VM_IP/api/health_check | jq .

# Stats API (auth required)
curl -s "http://$VM_IP/api/v1/stats?token=MyAccessToken" | jq .
```

#### Network Architecture

The deployment uses **nginx proxy** on port 80 that routes to internal services:

- `/api/*` → routes to tracker service (internal port 1212)
- Internal Docker ports (1212, 7070, 9090) are NOT accessible from outside the VM
- UDP ports (6868, 6969) are directly exposed for tracker protocol

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
