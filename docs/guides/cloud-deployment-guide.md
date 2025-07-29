# Deployment Guide - Torrust Tracker Demo

> **Current Status**: Local development deployment (KVM/libvirt) is fully implemented.
> Cloud deployment (Hetzner) is planned for future implementation.

## Overview

This guide describes how to deploy the Torrust Tracker using the automated deployment
system. Currently, the system supports local KVM/libvirt deployment for development
and testing. Hetzner Cloud support is planned as the next implementation target.

The process combines Infrastructure as Code with application deployment automation to
provide a streamlined deployment experience, following twelve-factor app methodology.

## Prerequisites

### Local Requirements

- **OpenTofu** (or Terraform) installed
- **Git** for repository access
- **SSH client** for server access
- **Domain name** (required for HTTPS certificates in production)

### Cloud Provider Requirements (For Future Implementation)

When cloud providers are implemented, they will need:

- **Cloud-init support**: Required for automated provisioning
- **VM specifications**: Minimum 2GB RAM, 25GB disk space
- **Network access**: Ports 22, 80, 443, 6968/udp, 6969/udp must be accessible

### Currently Supported Providers

- ✅ **Local KVM/libvirt** (fully implemented for development/testing)

### Next Planned Provider

- 🚧 **Hetzner Cloud** (in development - Phase 4 of migration plan)

**Note**: Currently, only local KVM/libvirt deployment is implemented. Hetzner Cloud
support is the next priority in the migration plan. The architecture is designed to be
cloud-agnostic to facilitate adding cloud providers that support cloud-init in the future.

## Quick Start

### Current Implementation: Local Development

The current implementation supports local KVM/libvirt deployment, which is perfect
for development, testing, and understanding the system before cloud deployment.

### 1. Clone and Setup

```bash
# Clone the repository
git clone https://github.com/torrust/torrust-tracker-demo.git
cd torrust-tracker-demo

# Install dependencies (Ubuntu/Debian)
make install-deps

# Configure SSH access for VMs
make infra-config-local
```

### 2. Local Testing with KVM/libvirt

```bash
# Test deployment locally with KVM
make infra-apply ENVIRONMENT=local
make app-deploy ENVIRONMENT=local
make app-health-check

# Access the local instance
make vm-ssh

# Cleanup when done
make infra-destroy
```

### 3. Cloud Deployment (Planned - Hetzner)

**Note**: Cloud deployment is not yet implemented. The following commands show the
planned interface for future Hetzner Cloud deployment:

```bash
# Planned: Deploy infrastructure to Hetzner Cloud
make infra-apply ENVIRONMENT=production PROVIDER=hetzner

# Planned: Deploy application services
make app-deploy ENVIRONMENT=production

# Validate deployment
make app-health-check

# Get connection information
make infra-status
```

## Current Implementation Status

### ✅ Fully Implemented (Local KVM/libvirt)

The following steps are completely automated for local development:

1. **Infrastructure Provisioning**

   - VM creation and configuration via OpenTofu/libvirt
   - Firewall setup (UFW rules)
   - User account creation with SSH keys
   - Basic security hardening (fail2ban, automatic updates)

2. **System Setup**

   - Docker and Docker Compose installation
   - Required package installation
   - Network and volume configuration

3. **Application Deployment**

   - Repository cloning via cloud-init
   - Environment configuration from templates
   - Docker Compose service deployment
   - Database initialization (MySQL)
   - Service health validation

4. **Maintenance Automation** (Phase 3 - In Progress)
   - Database backup scheduling (planned)
   - SSL certificate renewal (planned for production)
   - Log rotation and cleanup

### 🚧 In Development

#### Phase 3: Complete Application Installation Automation

- SSL certificate automation for production
- MySQL backup automation
- Enhanced monitoring and maintenance

#### Phase 4: Hetzner Cloud Provider Implementation

- Hetzner Cloud OpenTofu provider integration
- Cloud-specific configurations and networking
- Production deployment validation

### ⚠️ Manual Steps (Current Limitations)

Due to current implementation status, these steps require manual intervention:

#### 1. Cloud Provider Setup

**Status**: Not yet implemented - local KVM/libvirt only

**Planned for Hetzner**: Cloud provider configuration, API tokens, network setup

#### 2. Grafana Monitoring Setup

**Status**: Manual setup required (intentionally not automated)

**Why manual?** Grafana setup allows customization of:

- Security credentials and user accounts
- Custom dashboard configurations
- Data source preferences and settings
- Monitoring requirements specific to your deployment

**When to do this:** After successful deployment of all services.

