# Migration Guide: From Current State to Twelve-Factor

## Overview

This guide provides step-by-step instructions for migrating from the current
setup to the twelve-factor compliant architecture while maintaining backward
compatibility and minimizing disruption.

## Current vs Target Comparison

### Current Setup

```bash
# Current workflow
make apply                    # Does everything: infrastructure + app
./infrastructure/tests/test-integration.sh setup  # Manual app setup
```

### Target Setup

```bash
# New twelve-factor workflow
make infra-apply ENVIRONMENT=local    # Infrastructure only
make app-deploy ENVIRONMENT=local     # Application only
make health-check ENVIRONMENT=local   # Validation
```

## Migration Strategy

### Step 1: Create New Structure (Week 1)

#### 1.1 Create Configuration Structure

```bash
# Create directory structure
mkdir -p infrastructure/config/environments
mkdir -p infrastructure/config/templates
mkdir -p application/config/templates

# Create environment files
cat > infrastructure/config/environments/local.env << 'EOF'
# Infrastructure Configuration
INFRASTRUCTURE_PROVIDER=local
INFRASTRUCTURE_VM_NAME=torrust-tracker-demo
INFRASTRUCTURE_VM_MEMORY=2048
INFRASTRUCTURE_VM_CPUS=2

# Application Configuration
TORRUST_TRACKER_MODE=public
TORRUST_TRACKER_LOG_LEVEL=debug
TORRUST_TRACKER_DATABASE_DRIVER=sqlite3
TORRUST_TRACKER_API_TOKEN=MyAccessToken

# Service Configuration
GRAFANA_ADMIN_PASSWORD=admin
PROMETHEUS_RETENTION_TIME=7d

# Network Configuration
TORRUST_TRACKER_UDP_PORT_6868=6868
TORRUST_TRACKER_UDP_PORT_6969=6969
TORRUST_TRACKER_HTTP_PORT=7070
TORRUST_TRACKER_API_PORT=1212
EOF
```

#### 1.2 Extract Configuration from Cloud-Init

Current `user-data.yaml.tpl` has hardcoded application configuration.
We need to separate this into:

1. **Base system configuration** (stays in cloud-init)
2. **Application configuration** (moves to environment variables)

**New base cloud-init template** (`base-system.yaml.tpl`):

```yaml
#cloud-config
hostname: ${hostname}
locale: en_US.UTF-8
timezone: UTC

users:
  - name: torrust
    groups: [adm, sudo, docker]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
    ssh_authorized_keys:
      - ${ssh_public_key}

packages:
  - curl
  - git
  - docker.io
  - htop
  - vim
  - ufw

runcmd:
  # System setup only - NO application deployment
  - systemctl enable docker
  - systemctl start docker
  - usermod -aG docker torrust

  # Basic firewall setup
  - ufw --force reset
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow ssh
  - ufw allow 80/tcp
  - ufw allow 443/tcp
  - ufw allow 6868/udp
  - ufw allow 6969/udp
  - ufw allow 7070/tcp
  - ufw allow 1212/tcp
  - ufw --force enable

final_message: |
  Base system ready for application deployment.
  VM is ready for Torrust Tracker deployment!
```

#### 1.3 Create Configuration Templates

**Tracker configuration template** (`infrastructure/config/templates/tracker.toml.tpl`):

```toml
[logging]
threshold = "${TORRUST_TRACKER_LOG_LEVEL}"

[core]
inactive_peer_cleanup_interval = 600
listed = false
private = ${TORRUST_TRACKER_PRIVATE:-false}
tracker_usage_statistics = true

[core.announce_policy]
interval = ${TORRUST_TRACKER_ANNOUNCE_INTERVAL:-120}
interval_min = ${TORRUST_TRACKER_ANNOUNCE_INTERVAL_MIN:-120}

[core.database]
driver = "${TORRUST_TRACKER_DATABASE_DRIVER}"
path = "${TORRUST_TRACKER_DATABASE_PATH:-./storage/tracker/lib/database/sqlite3.db}"

[core.net]
external_ip = "0.0.0.0"
on_reverse_proxy = false

[health_check_api]
bind_address = "0.0.0.0:${TORRUST_TRACKER_API_PORT}"

[http_api]
bind_address = "0.0.0.0:${TORRUST_TRACKER_API_PORT}"

[http_api.access_tokens]
admin = "${TORRUST_TRACKER_API_TOKEN}"

[[udp_trackers]]
bind_address = "0.0.0.0:${TORRUST_TRACKER_UDP_PORT_6868}"

[[udp_trackers]]
bind_address = "0.0.0.0:${TORRUST_TRACKER_UDP_PORT_6969}"

[[http_trackers]]
bind_address = "0.0.0.0:${TORRUST_TRACKER_HTTP_PORT}"
```

