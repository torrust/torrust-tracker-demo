# Hetzner Cloud Provider Setup Guide

This guide explains how to set up and use the Hetzner Cloud provider with the Torrust Tracker Demo.

## Prerequisites

1. **Hetzner Cloud Account**: Create an account at [console.hetzner.cloud](https://console.hetzner.cloud/)
2. **API Token**: Generate an API token in your Hetzner Cloud project
3. **SSH Key**: Ensure you have an SSH key pair for server access

## Step 1: Create Hetzner Cloud Account

1. Visit [console.hetzner.cloud](https://console.hetzner.cloud/)
2. Sign up for a new account or log in to existing account
3. Create a new project or use an existing one

## Step 2: Generate API Token

1. In the Hetzner Cloud Console, navigate to your project
2. Go to **Security** → **API Tokens**
3. Click **Generate API Token**
4. Give it a descriptive name (e.g., "torrust-tracker-demo")
5. Set permissions to **Read & Write**
6. Copy the generated token (64 characters)

## Step 3: Configure Provider

1. Copy the provider configuration template:

   ```bash
   cp infrastructure/config/providers/hetzner.env.tpl infrastructure/config/providers/hetzner.env
   ```

2. Edit the configuration file:

   ```bash
   vim infrastructure/config/providers/hetzner.env
   ```

3. Replace the placeholder values:

   ```bash
   # Required: Your Hetzner API token
   HETZNER_TOKEN=your_64_character_token_here

   # Optional: Customize server settings
   HETZNER_SERVER_TYPE=cx31          # 2 vCPU, 8GB RAM, 80GB SSD
   HETZNER_LOCATION=nbg1             # Nuremberg, Germany
   HETZNER_IMAGE=ubuntu-24.04
   ```

## Step 4: Configure Environment

For production deployment, create a production environment:

1. Copy the environment template:

   ```bash
   cp infrastructure/config/environments/production.env.tpl infrastructure/config/environments/production.env
   ```

2. Edit the production configuration:

   ```bash
   vim infrastructure/config/environments/production.env
   ```

3. Replace all placeholder values:

   ```bash
   # Critical: Replace these with secure values
   DOMAIN_NAME=tracker.yourdomain.com
   CERTBOT_EMAIL=admin@yourdomain.com
   MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
   MYSQL_PASSWORD=$(openssl rand -base64 32)
   TRACKER_ADMIN_TOKEN=$(openssl rand -base64 32)
   GF_SECURITY_ADMIN_PASSWORD=$(openssl rand -base64 32)
   ```

## Step 5: Deploy Infrastructure

1. Export your Hetzner token:

   ```bash
   export HETZNER_TOKEN=your_64_character_token_here
   ```

2. Initialize Terraform:

   ```bash
   make infra-init ENVIRONMENT=production PROVIDER=hetzner
   ```

3. Plan the deployment:

   ```bash
   make infra-plan ENVIRONMENT=production PROVIDER=hetzner
   ```

4. Apply the infrastructure:

   ```bash
   make infra-apply ENVIRONMENT=production PROVIDER=hetzner
   ```

5. Deploy the application:

   ```bash
   make app-deploy ENVIRONMENT=production
   ```

## Step 5.5: Optional - Configure Persistent Volume for Data Persistence

**Important**: By default, all data is stored on the main server disk and will be lost
when the server is destroyed. For production environments where you need data persistence
across server recreation, you must manually set up a persistent volume.

### Why Manual Volume Setup?

- **Provider Flexibility**: Not all providers create additional volumes automatically
- **Administrative Control**: Sysadmins have full control over storage configuration
- **Cost Management**: Volumes can be expensive; optional setup allows cost optimization
- **Deployment Simplicity**: Basic deployment works without additional storage setup
- **Hetzner Cloud Limitation**: As of August 2025, Hetzner has a known issue where servers
  cannot be created with attached volumes during provisioning
  ([Status Page](https://status.hetzner.com/incident/579034f0-194d-4b44-bc0a-cdac41abd753))

**Important**: Even if this architectural decision changes in the future, the current
Hetzner Cloud service limitation makes manual volume attachment the only reliable approach.

### Setting Up Persistent Volume (Optional)

**When to do this**: After infrastructure provisioning but BEFORE application deployment.

1. **Create and attach volume in Hetzner Cloud Console**:

   ```bash
   # Create a 20GB volume for persistent data
   HCLOUD_TOKEN="$HETZNER_TOKEN" hcloud volume create \
     --name torrust-data \
     --size 20 \
     --location fsn1

   # Attach volume to server
   HCLOUD_TOKEN="$HETZNER_TOKEN" hcloud volume attach \
     torrust-data torrust-tracker-prod
   ```

2. **Format and mount the volume** (SSH into server):

   ```bash
   # SSH into the server
   ssh torrust@YOUR_SERVER_IP

   # Format the volume (usually /dev/sdb for first additional volume)
   sudo mkfs.ext4 /dev/sdb

   # Create mount point
   sudo mkdir -p /var/lib/torrust

   # Mount the volume
   sudo mount /dev/sdb /var/lib/torrust

   # Set proper ownership
   sudo chown -R torrust:torrust /var/lib/torrust

   # Add to fstab for permanent mounting
   echo '/dev/sdb /var/lib/torrust ext4 defaults,noatime 0 2' | sudo tee -a /etc/fstab
   ```

3. **Verify setup**:

   ```bash
   # Check mount
   df -h /var/lib/torrust

   # Verify ownership
   ls -la /var/lib/torrust
   ```

### Data Persistence Options

| Setup Type                     | Data Persistence              | Cost   | Complexity | Use Case             |
| ------------------------------ | ----------------------------- | ------ | ---------- | -------------------- |
| **Main Disk Only** (Default)   | ❌ Lost on server destruction | Lower  | Simple     | Testing, development |
| **Persistent Volume** (Manual) | ✅ Survives server recreation | Higher | Medium     | Production, staging  |

### What Gets Persisted

With persistent volume setup:

- ✅ Database data (MySQL)
- ✅ Configuration files (.env, tracker.toml)
- ✅ SSL certificates and keys
- ✅ Application logs and state
- ✅ Prometheus metrics data

Without persistent volume:

- ❌ All data lost when server is destroyed
- ✅ Infrastructure can be recreated identically
- ✅ Configuration regenerated from templates

## Step 6: Verify Deployment

1. Check infrastructure status:

   ```bash
   make infra-status ENVIRONMENT=production PROVIDER=hetzner
   ```

2. Test SSH access:

   ```bash
   make vm-ssh ENVIRONMENT=production
   ```

3. Verify application health:

   ```bash
   make app-health-check ENVIRONMENT=production
   ```

### Manual Verification

You can also manually verify the deployment by testing the HTTPS endpoints:

```bash
# Get the server IP from infrastructure status
export SERVER_IP=$(make infra-status ENVIRONMENT=production PROVIDER=hetzner | \
  grep vm_ip | cut -d'"' -f2)

# Test HTTPS health check endpoint
curl -k https://$SERVER_IP/health_check

# Expected response:
# {"status":"Ok"}

# Test HTTPS API endpoints (replace with your actual admin token)
curl -k "https://$SERVER_IP/api/v1/stats?token=your_admin_token_here"

# Test tracker announce endpoints
curl -k "https://$SERVER_IP/announce?info_hash=your_info_hash&peer_id=your_peer_id&port=8080"
```

**Note**: The `-k` flag is used to skip SSL certificate verification since we're using
self-signed certificates for testing. In production with proper domain names, you would
use Let's Encrypt certificates and remove the `-k` flag.

### Deployment Success Indicators

A successful deployment should show:

✅ **Infrastructure**: Server created and running in Hetzner Cloud Console  
✅ **SSH Access**: Can connect via `ssh torrust@SERVER_IP`  
✅ **HTTPS Health Check**: `https://SERVER_IP/health_check` returns `{"status":"Ok"}`  
✅ **Docker Services**: All containers running via `docker compose ps`  
✅ **API Access**: Statistics endpoint accessible with admin token  
✅ **Tracker Functionality**: UDP and HTTP tracker endpoints responding

**Verified Working (August 2025)**: HTTPS endpoint `https://138.199.166.49/health_check`
successfully returns the expected JSON response, confirming SSL certificate generation
and nginx proxy configuration are working correctly.

### Current Implementation Status

**✅ Successfully Implemented**:

- **Hetzner Cloud Provider**: Complete infrastructure provisioning
- **Cloud-init Configuration**: Fixed for providers without additional volumes
- **Self-signed SSL Certificates**: Automatic generation and nginx configuration
- **Docker Services**: All services running with proper orchestration
- **Persistent Volume Architecture**: Configuration stored in `/var/lib/torrust`
- **Twelve-Factor Deployment**: Complete Build/Release/Run stages working

**📋 Manual Setup Required**:

- **Persistent Volumes**: Must be created and mounted manually for data persistence
- **Domain Configuration**: Point your domain to server IP for Let's Encrypt SSL
- **Production Secrets**: Replace default tokens with secure values

**🔄 Future Enhancements**:

- **Automatic Volume Creation**: Providers could optionally create persistent volumes
- **Let's Encrypt Integration**: Automatic SSL for real domains
- **Health Check Integration**: Automated validation in deployment pipeline

## Server Types and Pricing

Choose the appropriate server type based on your needs. **Note**: Server types are subject to change
by Hetzner. Use `hcloud server-type list` for current availability.

### Current Server Types (as of August 2025)

| Type  | vCPU | RAM  | Storage   | Price/Month\* | CPU Type   | Use Case         |
| ----- | ---- | ---- | --------- | ------------- | ---------- | ---------------- |
| cx22  | 2    | 4GB  | 40GB SSD  | ~€5.83        | Shared     | Light staging    |
| cx32  | 4    | 8GB  | 80GB SSD  | ~€8.21        | Shared     | **Recommended**  |
| cx42  | 8    | 16GB | 160GB SSD | ~€15.99       | Shared     | High traffic     |
| cx52  | 16   | 32GB | 320GB SSD | ~€31.67       | Shared     | Heavy workloads  |
| cpx11 | 2    | 2GB  | 40GB SSD  | ~€4.15        | AMD Shared | Testing only     |
| cpx21 | 3    | 4GB  | 80GB SSD  | ~€7.05        | AMD Shared | Light production |
| cpx31 | 4    | 8GB  | 160GB SSD | ~€13.85       | AMD Shared | Production       |
| ccx13 | 2    | 8GB  | 80GB SSD  | ~€13.85       | Dedicated  | CPU-intensive    |

\*Prices are approximate and may vary. Check Hetzner Cloud Console for current pricing.

## Datacenter Locations

**Note**: Locations are subject to change. Use `hcloud location list` for current availability.

| Code | Location              | Network Zone | Country | Description                  |
| ---- | --------------------- | ------------ | ------- | ---------------------------- |
| fsn1 | Falkenstein DC Park 1 | eu-central   | DE      | **Default** - EU alternative |
| nbg1 | Nuremberg DC Park 1   | eu-central   | DE      | EU, good latency             |
| hel1 | Helsinki DC Park 1    | eu-central   | FI      | Northern Europe              |
| ash  | Ashburn, VA           | us-east      | US      | US East Coast                |
| hil  | Hillsboro, OR         | us-west      | US      | US West Coast                |
| sin  | Singapore             | ap-southeast | SG      | Asia Pacific                 |

## Security Considerations

1. **API Token Security**: Store your token securely, never commit it to version control
2. **SSH Key Management**: Use strong SSH keys, rotate regularly
3. **Firewall**: The provider automatically configures necessary firewall rules
4. **SSL**: Production configuration includes automatic SSL certificates via Let's Encrypt
5. **Updates**: Enable automatic security updates in production

## Cost Management

1. **Development**: Use `cx21` or `cx31` for cost-effective development
2. **Staging**: `cx21` is usually sufficient for staging environments
3. **Production**: `cx31` recommended for most production workloads
4. **Monitoring**: Set up billing alerts in Hetzner Cloud Console
5. **Cleanup**: Always destroy infrastructure when not needed:

   ```bash
   make infra-destroy ENVIRONMENT=production PROVIDER=hetzner
   ```

## Troubleshooting

## Troubleshooting

### Common Issues

#### 1. "server type not found" Error

**Problem**: Error message `server type cx31 not found` during deployment.

**Cause**: Hetzner Cloud server types change over time. Some older types may be deprecated or renamed.

**Solution**:

1. Get current server types:

   ```bash
   # Install hcloud CLI if not installed
   sudo apt install golang-go
   go install github.com/hetznercloud/cli/cmd/hcloud@latest
   export PATH=$PATH:$(go env GOPATH)/bin

   # List current server types
   HCLOUD_TOKEN="$HETZNER_TOKEN" hcloud server-type list
   ```

2. Update your configuration with a valid server type:

   ```bash
   vim infrastructure/config/providers/hetzner.env
   # Change HETZNER_SERVER_TYPE to a valid type (e.g., cx32)
   ```

#### 2. Invalid Token Error

**Problem**: Token validation fails with "malformed token" or 35-character length.

**Cause**: Using placeholder token or incorrect token format.

**Solution**:

1. Ensure token is exactly 64 characters
2. Verify token has Read & Write permissions
3. Check token is correctly set in both:
   - `infrastructure/config/providers/hetzner.env`
   - Environment variable: `export HETZNER_TOKEN=your_token_here`

#### 3. Provider Configuration Variable Collision

**Problem**: Error "Configuration script not found" in provider directory.

**Cause**: Variable name collision between main provisioning script and provider script.

**Solution**: This has been fixed in the codebase by using `PROVIDER_DIR` instead of `SCRIPT_DIR`
in provider scripts.

#### 4. Region/Location Issues

**Problem**: Some regions may have capacity limits or server type availability issues.

**Solution**:

1. Check current locations:

   ```bash
   HCLOUD_TOKEN="$HETZNER_TOKEN" hcloud location list
   ```

2. Try different locations:

   ```bash
   # Edit provider configuration
   vim infrastructure/config/providers/hetzner.env
   # Change HETZNER_LOCATION (e.g., fsn1, nbg1, hel1)
   ```

#### 5. SSH Access Issues

**Problem**: Cannot SSH to deployed server.

**Solutions**:

- Verify SSH key is properly configured and accessible
- Check if server is fully booted (cloud-init can take 5-10 minutes)
- Verify firewall rules allow SSH (port 22)

#### 6. SSH Connection Refused (Cloud-init Still Running)

**Problem**: SSH connection is refused with "Connection refused" error.

**Cause**: Cloud-init is still configuring the system and SSH service hasn't been started yet.
This is normal during initial deployment.

**Symptoms**:

```bash
ssh: connect to host X.X.X.X port 22: Connection refused
```

**Diagnosis**:

1. Access server console through Hetzner Cloud Console
2. Check system status:

   ```bash
   systemctl is-system-running
   # Output: "maintenance" means cloud-init is still running
   ```

3. Check cloud-init progress:

   ```bash
   sudo cloud-init status
   # Output: "status: running" means configuration is in progress
   ```

4. Check SSH service status:

   ```bash
   systemctl status ssh
   # May show "inactive" or "not found" if not yet configured
   ```

5. Monitor what cloud-init is currently doing:

   ```bash
   sudo tail -f /var/log/cloud-init-output.log
   # Shows current installation/configuration progress

   # Alternative: Check which packages are being installed
   ps aux | grep -E "(apt|dpkg|cloud-init)"
   ```

**Solution**: Wait for cloud-init to complete. This process typically takes 5-20 minutes and includes:

- Package updates and installations (Docker, Git, etc.)
- User and SSH key configuration
- SSH service installation and startup
- Firewall setup
- Repository cloning
- System optimization

**Expected Timeline**:

- 0-5 minutes: Package updates and system configuration
- 5-10 minutes: Docker installation and user setup
- 10-15 minutes: SSH service starts, connection becomes available
- 15-20 minutes: Final repository cloning and system optimization

The system will automatically transition to "running" state and SSH will become available when complete.

#### 7. Cloud-init Failure During Network Stage

**Problem**: Cloud-init fails with exit status 1 during network stage.

**Symptoms**:

```bash
cloud-init.service: Main process exited, code=exited, status=1/FAILURE
cloud-init.service: Failed with result 'exit-code'
Failed to start cloud-init.service - Cloud-init: Network Stage.
```

**Cause**: Network configuration issues, package repository problems, or cloud-init template errors.

**Diagnosis**:

1. Check cloud-init logs for specific errors:

   ```bash
   # Check detailed cloud-init logs
   sudo cat /var/log/cloud-init.log
   sudo cat /var/log/cloud-init-output.log

   # Check for network issues
   sudo journalctl -u cloud-init
   sudo journalctl -u systemd-networkd
   ```

2. Test basic connectivity:

   ```bash
   # Test network connectivity
   ping -c 3 8.8.8.8
   ping -c 3 archive.ubuntu.com

   # Check DNS resolution
   nslookup archive.ubuntu.com
   ```

3. Check package repositories:

   ```bash
   # Test package manager
   sudo apt update
   sudo apt list --upgradable
   ```

**Recovery Methods**:

**Method 1: Manual System Setup** (Recommended if cloud-init failed early)

Since cloud-init failed, manually configure the essential components:

```bash
# 1. Create torrust user
sudo useradd -m -s /bin/bash torrust
sudo usermod -aG sudo torrust

# 2. Add SSH key for torrust user
sudo mkdir -p /home/torrust/.ssh
sudo chmod 700 /home/torrust/.ssh

# 3. Add the SSH key from cloud-init template
# Replace with your actual public key:
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC..." | sudo tee /home/torrust/.ssh/authorized_keys
sudo chmod 600 /home/torrust/.ssh/authorized_keys
sudo chown -R torrust:torrust /home/torrust/.ssh

# 4. Install and start SSH service
sudo apt update
sudo apt install -y openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh

# 5. Test SSH access
sudo systemctl status ssh
```

**Method 2: Re-run Cloud-init** (If network issues are resolved)

```bash
# Clean cloud-init state and re-run
sudo cloud-init clean
sudo cloud-init init
sudo cloud-init modules --mode config
sudo cloud-init modules --mode final
```

**Recovery Method (If SSH Still Fails)**:

If cloud-init completes but SSH access still fails, you can add a backup SSH key:

**Note**: If using Hetzner web console, you may encounter keyboard layout issues where `|`
becomes `/`. Use alternative commands without pipes.

1. **Add SSH Key via Hetzner Console**:

   - Go to Hetzner Cloud Console → Server → torrust-tracker-prod
   - Click **"Rescue"** tab
   - Enable rescue system with your personal SSH key
   - Reboot into rescue mode
   - Mount the main filesystem and debug

2. **Alternative - Add Key to Running Server**:

   - Access server via Hetzner web console
   - Add your personal public key manually:

     ```bash
     # As root in console
     mkdir -p /home/torrust/.ssh
     echo "your-personal-ssh-public-key-here" >> /home/torrust/.ssh/authorized_keys
     chown -R torrust:torrust /home/torrust/.ssh
     chmod 700 /home/torrust/.ssh
     chmod 600 /home/torrust/.ssh/authorized_keys

     # Test SSH service
     systemctl status ssh
     systemctl start ssh  # if needed
     ```

3. **Then SSH with personal key**:

   ```bash
   ssh -i ~/.ssh/your-personal-key torrust@138.199.166.49
   ```

#### 8. Billing Issues

**Problem**: Deployment fails due to insufficient credits.

**Solution**: Ensure account has sufficient credits/payment method configured in Hetzner Cloud Console.

#### 9. Volume Attachment Issues (Current Hetzner Limitation)

**Problem**: Attempting to create servers with volumes attached during provisioning fails.

**Cause**: Hetzner Cloud currently has a service limitation preventing volume attachment
during server creation (as of August 2025).

**Official Status**: [Hetzner Cloud Status - Volume Attachment Issue](https://status.hetzner.com/incident/579034f0-194d-4b44-bc0a-cdac41abd753)

**Solution**: This is exactly why our architecture uses manual volume setup:

1. **Create server first** without any volumes attached
2. **After server is running**, create and attach volumes separately
3. **SSH into server** and manually format/mount the volume

This limitation validates our architectural decision to make volume setup manual and optional.

### Debug Commands

```bash
# Check current server types and availability
HCLOUD_TOKEN="$HETZNER_TOKEN" hcloud server-type list

# Check available locations
HCLOUD_TOKEN="$HETZNER_TOKEN" hcloud location list

# Validate configuration without applying
make infra-plan ENVIRONMENT=production-hetzner PROVIDER=hetzner

# Check infrastructure status
make infra-status ENVIRONMENT=production-hetzner PROVIDER=hetzner

# Access server console
make vm-ssh ENVIRONMENT=production-hetzner

# Check server details (after deployment)
HCLOUD_TOKEN="$HETZNER_TOKEN" hcloud server list
HCLOUD_TOKEN="$HETZNER_TOKEN" hcloud server describe torrust-tracker-prod
```

### Real-Time Information Commands

Always verify current Hetzner Cloud offerings before deployment:

```bash
# Get current server types with pricing
HCLOUD_TOKEN="$HETZNER_TOKEN" hcloud server-type list

# Get current datacenter locations
HCLOUD_TOKEN="$HETZNER_TOKEN" hcloud location list

# Check image availability
HCLOUD_TOKEN="$HETZNER_TOKEN" hcloud image list --type=system | grep ubuntu
```

## Docker Compose Commands on Deployed Server

**Important**: The Torrust Tracker Demo uses a persistent volume approach where all
configuration files are stored in `/var/lib/torrust` for backup and snapshot purposes.
When running Docker Compose commands on the deployed server, you must specify the
correct environment file location.

### Correct Docker Compose Usage

All Docker Compose commands must be run from the application directory with the `--env-file` parameter:

```bash
# Connect to server
ssh torrust@YOUR_SERVER_IP

# Navigate to application directory
cd /home/torrust/github/torrust/torrust-tracker-demo/application

# Run Docker Compose commands with explicit env-file path
docker compose --env-file /var/lib/torrust/compose/.env up -d
docker compose --env-file /var/lib/torrust/compose/.env ps
docker compose --env-file /var/lib/torrust/compose/.env logs
docker compose --env-file /var/lib/torrust/compose/.env down
```

### Why Environment Files Are in /var/lib/torrust

- **Persistent Volume**: All configuration is stored in `/var/lib/torrust` for persistence
- **Backup Strategy**: You can snapshot only the volume instead of the entire server
- **Configuration Management**: All environment variables are centrally managed
- **Infrastructure Separation**: Configuration survives server recreation

### File Locations

```bash
# Environment file for Docker Compose
/var/lib/torrust/compose/.env

# Application configuration files
/var/lib/torrust/tracker/etc/tracker.toml
/var/lib/torrust/proxy/etc/nginx-conf/nginx.conf
/var/lib/torrust/prometheus/etc/prometheus.yml

# Persistent data
/var/lib/torrust/mysql/       # Database data
/var/lib/torrust/proxy/certs/ # SSL certificates
```

### Common Commands

```bash
# Check service status
docker compose --env-file /var/lib/torrust/compose/.env ps

# View service logs
docker compose --env-file /var/lib/torrust/compose/.env logs tracker

# Restart specific service
docker compose --env-file /var/lib/torrust/compose/.env restart tracker

# Update and restart all services
docker compose --env-file /var/lib/torrust/compose/.env pull
docker compose --env-file /var/lib/torrust/compose/.env up -d

# Stop all services
docker compose --env-file /var/lib/torrust/compose/.env down
```

### Getting Help

1. **Hetzner Documentation**: [docs.hetzner.com](https://docs.hetzner.com/)
2. **Community**: [community.hetzner.com](https://community.hetzner.com/)
3. **Support**: Available through Hetzner Cloud Console
4. **Terraform Provider**: [registry.terraform.io/providers/hetznercloud/hcloud](https://registry.terraform.io/providers/hetznercloud/hcloud)

## Next Steps

After successful deployment:

1. **DNS Configuration**: Point your domain to the server IP
2. **SSL Verification**: Ensure SSL certificates are properly issued
3. **Monitoring Setup**: Configure Grafana dashboards and alerts
4. **Backup Strategy**: Set up regular database backups
5. **Update Process**: Establish update and maintenance procedures