**Steps:** Follow the [Grafana Setup Guide](grafana-setup-guide.md) for complete instructions on:

1. Securing the default admin account
2. Configuring Prometheus data source
3. Importing pre-built dashboards
4. Creating custom monitoring panels

#### 3. Initial SSL Certificate Generation

**Status**: Will remain manual for production

**Why manual?** SSL certificate generation requires:

- Domain DNS resolution pointing to your server
- Server accessible via port 80 for HTTP challenge
- Cannot be tested with local VMs (no public domain)

**When to do this:** Only needed for production deployments with custom domains.

#### 4. Domain Configuration

**Status**: Manual (and will remain so)

**Steps:**

1. Point your domain's DNS A records to your server IP
2. Configure DNS records for subdomains
3. Optional: Add BEP 34 TXT records for tracker discovery

## Detailed Deployment Process

### Infrastructure Deployment

The infrastructure deployment creates and configures the VM:

```bash
# Deploy infrastructure
make infra-apply ENVIRONMENT=production

# What this does:
# 1. Creates VM with Ubuntu 24.04
# 2. Configures cloud-init for automated setup
# 3. Installs Docker, git, security tools
# 4. Sets up torrust user with SSH access
# 5. Configures firewall rules
# 6. Creates persistent data volume
```

### Application Deployment

The application deployment sets up all services:

```bash
# Deploy application
make app-deploy ENVIRONMENT=production

# What this does:
# 1. Clones torrust-tracker-demo repository
# 2. Generates .env configuration from templates
# 3. Starts Docker Compose services:
#    - MySQL database
#    - Torrust Tracker
#    - Nginx reverse proxy
#    - Prometheus monitoring
#    - Grafana dashboards
# 4. Configures automated maintenance tasks
# 5. Validates all service health
```

### Health Validation

```bash
# Validate deployment
make app-health-check

# What this checks:
# 1. All Docker services are running
# 2. Database connectivity and schema
# 3. Tracker API endpoints responding
# 4. Network connectivity on all ports
# 5. Backup system configuration
# 6. Monitoring system status
```

## Post-Deployment Configuration

### Required Manual Setup

After successful deployment, you'll need to complete these manual configuration steps
to have a fully functional tracker installation:

1. **[Grafana Monitoring Setup](grafana-setup-guide.md)** - Secure and configure monitoring
   dashboards (required for proper monitoring)
2. **SSL Certificate Generation** - For production deployments with custom domains
3. **Domain Configuration** - DNS setup for production deployments

### Accessing Services

After deployment, these services are available:

- **Tracker HTTP**: `http://<server-ip>:7070/announce`
- **Tracker UDP**: `udp://<server-ip>:6969/announce`
- **Tracker API**: `http://<server-ip>:1212/api/health_check`
- **Nginx Proxy**: `http://<server-ip>/` (routes to tracker)
- **Grafana**: `http://<server-ip>:3100/` (admin/admin)

### Service Management

```bash
# SSH to server
ssh torrust@<server-ip>

# Navigate to application directory
cd /home/torrust/github/torrust/torrust-tracker-demo/application

# Check service status
docker compose ps

# View logs
docker compose logs tracker
docker compose logs mysql
docker compose logs nginx

# Restart services
docker compose restart
```

### Database Access

```bash
# Access MySQL database
docker compose exec mysql mysql -u torrust -p torrust_tracker

# View tracker data
SHOW TABLES;
SELECT * FROM torrents LIMIT 10;
```

### Backup Management

```bash
# Backups are created automatically at /var/lib/torrust/mysql/backups/
ls -la /var/lib/torrust/mysql/backups/

# Manual backup
./share/bin/mysql-backup.sh

# Restore from backup (example)
gunzip -c /var/lib/torrust/mysql/backups/torrust_tracker_backup_20250729_030001.sql.gz | \
docker compose exec -T mysql mysql -u root -p torrust_tracker
```

## Environment Configuration

### Local Development

For local testing and development:

```bash
# Use local environment
make infra-apply ENVIRONMENT=local
make app-deploy ENVIRONMENT=local

# Features enabled:
# - HTTP only (no SSL certificates)
# - Local domain names (tracker.local)
# - Basic monitoring
# - MySQL database (same as production)
```

### Production Environment Setup

Before deploying to production, you must configure secure secrets and environment variables.

#### Step 1: Generate Secure Secrets

Production deployment requires several secure random secrets. Use the built-in secret generator:

```bash
# Generate secure secrets using the built-in helper
./infrastructure/scripts/configure-env.sh generate-secrets
```

**Example output**:

```bash
=== TORRUST TRACKER PRODUCTION SECRETS ===

Copy these values into: infrastructure/config/environments/production.env

# === GENERATED SECRETS ===
MYSQL_ROOT_PASSWORD=jcrmbzlGyeP7z53TUQtXmtltMb5TubsIE9e0DPLnS4Ih29JddQw5JA==
MYSQL_PASSWORD=kLp9nReY4vXqA7mZ8wB3QcG6FsE1oNtH5jUiD2fK0zRyS9CxT8V1Mq==
TRACKER_ADMIN_TOKEN=nP6rL2gKbY8xW5zA9mQ4jE3vC7sR1tH0oB9fN6dK5uI8eT2yV1nX4q==
GF_SECURITY_ADMIN_PASSWORD=wQ9tR4nM7bX2zA8kY6pL5sG1oE3vN0cF9eT8jU4dK7hB6rW5iQ2nM==

# === DOMAIN CONFIGURATION (REPLACE WITH YOUR VALUES) ===
DOMAIN_NAME=your-domain.com
CERTBOT_EMAIL=admin@your-domain.com
```

#### Step 2: Configure Production Environment

**Note**: The project now uses a unified configuration template approach following twelve-factor
principles. This eliminates synchronization issues between multiple template files.

Generate the production configuration template:

```bash
# Generate production configuration template with placeholders
make infra-config-production
```

This will create `infrastructure/config/environments/production.env` with secure placeholder
values that need to be replaced with your actual configuration.

#### Step 3: Replace Placeholder Values

Edit the generated production environment file with your secure secrets and domain configuration:

```bash
# Edit the production configuration
vim infrastructure/config/environments/production.env
```

**Replace these placeholder values with your actual configuration**:

```bash
# === SECURE SECRETS ===
# Replace with secrets generated above
MYSQL_ROOT_PASSWORD=jcrmbzlGyeP7z53TUQtXmtltMb5TubsIE9e0DPLnS4Ih29JddQw5JA==
MYSQL_PASSWORD=kLp9nReY4vXqA7mZ8wB3QcG6FsE1oNtH5jUiD2fK0zRyS9CxT8V1Mq==
TRACKER_ADMIN_TOKEN=nP6rL2gKbY8xW5zA9mQ4jE3vC7sR1tH0oB9fN6dK5uI8eT2yV1nX4q==
GF_SECURITY_ADMIN_PASSWORD=wQ9tR4nM7bX2zA8kY6pL5sG1oE3vN0cF9eT8jU4dK7hB6rW5iQ2nM==

# === DOMAIN CONFIGURATION ===
DOMAIN_NAME=your-domain.com                    # Your actual domain
CERTBOT_EMAIL=admin@your-domain.com            # Your email for Let's Encrypt

# === BACKUP CONFIGURATION ===
ENABLE_DB_BACKUPS=true
BACKUP_RETENTION_DAYS=7
```

**⚠️ Security Note**: The `production.env` file contains sensitive secrets and is git-ignored.
Never commit this file to version control.

#### Step 4: Validate Configuration

Validate your production configuration before deployment:

```bash
# Validate configuration (will work only after secrets are configured)
make infra-config-production

# Expected output:
# ✅ Production environment: VALID
# ✅ Domain configuration: your-domain.com
# ✅ SSL configuration: READY
# ✅ Database secrets: CONFIGURED
# ✅ All required variables: SET
```

### Production Deployment (Planned)

**Note**: Production deployment is not yet implemented. The following shows the
planned interface for future production deployments:

```bash
# Planned: Use production environment
make infra-apply ENVIRONMENT=production DOMAIN=your-domain.com
make app-deploy ENVIRONMENT=production

# Planned features:
# - HTTPS support (with automated certificate setup)
# - MySQL database with automated backups
# - Full monitoring with Grafana dashboards
# - Production security hardening
# - Automated maintenance tasks
```

## Monitoring and Maintenance

### Grafana Dashboards (Required Setup)

**⚠️ Important**: Grafana setup is required to complete your tracker installation.

Grafana provides powerful monitoring dashboards for your Torrust Tracker deployment.
After deployment, Grafana requires manual setup to secure the installation and
configure data sources.

**Setup Required**: Follow the [Grafana Setup Guide](grafana-setup-guide.md) for
detailed instructions on:

- Securing the default admin account
- Configuring Prometheus data source
- Importing pre-built dashboards
- Creating custom monitoring panels

**Quick Setup Summary**:

1. Access Grafana at `http://<server-ip>:3100/`
2. Login with `admin/admin` (change password immediately)
3. Add Prometheus data source: `http://prometheus:9090`
4. Import dashboards from `application/share/grafana/dashboards/`

### Log Monitoring

```bash
# Application logs
docker compose logs -f tracker

# System logs
sudo journalctl -u docker -f

# Maintenance logs
tail -f /var/log/mysql-backup.log
tail -f /var/log/ssl-renewal.log
```

### Performance Monitoring

```bash
# Resource usage
htop
df -h
docker stats

# Network connectivity
netstat -tulpn | grep -E ':(80|443|6969|7070|1212|3100)'
```

## Troubleshooting

### Common Issues

#### 1. VM Creation Fails (Local Development)

```bash
# Check libvirt status and configuration
make infra-test-prereq

# Check OpenTofu configuration
make infra-plan

# Check detailed logs
journalctl -u libvirtd
```

#### 2. Application Services Won't Start

```bash
# SSH to server and check logs
ssh torrust@<server-ip>
cd /home/torrust/github/torrust/torrust-tracker-demo/application
docker compose ps
docker compose logs
```

#### 3. Domain/DNS Issues

```bash
# Test DNS resolution
nslookup tracker.your-domain.com
dig tracker.your-domain.com

# Test connectivity
curl -I http://tracker.your-domain.com
```

#### 4. SSL Certificate Issues

```bash
# Check certificate status
openssl x509 -in /path/to/cert.pem -text -noout

# Test SSL configuration
curl -I https://tracker.your-domain.com

# Check Let's Encrypt logs
docker compose logs certbot
```

### Recovery Procedures

#### Service Recovery

```bash
# Restart all services
docker compose down
docker compose up -d

# Reset database (WARNING: destroys data)
docker compose down -v
docker compose up -d
```

#### SSL Recovery

```bash
# Remove existing certificates and regenerate
sudo rm -rf /path/to/certbot/data
./share/bin/ssl_generate.sh your-domain.com admin@your-domain.com
```

#### Backup Recovery

```bash
# List available backups
ls -la /var/lib/torrust/mysql/backups/

# Restore from specific backup
gunzip -c /path/to/backup.sql.gz | docker compose exec -T mysql mysql -u root -p torrust_tracker
```

## Security Considerations

### Default Security Features

- **UFW Firewall**: Only required ports are open
- **Fail2ban**: SSH brute force protection
- **Automatic Updates**: Security patches applied automatically
- **SSH Key Authentication**: Password authentication disabled
- **Container Isolation**: Services run in isolated containers

### Additional Hardening

For production deployments, consider:

1. **SSL Certificates**: Use the manual SSL setup for HTTPS
2. **Database Security**: Change default MySQL passwords
3. **Access Control**: Restrict SSH access to specific IPs
4. **Monitoring**: Set up log aggregation and alerting
5. **Backups**: Implement off-site backup storage

## Advanced Configuration

### Custom Environment Variables

Edit the environment templates in `infrastructure/config/templates/` to customize:

- Database passwords and configuration
- Tracker ports and settings
- Monitoring configuration
- SSL certificate settings

### Multi-Instance Deployment

For high-availability setups:

1. Deploy multiple VMs with load balancer
2. Use external MySQL database service
3. Implement shared storage for certificates
4. Configure monitoring across all instances

### Provider-Specific Configurations

#### Hetzner Cloud (Planned)

**Note**: Hetzner Cloud support is not yet implemented. The following shows the
planned interface for future implementation:

```bash
# Planned: Use Hetzner-specific configurations
export HCLOUD_TOKEN="your-hetzner-token"
make infra-apply ENVIRONMENT=production PROVIDER=hetzner
```

**Status**: This functionality will be implemented in Phase 4 of the migration plan.

## Support and Contributing

### Getting Help

- **Issues**: [GitHub Issues](https://github.com/torrust/torrust-tracker-demo/issues)
- **Documentation**: [Project Documentation](https://github.com/torrust/torrust-tracker-demo/docs)
- **Community**: [Torrust Community](https://torrust.com/community)

### Contributing

1. Fork the repository
2. Test changes locally with `make test-e2e`
3. Submit pull requests with documentation updates
4. Follow the [Contributor Guide](../.github/copilot-instructions.md)

## Conclusion

This guide provides a complete workflow for deploying Torrust Tracker in local
development environments, with cloud deployment planned for future implementation.
Currently, the automation handles the majority of setup tasks for local KVM/libvirt
deployment. For production cloud deployments (planned), only domain-specific SSL
configuration will require manual steps.

For questions or issues, please refer to the project documentation or open an issue
on GitHub.