### Step 2: Adapt Current Scripts (Week 1-2)

#### 2.1 Modify test-integration.sh

Instead of completely replacing `test-integration.sh`, we'll adapt it to use
the new configuration system while maintaining backward compatibility.

**Enhanced setup_torrust_tracker function:**

```bash
# Enhanced setup function in test-integration.sh
setup_torrust_tracker() {
    log_info "Setting up Torrust Tracker Demo..."

    local vm_ip
    vm_ip=$(get_vm_ip)

    # Check if new configuration system is available
    if [ -f "${PROJECT_ROOT}/infrastructure/scripts/deploy-app.sh" ]; then
        log_info "Using new twelve-factor deployment system"

        # Use new deployment script
        "${PROJECT_ROOT}/infrastructure/scripts/deploy-app.sh" local "${vm_ip}"

    else
        log_info "Using legacy deployment system"

        # Original deployment logic (preserved for backward compatibility)
        setup_legacy_deployment "${vm_ip}"
    fi

    log_success "Torrust Tracker Demo setup completed"
    return 0
}

# Legacy deployment function (preserved)
setup_legacy_deployment() {
    local vm_ip="$1"

    # Check if already cloned
    if vm_exec "${vm_ip}" "test -d /home/torrust/github/torrust/torrust-tracker-demo" \
        "Checking if repo exists"; then
        log_info "Repository already exists, updating..."
        vm_exec "${vm_ip}" \
            "cd /home/torrust/github/torrust/torrust-tracker-demo && git pull" \
            "Updating repository"
    else
        log_info "Cloning repository..."
        vm_exec "${vm_ip}" "mkdir -p /home/torrust/github/torrust" \
            "Creating directory structure"
        vm_exec "${vm_ip}" \
            "cd /home/torrust/github/torrust && git clone \
https://github.com/torrust/torrust-tracker-demo.git" \
            "Cloning repository"
    fi

    # Setup environment file
    vm_exec "${vm_ip}" \
        "cd /home/torrust/github/torrust/torrust-tracker-demo && cp .env.production .env" \
        "Setting up environment file"
}
```

#### 2.2 Update Makefile

Add new targets while keeping existing ones:

```makefile
# New twelve-factor targets
infra-apply: ## Deploy infrastructure only
    @echo "Deploying infrastructure for environment: $(ENVIRONMENT)"
    @if [ -z "$(ENVIRONMENT)" ]; then \
        echo "ERROR: ENVIRONMENT not specified. Use: make infra-apply ENVIRONMENT=local"; \
        exit 1; \
    fi
    ./infrastructure/scripts/provision-infrastructure.sh $(ENVIRONMENT) apply

app-deploy: ## Deploy application only
    @echo "Deploying application for environment: $(ENVIRONMENT)"
    @if [ -z "$(ENVIRONMENT)" ]; then \
        echo "ERROR: ENVIRONMENT not specified. Use: make app-deploy ENVIRONMENT=local"; \
        exit 1; \
    fi
    ./infrastructure/scripts/deploy-app.sh $(ENVIRONMENT)

health-check: ## Check deployment health
    @echo "Checking deployment health for environment: $(ENVIRONMENT)"
    @if [ -z "$(ENVIRONMENT)" ]; then \
        echo "ERROR: ENVIRONMENT not specified. Use: make health-check ENVIRONMENT=local"; \
        exit 1; \
    fi
    ./infrastructure/scripts/health-check.sh $(ENVIRONMENT)

# Enhanced existing targets
apply: ## Deploy VM with application (legacy method, maintained for compatibility)
    @echo "Deploying VM with full application stack..."
    @echo "NOTE: Consider using 'make infra-apply ENVIRONMENT=local && \
make app-deploy ENVIRONMENT=local' for better separation"
    cd $(TERRAFORM_DIR) && tofu apply -var-file="local.tfvars"
    @echo "Deployment completed. Testing application deployment..."
    $(TESTS_DIR)/test-integration.sh setup

# Configuration management
configure-env: ## Process environment configuration
    @echo "Processing configuration for environment: $(ENVIRONMENT)"
    @if [ -z "$(ENVIRONMENT)" ]; then \
        echo "ERROR: ENVIRONMENT not specified. Use: make configure-env ENVIRONMENT=local"; \
        exit 1; \
    fi
    ./infrastructure/scripts/configure-env.sh $(ENVIRONMENT)

validate-config: ## Validate configuration files
    @echo "Validating configuration files..."
    ./infrastructure/scripts/validate-config.sh
```

> **Note**: In actual Makefile implementation, replace the 4-space indentation
> with tabs as required by Make syntax.

### Step 3: Gradual Migration (Week 2-3)

#### 3.1 Update Documentation

**Enhanced README.md section:**

````markdown
## Deployment Options

### Option 1: Twelve-Factor Deployment (Recommended)

```bash
# 1. Deploy infrastructure
make infra-apply ENVIRONMENT=local

# 2. Deploy application
make app-deploy ENVIRONMENT=local

# 3. Validate deployment
make health-check ENVIRONMENT=local
```
````

### Option 2: Legacy Single-Command Deployment

```bash
# Deploy everything at once (legacy method)
make apply
```

### Configuration Management

The new system uses environment-specific configuration:

- `infrastructure/config/environments/local.env` - Local development
- `infrastructure/config/environments/staging.env` - Staging environment
- `infrastructure/config/environments/production.env` - Production environment

Process configuration before deployment:

```bash
make configure-env ENVIRONMENT=local
make validate-config
```

#### 3.2 Migration Testing

**Test both deployment methods work:**

```bash
# Test new method
make infra-apply ENVIRONMENT=local
make app-deploy ENVIRONMENT=local
make health-check ENVIRONMENT=local
make destroy

# Test legacy method still works
make apply
make destroy
```

### Step 4: Environment-Specific Configurations (Week 3-4)

#### 4.1 Create Environment Variations

**Staging configuration** (`infrastructure/config/environments/staging.env`):

```bash
# Infrastructure Configuration
INFRASTRUCTURE_PROVIDER=hetzner
INFRASTRUCTURE_REGION=fsn1
INFRASTRUCTURE_INSTANCE_TYPE=cx11

# Application Configuration
TORRUST_TRACKER_MODE=private
TORRUST_TRACKER_LOG_LEVEL=info
TORRUST_TRACKER_DATABASE_DRIVER=sqlite3
TORRUST_TRACKER_API_TOKEN=${TORRUST_STAGING_API_TOKEN}

# Service Configuration
GRAFANA_ADMIN_PASSWORD=${GRAFANA_STAGING_PASSWORD}
PROMETHEUS_RETENTION_TIME=15d

# Security Configuration
SSH_PUBLIC_KEY=${SSH_PUBLIC_KEY}
DOMAIN_NAME=staging.torrust-demo.com
SSL_EMAIL=${SSL_EMAIL}
```

**Production configuration** (`infrastructure/config/environments/production.env`):

```bash
# Infrastructure Configuration
INFRASTRUCTURE_PROVIDER=hetzner
INFRASTRUCTURE_REGION=fsn1
INFRASTRUCTURE_INSTANCE_TYPE=cx21

# Application Configuration
TORRUST_TRACKER_MODE=private
TORRUST_TRACKER_LOG_LEVEL=info
TORRUST_TRACKER_DATABASE_DRIVER=mysql
TORRUST_TRACKER_DATABASE_URL=${TORRUST_PROD_DATABASE_URL}
TORRUST_TRACKER_API_TOKEN=${TORRUST_PROD_API_TOKEN}

# Service Configuration
GRAFANA_ADMIN_PASSWORD=${GRAFANA_PROD_PASSWORD}
PROMETHEUS_RETENTION_TIME=30d

# Security Configuration
SSH_PUBLIC_KEY=${SSH_PUBLIC_KEY}
DOMAIN_NAME=torrust-demo.com
SSL_EMAIL=${SSL_EMAIL}
```

#### 4.2 Provider-Specific Configurations

Create provider-specific Terraform configurations:

```text
infrastructure/
├── terraform/
│   ├── providers/
│   │   ├── local/
│   │   │   ├── main.tf
│   │   │   └── variables.tf
│   │   ├── hetzner/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── hetzner.tf
│   │   └── aws/                    # Future
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── aws.tf
│   └── modules/                    # Shared modules
│       ├── base-vm/
│       ├── networking/
│       └── security/
```

### Step 5: Production Readiness (Week 4-5)

#### 5.1 Hetzner Cloud Integration

**Hetzner provider configuration** (`infrastructure/terraform/providers/hetzner/main.tf`):

```hcl
terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

# Use shared base-vm module
module "tracker_vm" {
  source = "../../modules/base-vm"

  # Provider-specific values
  provider_type    = "hetzner"
  instance_type    = var.instance_type
  region          = var.region

  # Common values
  vm_name         = var.vm_name
  ssh_public_key  = var.ssh_public_key
  environment     = var.environment
}
```

#### 5.2 Environment Variable Management

For production, use secure environment variable management:

```bash
# Example using direnv for local development
cat > .envrc << 'EOF'
# Load environment-specific configuration
export ENVIRONMENT=local
source infrastructure/config/environments/${ENVIRONMENT}.env

# Sensitive variables (not committed to git)
export SSH_PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)"
export TORRUST_PROD_API_TOKEN="your-production-token"
export GRAFANA_PROD_PASSWORD="your-production-password"
EOF

# Allow direnv
direnv allow
```

## Migration Checklist

### Week 1: Foundation

- [ ] Create new directory structure
- [ ] Create environment configuration files
- [ ] Create configuration templates
- [ ] Implement configuration processing scripts
- [ ] Test configuration processing locally

### Week 2: Integration

- [ ] Modify existing scripts for backward compatibility
- [ ] Update Makefile with new targets
- [ ] Update documentation
- [ ] Test both old and new deployment methods

### Week 3: Environment Support

- [ ] Create staging and production configurations
- [ ] Implement environment-specific logic
- [ ] Test multi-environment deployment
- [ ] Validate configuration for all environments

### Week 4: Provider Abstraction

- [ ] Create provider-specific Terraform modules
- [ ] Implement Hetzner cloud support
- [ ] Test cloud provider deployment
- [ ] Document cloud-specific requirements

### Week 5: Production Readiness

- [ ] Implement secure secret management
- [ ] Create production deployment procedures
- [ ] Implement monitoring and health checks
- [ ] Create disaster recovery procedures

## Rollback Plan

If issues arise during migration, you can always rollback to the previous system:

```bash
# Rollback to legacy deployment
git checkout HEAD~1  # Or specific commit before migration
make apply           # Use old deployment method
```

The migration maintains backward compatibility, so the old `make apply` command
will continue to work throughout the transition period.

## Benefits After Migration

1. **Environment Parity**: Same deployment process for all environments
2. **Configuration Management**: All configuration via environment variables
3. **Deployment Speed**: Faster application updates (no infrastructure changes)
4. **Cloud Flexibility**: Easy to add new cloud providers
5. **Testing**: Better isolation between infrastructure and application testing
6. **Monitoring**: Clearer deployment validation and health checking

## Next Steps

Once this migration is complete:

1. Add support for additional cloud providers (AWS, GCP)
2. Implement rolling deployments
3. Add automated backup and disaster recovery
4. Implement configuration drift detection
5. Add performance monitoring and alerting
