# Issue #21: Complete Application Installation Automation

## Overview

This document outlines the implementation plan for Phase 3 of the Hetzner migration:
**Maximum Practical Application Installation Automation**. This phase aims to minimize manual
setup steps by automating most of the application deployment process, while providing clear
guidance for the few manual steps that cannot be fully automated due to external dependencies
(DNS configuration, domain-specific setup).

**Goal**: Achieve **90%+ automation** with remaining manual steps being simple, fast, and
well-guided.

## Table of Contents

- [Overview](#overview)
- [Table of Contents](#table-of-contents)
- [Implementation Status](#implementation-status)
- [Current State Analysis](#current-state-analysis)
  - [What's Already Automated](#whats-already-automated)
  - [What Requires Manual Steps (Current Gaps)](#what-requires-manual-steps-current-gaps)
    - [Steps That Can Be Automated (Extensions Needed)](#steps-that-can-be-automated-extensions-needed)
    - [Steps That Require Manual Intervention (Cannot Be Fully Automated)](#steps-that-require-manual-intervention-cannot-be-fully-automated)
- [Current Architecture Foundation](#current-architecture-foundation)
  - [Existing Automation Workflow](#existing-automation-workflow)
  - [Extension Points for SSL/Backup Automation](#extension-points-for-sslbackup-automation)
- [Implementation Roadmap](#implementation-roadmap)
  - [Phase 1: Environment Template Extensions (Priority: HIGH)](#phase-1-environment-template-extensions-priority-high)
  - [Phase 2: SSL Certificate Automation (Priority: HIGH)](#phase-2-ssl-certificate-automation-priority-high)
  - [Phase 3: Database Backup Automation (Priority: MEDIUM)](#phase-3-database-backup-automation-priority-medium)
  - [Phase 4: Documentation and Integration (Priority: MEDIUM)](#phase-4-documentation-and-integration-priority-medium)
- [Implementation Plan](#implementation-plan)
  - [Core Automation Strategy](#core-automation-strategy)
  - [Task 1: Extend Environment Configuration](#task-1-extend-environment-configuration)
    - [1.1 Environment Variables Status](#11-environment-variables-status)
    - [1.2 Update configure-env.sh (NOT YET IMPLEMENTED)](#12-update-configure-envsh-not-yet-implemented)
  - [Task 2: Extend deploy-app.sh with SSL Automation](#task-2-extend-deploy-appsh-with-ssl-automation)
    - [2.1 Create SSL Certificate Generation Script](#21-create-ssl-certificate-generation-script)
    - [1.3 SSL Certificate Setup Workflow](#13-ssl-certificate-setup-workflow)
    - [1.3.1 Local Testing Workflow with Pebble](#131-local-testing-workflow-with-pebble)
    - [1.4 Current Nginx Template State](#14-current-nginx-template-state)
    - [1.5 Automate Certificate Renewal Setup](#15-automate-certificate-renewal-setup)
  - [Task 2: MySQL Database Backup Automation](#task-2-mysql-database-backup-automation)
    - [2.1 Create MySQL Backup Script (MISSING FILE)](#21-create-mysql-backup-script-missing-file)
    - [2.2 Crontab Template Status](#22-crontab-template-status)
  - [Task 3: Integration and Documentation](#task-3-integration-and-documentation)
    - [3.1 Cloud-Init Integration for Crontab Setup](#31-cloud-init-integration-for-crontab-setup)
    - [3.2 Create Production Deployment Validation Script](#32-create-production-deployment-validation-script)
- [Technical Implementation Details](#technical-implementation-details)
  - [Implementation Approach](#implementation-approach)
  - [Integration Points](#integration-points)
    - [1. Environment Template Updates](#1-environment-template-updates)
    - [2. Deploy-App.sh Extensions](#2-deploy-appsh-extensions)
    - [3. New Supporting Scripts](#3-new-supporting-scripts)
  - [Integration with Existing Scripts](#integration-with-existing-scripts)
- [Success Criteria](#success-criteria)
  - [Functional Requirements](#functional-requirements)
  - [Non-Functional Requirements](#non-functional-requirements)
- [Risk Assessment and Mitigation](#risk-assessment-and-mitigation)
  - [High-Risk Areas](#high-risk-areas)
  - [Medium-Risk Areas](#medium-risk-areas)
- [Testing Strategy](#testing-strategy)
  - [Unit Testing](#unit-testing)
  - [Integration Testing](#integration-testing)
  - [SSL Workflow Testing](#ssl-workflow-testing)
  - [End-to-End Testing](#end-to-end-testing)
  - [Smoke Testing](#smoke-testing)
- [Success Criteria](#success-criteria-1)
  - [Primary Goals](#primary-goals)
  - [Secondary Goals](#secondary-goals)
- [Timeline and Dependencies](#timeline-and-dependencies)
  - [Task 1: SSL Certificate Automation (Week 1)](#task-1-ssl-certificate-automation-week-1)
  - [Task 2: MySQL Backup Automation (Week 1-2)](#task-2-mysql-backup-automation-week-1-2)
  - [Task 3: Integration and Documentation (Week 2)](#task-3-integration-and-documentation-week-2)
- [Acceptance Criteria](#acceptance-criteria)
  - [Primary Goals](#primary-goals-1)
  - [Secondary Goals](#secondary-goals-1)
- [Related Issues and Dependencies](#related-issues-and-dependencies)
- [Documentation Updates Required](#documentation-updates-required)
- [Conclusion](#conclusion)

## Implementation Status

**Last Updated**: 2025-07-29

| Component                     | Status             | Description                                        | Notes                                             |
| ----------------------------- | ------------------ | -------------------------------------------------- | ------------------------------------------------- |
| **Infrastructure Foundation** | ✅ **Complete**    | VM provisioning, cloud-init, basic system setup    | Fully automated via provision-infrastructure.sh   |
| **Application Foundation**    | ✅ **Complete**    | Docker deployment, basic app orchestration         | Fully automated via deploy-app.sh                 |
| **Environment Templates**     | ✅ **Complete**    | SSL/domain/backup variables added to templates     | Templates updated with all required variables     |
| **Secret Generation Helper**  | ✅ **Complete**    | Helper script for generating secure secrets        | generate-secrets.sh implemented                   |
| **Basic Nginx Templates**     | ✅ **Complete**    | HTTP nginx configuration template exists           | nginx.conf.tpl with HTTP + commented HTTPS        |
| **configure-env.sh Updates**  | ✅ **Complete**    | SSL/backup variable validation implemented          | Comprehensive validation with email/boolean checks |
| **SSL Certificate Scripts**   | ❌ **Not Started** | Create SSL generation and configuration scripts    | Core SSL automation needed                        |
| **HTTPS Nginx Templates**     | 🔄 **Partial**     | HTTPS configuration exists but commented out       | Current template has HTTPS but needs activation   |
| **MySQL Backup Scripts**      | ❌ **Not Started** | Create MySQL backup automation scripts             | Referenced by cron template but doesn't exist     |
| **deploy-app.sh Extensions**  | ❌ **Not Started** | SSL/backup automation not yet integrated           | Foundation exists, needs SSL/backup stages        |
| **Crontab Templates**         | 🔄 **Partial**     | Templates exist but reference non-existent scripts | Templates created, scripts and integration needed |
| **Documentation Updates**     | 🔄 **Partial**     | ADR-004 updated for deployment automation config   | Deployment guides need updates post-implementation |

**Current Progress**: 50% complete (6/12 components fully implemented)

**Next Steps** (Phase 1 - Priority: HIGH):

1. ✅ **Environment Templates** - SSL/domain/backup variables added to templates (COMPLETED)
2. ✅ **Secret Generation Helper** - Helper script for secure secret generation (COMPLETED)
3. ✅ **Update configure-env.sh** - Add validation for new SSL and backup configuration variables
   (COMPLETED 2025-07-29)
4. 🎯 **Create SSL Scripts** - Implement certificate generation and nginx configuration

**Immediate Action Items**:

- ✅ ~~Extend `validate_environment()` function in `configure-env.sh` to validate SSL variables~~ **COMPLETED**
  - Comprehensive validation implemented with email format, boolean, and placeholder detection
  - Updated ADR-004 to document deployment automation configuration exception
  - All e2e tests pass with new validation
- Create `application/share/bin/mysql-backup.sh` script (referenced by cron template but
  doesn't exist yet) - **Missing file**
- Fix nginx template HTTPS configuration (currently commented out in nginx.conf.tpl)
- Begin Phase 2: SSL certificate automation script development

## Critical Review Findings (2025-07-29)

**Document Review Summary**: This document has been updated to accurately reflect the current
repository state. Key inconsistencies identified and corrected:

### ✅ **Corrected Status Information**

1. **Basic Nginx Templates**: Status corrected from "Not Started" to "Complete" -  
   `nginx.conf.tpl` exists with working HTTP configuration
2. **HTTPS Configuration**: Status updated to "Partial" - HTTPS config exists but is  
   commented out in the template
3. **Environment Templates**: Confirmed as complete - SSL/backup variables already exist  
   in both templates
4. **Secret Generation**: Confirmed as complete - `generate-secrets.sh` script exists  
   and functional
5. **configure-env.sh Updates**: Status updated to "Complete" (2025-07-29) -  
   Comprehensive SSL/backup validation implemented with ADR-004 updates

### ❌ **Critical Missing Files Identified**

1. **`application/share/bin/mysql-backup.sh`**: Referenced by cron template but doesn't exist
2. **`application/share/bin/crontab_utils.sh`**: Mentioned in implementation plan but not created
3. **SSL certificate generation scripts**: Detailed in plan but not yet implemented

### 🔄 **Status Clarifications**

1. **configure-env.sh SSL validation**: Completed (2025-07-29) with comprehensive validation features
2. **Crontab templates**: Confirmed as existing but referencing missing scripts
3. **nginx template approach**: Updated to reflect current single-template approach vs.  
   proposed two-template approach

### 📊 **Accuracy Improvements**

- Progress updated from 40% to 50% (6/12 components vs. 5/12)
- Last updated date maintained as 2025-07-29
- Component count updated for configure-env.sh completion
- All file references verified against actual repository state

**Conclusion**: The implementation plan is now accurately synchronized with the current  
repository state, with Phase 1 Task 1.2 (configure-env.sh updates) successfully completed.  
This provides a solid foundation for continuing the SSL certificate automation work.

## Current State Analysis

### What's Already Automated

**Infrastructure Layer** (✅ **Fully Automated**):

1. **Infrastructure Provisioning**: VM creation and basic system setup via cloud-init
2. **System Dependencies**: Docker, git, basic tools installation
3. **User Setup**: `torrust` user creation with sudo privileges
4. **Firewall Configuration**: UFW rules for all required ports
5. **Basic Security**: SSH key setup, fail2ban, automatic updates

**Application Layer** (✅ **Fully Automated**):

1. **Application Deployment**: Docker Compose service orchestration
2. **Environment Configuration**: Template-based environment variable processing
3. **Service Health Checks**: Automated validation of running services
4. **Basic Monitoring**: Prometheus and Grafana container deployment

**Foundation Scripts** (✅ **Working**):

- `provision-infrastructure.sh` - Complete infrastructure provisioning workflow
- `deploy-app.sh` - Complete application deployment workflow with health validation
- `configure-env.sh` - Environment template processing and validation
- `health-check.sh` - Comprehensive service health validation

### What Requires Manual Steps (Current Gaps)

Based on current implementation status, these areas need extension or still require manual intervention:

#### Steps That Can Be Automated (Extensions Needed)

1. **SSL Certificate Automation**: Extend deployment with HTTPS support

   - 🔄 **Extension needed**: Add SSL variable templates to environment files
   - 🔄 **Extension needed**: Create certificate generation scripts
   - 🔄 **Extension needed**: Extend deploy-app.sh with SSL workflow integration
   - ✅ **Foundation exists**: Environment processing and deployment orchestration

2. **Database Backup Automation**: Extend deployment with backup scheduling

   - ❌ **Missing**: MySQL backup script creation and crontab automation
   - ✅ **Foundation exists**: MySQL service deployment and health checks

3. **Nginx HTTPS Configuration**: Extend nginx setup with SSL support
   - 🔄 **Partial implementation**: HTTPS configuration exists in nginx.conf.tpl but is commented out
   - ❌ **Missing**: SSL automation to uncomment and activate HTTPS configuration
   - ✅ **Foundation exists**: Basic nginx deployment via Docker Compose

#### Steps That Require Manual Intervention (Cannot Be Fully Automated)

1. **DNS Configuration**: (one-time, external dependency)

   - ❌ **Cannot automate**: Point domain A records to server IP (requires domain registrar access)
   - ⏱️ **Time required**: ~5 minutes
   - 📋 **Guidance**: Clear DNS setup instructions provided

2. **Environment Configuration**: (one-time, deployment-specific)

   - ❌ **Cannot automate**: Configure `DOMAIN_NAME` and `CERTBOT_EMAIL` (deployment-specific values)
   - ⏱️ **Time required**: ~2 minutes
   - 📋 **Guidance**: Template with clear placeholders and validation

3. **SSL Certificate Generation**: (one-time, depends on DNS)

   - ❌ **Cannot automate**: Initial certificate generation (depends on DNS resolution)
   - ⏱️ **Time required**: ~3-5 minutes
   - 📋 **Guidance**: Guided script with DNS validation and clear error messages

4. **Grafana Dashboard Setup**: (optional, post-deployment)
   - ❌ **Cannot automate**: Custom dashboard configuration (user preference)
   - ⏱️ **Time required**: ~10-15 minutes (optional)
   - 📋 **Guidance**: Pre-configured dashboards and import instructions

**Total Manual Time Required**: ~10-15 minutes for essential setup, +10-15 minutes for optional
Grafana customization.

**Note**: Repository cloning, environment configuration, service deployment, and basic
validation are already automated through the existing cloud-init and deployment scripts.

## Current Architecture Foundation

### Existing Automation Workflow

The project already implements a robust **twelve-factor application deployment** workflow
with clear separation between infrastructure provisioning and application deployment:

**Infrastructure Stage** (`make infra-apply`):

- ✅ **Complete**: VM provisioning via `provision-infrastructure.sh`
- ✅ **Complete**: Cloud-init system setup (Docker, firewall, users, security)
- ✅ **Complete**: Environment template processing via `configure-env.sh`

**Application Stage** (`make app-deploy`):

- ✅ **Complete**: Build + Release + Run stages via `deploy-app.sh`
- ✅ **Complete**: Docker Compose service orchestration
- ✅ **Complete**: Health validation via `health-check.sh`

### Extension Points for SSL/Backup Automation

The planned SSL and backup automation will **extend** (not replace) the existing workflow:

**Environment Templates** (🔄 **Extension**):

```bash
infrastructure/config/environments/
├── local.env.tpl      # Add SSL/backup variables
└── production.env.tpl # Add SSL/backup variables
```

**Application Deployment** (🔄 **Extension**):

```bash
infrastructure/scripts/deploy-app.sh
└── run_stage() function # Add SSL + backup integration
```

**Supporting Scripts** (❌ **New**):

```bash
application/share/bin/
├── ssl_generate.sh    # SSL certificate automation
├── backup_mysql.sh    # Database backup automation
└── setup_crontab.sh   # Automated scheduling
```

This approach ensures:

- ✅ **Backward compatibility**: Existing workflows continue working
- ✅ **Incremental adoption**: SSL/backup features are optional extensions
- ✅ **Testability**: Each extension can be tested independently

## Implementation Roadmap

### Phase 1: Environment Template Extensions (Priority: HIGH)

**Goal**: Add SSL and backup configuration variables to environment templates.

**Components**:

- 🔄 **Environment Templates** - Add SSL/domain/backup variables
- 🔄 **configure-env.sh Updates** - Add validation for new variables

**Dependencies**: None (can start immediately)
**Estimated Time**: 1-2 hours
**Risk**: Low

### Phase 2: SSL Certificate Automation (Priority: HIGH)

**Goal**: Implement automated SSL certificate generation and nginx configuration.

**Components**:

- ❌ **SSL Certificate Scripts** - Create certificate generation automation
- ❌ **Nginx Templates** - Create HTTP and HTTPS configuration templates
- 🔄 **deploy-app.sh Extensions** - Add SSL workflow integration

**Dependencies**: Phase 1 completion
**Estimated Time**: 4-6 hours
**Risk**: Medium (external dependencies on DNS/Let's Encrypt)

### Phase 3: Database Backup Automation (Priority: MEDIUM)

**Goal**: Implement automated MySQL backup system with scheduling.

**Components**:

- ❌ **Database Backup Scripts** - Create MySQL backup automation
- ❌ **Crontab Configuration** - Automate backup scheduling

**Dependencies**: None (can run parallel with Phase 2)
**Estimated Time**: 2-3 hours
**Risk**: Low

### Phase 4: Documentation and Integration (Priority: MEDIUM)

**Goal**: Update all deployment guides and finalize integration testing.

**Components**:

- ❌ **Documentation Updates** - Update all deployment guides
- **Integration Testing** - Comprehensive workflow validation

**Dependencies**: Phases 1-3 completion
**Estimated Time**: 2-3 hours
**Risk**: Low

**Total Estimated Implementation Time**: 9-14 hours
**Critical Path**: Phase 1 → Phase 2 (SSL automation is the most complex component)

## Implementation Plan

### Core Automation Strategy

The implementation focuses on **extending the existing `infrastructure/scripts/deploy-app.sh`**
script to automate the remaining manual steps. This aligns with the current twelve-factor
architecture where `deploy-app.sh` handles the Release + Run stages.

**Key Changes**:

1. **Add SSL automation to `deploy-app.sh`** - Extend the run_stage() function
2. **Add backup automation to `deploy-app.sh`** - Extend the run_stage() function
3. **Add required environment variables** - Extend environment templates
4. **Create supporting scripts** - SSL generation and backup scripts in `application/share/bin/`

### Task 1: Extend Environment Configuration

#### 1.1 Environment Variables Status

The SSL and backup configuration variables have already been added to environment templates:

**File**: `infrastructure/config/environments/production.env.tpl` ✅ **COMPLETED**

Variables already added:

```bash
# === SSL CERTIFICATE CONFIGURATION ===
# Domain name for SSL certificates (required for production)
DOMAIN_NAME=REPLACE_WITH_YOUR_DOMAIN
# Email for Let's Encrypt certificate registration (required for production)
CERTBOT_EMAIL=REPLACE_WITH_YOUR_EMAIL
# Enable SSL certificates (true for production, false for testing)
ENABLE_SSL=true

# === BACKUP CONFIGURATION ===
# Enable daily database backups (true/false)
ENABLE_DB_BACKUPS=true
# Backup retention period in days
BACKUP_RETENTION_DAYS=7
```

**File**: `infrastructure/config/environments/local.env.tpl` ✅ **COMPLETED**

Variables already added:

```bash
# === SSL CERTIFICATE CONFIGURATION ===
# Domain name for SSL certificates (local testing with fake domains)
DOMAIN_NAME=test.local
# Email for certificate registration (test email for local)
CERTBOT_EMAIL=test@test.local
# Enable SSL certificates (true for production, false for testing)
ENABLE_SSL=false

# === BACKUP CONFIGURATION ===
# Enable daily database backups (disabled for local testing)
ENABLE_DB_BACKUPS=false
# Backup retention period in days
BACKUP_RETENTION_DAYS=3
```

#### 1.2 Update configure-env.sh (NOT YET IMPLEMENTED)

The `infrastructure/scripts/configure-env.sh` script currently validates basic variables
but does NOT validate SSL/backup configuration variables yet. This needs to be implemented.

**Current validation** (from actual code):

```bash
# Validate required environment variables
validate_environment() {
    local required_vars=(
        "ENVIRONMENT"
        "MYSQL_ROOT_PASSWORD"
        "MYSQL_PASSWORD"
        "TRACKER_ADMIN_TOKEN"
        "GF_SECURITY_ADMIN_PASSWORD"
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required environment variable not set: ${var}"
            exit 1
        fi
    done

    log_success "Environment validation passed"
}
```

**REQUIRED**: Extend this function to validate SSL variables:

- `DOMAIN_NAME` (should not be placeholder value)
- `CERTBOT_EMAIL` (should not be placeholder value)
- `ENABLE_SSL` (should be true/false)
- `ENABLE_DB_BACKUPS` (should be true/false)
- `BACKUP_RETENTION_DAYS` (should be numeric)

### Task 2: Extend deploy-app.sh with SSL Automation

#### 2.1 Create SSL Certificate Generation Script

Create `application/share/bin/ssl_generate.sh`:

```bash
#!/bin/bash
# SSL certificate generation script for production deployment
# Usage: ./ssl_generate.sh <domain> <email> [--production|--staging]

set -euo pipefail

DOMAIN="${1:-}"
MODE="${2:-}"
EMAIL="admin@${DOMAIN}"
APP_DIR="/home/torrust/github/torrust/torrust-tracker-demo/application"

if [[ -z "$DOMAIN" ]]; then
    echo "Usage: $0 <domain> [--production|--pebble]"
    echo ""
    echo "Examples:"
    echo "  $0 torrust-demo.com                    # Generate staging certificates"
    echo "  $0 torrust-demo.com --production       # Generate production certificates"
    echo "  $0 torrust-demo.com --pebble           # Generate test certificates with Pebble"
    exit 1
fi

cd "$APP_DIR"

# Check Docker Compose configuration based on mode
if [[ "$MODE" == "--pebble" ]]; then
    COMPOSE_FILE="compose.test.yaml"
    if ! docker compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        echo "Error: Pebble test environment is not running."
        echo "Please run 'docker compose -f $COMPOSE_FILE up -d' first."
        exit 1
    fi
else
    COMPOSE_FILE="compose.yaml"
    if ! docker compose ps | grep -q "Up"; then
        echo "Error: Docker Compose services are not running."
        echo "Please run 'docker compose up -d' first."
        exit 1
    fi
fi

# Set up certificate parameters
CERT_ARGS=""
CERTBOT_SERVICE="certbot"

if [[ "$MODE" == "--production" ]]; then
    echo "WARNING: You are about to generate PRODUCTION SSL certificates."
    echo "This will use Let's Encrypt production servers with rate limits."
    echo ""
    echo "Domain: $DOMAIN"
    echo "Email: $EMAIL"
    echo ""
    read -p "Continue with production certificate generation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Production certificate generation cancelled."
        exit 0
    fi
    echo "Generating production certificates..."
elif [[ "$MODE" == "--pebble" ]]; then
    echo "Generating test certificates with Pebble for domain: $DOMAIN"
    CERT_ARGS="--server https://pebble:14000/dir --no-verify-ssl"
    CERTBOT_SERVICE="certbot-test"
    EMAIL="test@${DOMAIN}"
else
    echo "Generating staging certificates for domain: $DOMAIN"
    CERT_ARGS="--test-cert"
fi

# Generate DH parameters if not present (except for Pebble mode)
if [[ "$MODE" != "--pebble" && ! -f "/var/lib/torrust/proxy/dhparam/dhparam.pem" ]]; then
    echo "Generating DH parameters..."
    docker compose exec proxy openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
fi

# Generate certificates for both subdomains
echo "Generating certificate for tracker.$DOMAIN..."
docker compose -f "$COMPOSE_FILE" run --rm "$CERTBOT_SERVICE" certonly \
    --webroot \
    --webroot-path=/var/www/html \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    $CERT_ARGS \
    -d "tracker.$DOMAIN"

echo "Generating certificate for grafana.$DOMAIN..."
docker compose -f "$COMPOSE_FILE" run --rm "$CERTBOT_SERVICE" certonly \
    --webroot \
    --webroot-path=/var/www/html \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    $CERT_ARGS \
    -d "grafana.$DOMAIN"

if [[ "$MODE" == "--production" ]]; then
    echo "✅ Production SSL certificates generated successfully!"
    echo ""
    echo "Certificates location:"
    echo "  - tracker.$DOMAIN: /var/lib/torrust/proxy/certbot/etc/letsencrypt/live/tracker.$DOMAIN/"
    echo "  - grafana.$DOMAIN: /var/lib/torrust/proxy/certbot/etc/letsencrypt/live/grafana.$DOMAIN/"
    echo ""
    echo "Next steps:"
    echo "  1. Configure nginx for HTTPS: ./ssl_configure_nginx.sh $DOMAIN"
    echo "  2. Restart proxy service: docker compose restart proxy"
    echo "  3. Test HTTPS endpoints:"
    echo "     - https://tracker.$DOMAIN"
    echo "     - https://grafana.$DOMAIN"
elif [[ "$MODE" == "--pebble" ]]; then
    echo "✅ Pebble test certificates generated successfully!"
    echo ""
    echo "Certificates location:"
    echo "  - tracker.$DOMAIN: /var/lib/torrust/proxy/certbot/etc/letsencrypt/live/tracker.$DOMAIN/"
    echo "  - grafana.$DOMAIN: /var/lib/torrust/proxy/certbot/etc/letsencrypt/live/grafana.$DOMAIN/"
    echo ""
    echo "Next steps:"
    echo "  1. Configure nginx for HTTPS: ./ssl_configure_nginx.sh $DOMAIN"
    echo "  2. Restart proxy service: docker compose -f $COMPOSE_FILE restart proxy"
    echo "  3. Test HTTPS endpoints (use Pebble CA for verification):"
    echo "     - curl --cacert /tmp/pebble.minica.pem https://tracker.$DOMAIN"
    echo "     - curl --cacert /tmp/pebble.minica.pem https://grafana.$DOMAIN"
    echo ""
    echo "Clean up test environment:"
    echo "  - docker compose -f $COMPOSE_FILE down -v"
else
    echo "✅ Staging SSL certificates generated successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Configure nginx for HTTPS: ./ssl_configure_nginx.sh $DOMAIN"
    echo "  2. Test staging endpoints (expect certificate warnings):"
    echo "     - https://tracker.$DOMAIN"
    echo "     - https://grafana.$DOMAIN"
    echo "  3. If staging works, generate production certificates:"
    echo "     - ./ssl_generate.sh $DOMAIN --production"
fi
```

#### 1.3 SSL Certificate Setup Workflow

The recommended workflow follows the [Torrust production deployment guide](https://torrust.com/blog/deploying-torrust-to-production#install-the-application):

**Prerequisites** (manual steps required):

1. Domain DNS A records point to server IP:
   - `tracker.torrust-demo.com` → `<server-ip>` (Tracker API)
   - `grafana.torrust-demo.com` → `<server-ip>` (Monitoring Dashboard)
2. Server is accessible on port 80 (required for HTTP challenge)
3. Tracker application is deployed with HTTP-only nginx configuration

**Initial Setup** (Template-Based):

```bash
# Step 1: Deploy with HTTP-only nginx configuration
cp ../infrastructure/config/templates/nginx-http.conf.tpl /var/lib/torrust/proxy/etc/nginx-conf/default.conf
sed -i "s/\${DOMAIN_NAME}/torrust-demo.com/g" /var/lib/torrust/proxy/etc/nginx-conf/default.conf
docker compose up -d
```

**Automated Certificate Generation**:

```bash
# Step 2: Test with staging certificates (recommended)
./ssl_generate.sh torrust-demo.com

# Step 3: Configure nginx for HTTPS
./ssl_configure_nginx.sh torrust-demo.com

# Step 4: If staging succeeds, generate production certificates
./ssl_generate.sh torrust-demo.com --production

# Step 5: Restart nginx to load production certificates
docker compose restart proxy
```

**Benefits of this approach**:

- Template-based nginx configuration (clean, maintainable)
- Safe testing with staging certificates (no rate limits)
- Production certificate generation with confirmation prompt
- Follows proven production deployment practices
- Comprehensive error handling and user guidance

#### 1.3.1 Local Testing Workflow with Pebble

For development and testing, use Pebble to validate the complete SSL workflow locally:

**Local Testing Prerequisites**:

- Local development environment with Docker and Docker Compose
- No domain or DNS setup required
- Fast iteration for testing script changes

**Local Testing Steps**:

```bash
# Step 1: Start Pebble test environment
docker compose -f compose.test.yaml up -d pebble pebble-challtestsrv

# Step 2: Set up test nginx configuration
cp ../infrastructure/config/templates/nginx-http.conf.tpl /var/lib/torrust/proxy/etc/nginx-conf/default.conf
sed -i "s/\${DOMAIN_NAME}/test.local/g" /var/lib/torrust/proxy/etc/nginx-conf/default.conf

# Step 3: Start application services
docker compose -f compose.test.yaml up -d

# Step 4: Generate test certificates with Pebble
./ssl_generate.sh test.local --pebble

# Step 5: Configure nginx for HTTPS
./ssl_configure_nginx.sh test.local

# Step 6: Test HTTPS endpoints
curl --cacert /tmp/pebble.minica.pem https://tracker.test.local/
curl --cacert /tmp/pebble.minica.pem https://grafana.test.local/

# Step 7: Clean up test environment
docker compose -f compose.test.yaml down -v
```

**Benefits of Pebble Testing**:

- Complete SSL workflow validation without external dependencies
- Fast iteration for script development and debugging
- No rate limits or domain requirements
- CI/CD integration for automated testing
- Validates nginx reconfiguration end-to-end

### 1.4 Current Nginx Template State

**Current Implementation** ✅ **PARTIAL COMPLETION**:

The nginx configuration template already exists at `infrastructure/config/templates/nginx.conf.tpl`
with the following state:

- ✅ **HTTP configuration**: Fully implemented and working
- 🔄 **HTTPS configuration**: Exists but is commented out
- ❌ **SSL activation**: No automation to uncomment HTTPS sections

**Current Template Structure**:

```nginx
# Active HTTP configuration
server {
    listen 80;
    server_name tracker.torrust-demo.com;
    # ... proxy configuration ...
}

server {
    listen 80;
    server_name grafana.torrust-demo.com;
    # ... proxy configuration ...
}

# HTTPS configuration (COMMENTED OUT)
#server {
#    listen 443 ssl http2;
#    server_name tracker.torrust-demo.com;
#    ssl_certificate /etc/letsencrypt/live/tracker.torrust-demo.com/fullchain.pem;
#    # ... SSL configuration ...
#}
# ... (full HTTPS config exists but commented)
```

**Required Implementation**:

Create automation to uncomment and activate the HTTPS configuration after SSL certificates
are generated, rather than creating separate template files.

### 1.5 Automate Certificate Renewal Setup

The renewal script already exists at `application/share/bin/ssl_renew.sh`. We need to:

1. **Update crontab configuration** in `application/share/container/default/config/crontab.conf`:

```bash
# SSL Certificate Renewal (daily at 2 AM)
0 2 * * * /home/torrust/github/torrust/torrust-tracker-demo/application/share/bin/ssl_renew.sh \
  >> /var/log/ssl-renewal.log 2>&1
```

1. **Enhance the existing ssl_renew.sh script** to handle MySQL environment:

```bash
#!/bin/bash
# Enhanced SSL certificate renewal script
# This script should be run via crontab

set -euo pipefail

APP_DIR="/home/torrust/github/torrust/torrust-tracker-demo/application"
LOG_FILE="/var/log/ssl-renewal.log"

cd "$APP_DIR"

echo "$(date): Starting SSL certificate renewal check" >> "$LOG_FILE"

# Attempt certificate renewal
if docker compose run --rm certbot renew --quiet; then
    echo "$(date): Certificate renewal successful" >> "$LOG_FILE"

    # Restart nginx to reload certificates
    docker compose restart proxy
    echo "$(date): Nginx restarted to reload certificates" >> "$LOG_FILE"
else
    echo "$(date): Certificate renewal failed or not needed" >> "$LOG_FILE"
fi

echo "$(date): SSL renewal check completed" >> "$LOG_FILE"
```

### Task 2: MySQL Database Backup Automation

#### 2.1 Create MySQL Backup Script (MISSING FILE)

**Current Issue**: The script `application/share/bin/mysql-backup.sh` is referenced by the cron
template at `infrastructure/config/templates/crontab/mysql-backup.cron` but doesn't exist yet.

**Note**: There is an existing `application/share/bin/tracker-db-backup.sh` script, but it's
for SQLite databases (legacy). The new MySQL backup script needs to be created.

**Required**: Create `application/share/bin/mysql-backup.sh`:

```bash
#!/bin/bash
# MySQL database backup script for Torrust Tracker
# Creates daily MySQL dumps in /var/lib/torrust/mysql/backups

set -euo pipefail

APP_DIR="/home/torrust/github/torrust/torrust-tracker-demo/application"
BACKUP_DIR="/var/lib/torrust/mysql/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

cd "$APP_DIR"

# Source environment variables
if [[ -f .env ]]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Create backup filename
BACKUP_FILE="torrust_tracker_backup_${DATE}.sql"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILE"

echo "Starting MySQL backup: $BACKUP_FILE"

# Create MySQL dump
docker compose exec -T mysql mysqldump \
    -u root -p"$MYSQL_ROOT_PASSWORD" \
    --single-transaction \
    --routines \
    --triggers \
    "$MYSQL_DATABASE" > "$BACKUP_PATH"

# Compress the backup
gzip "$BACKUP_PATH"
COMPRESSED_BACKUP="${BACKUP_PATH}.gz"

echo "Backup completed: $(basename "$COMPRESSED_BACKUP")"
echo "Backup size: $(du -h "$COMPRESSED_BACKUP" | cut -f1)"

# Clean up old backups (keep last 30 days)
find "$BACKUP_DIR" -name "torrust_tracker_backup_*.sql.gz" -mtime +$RETENTION_DAYS -delete

echo "Old backups cleaned up (retention: $RETENTION_DAYS days)"
echo "Backup process completed successfully"
```

#### 2.2 Crontab Template Status

**Current State**: ✅ **TEMPLATES EXIST**

The crontab templates already exist but reference missing scripts:

**File**: `infrastructure/config/templates/crontab/mysql-backup.cron` ✅ **EXISTS**

```plaintext
# MySQL Database Backup Crontab Entry
# Runs daily at 3:00 AM as torrust user
# Output is logged to /var/log/mysql-backup.log
# Requires: torrust user in docker group (already configured via cloud-init)

0 3 * * * /home/torrust/github/torrust/torrust-tracker-demo/application/share/bin/mysql-backup.sh \
  >> /var/log/mysql-backup.log 2>&1
```

**File**: `infrastructure/config/templates/crontab/ssl-renewal.cron` ✅ **EXISTS**

```plaintext
# SSL Certificate Renewal Crontab Entry
# Runs daily at 2:00 AM as torrust user (before backup to avoid conflicts)
# Output is logged to /var/log/ssl-renewal.log
# Requires: torrust user in docker group (already configured via cloud-init)

0 2 * * * /home/torrust/github/torrust/torrust-tracker-demo/application/share/bin/ssl_renew.sh \
  >> /var/log/ssl-renewal.log 2>&1
```

**Missing**: Integration automation to install these cron jobs (see Task 3 below).

```bash
#!/bin/bash
# Crontab management utilities for Torrust Tracker automation

set -euo pipefail

CRONTAB_TEMP_DIR="/tmp/torrust-crontab"
TEMPLATE_DIR="/home/torrust/github/torrust/torrust-tracker-demo/infrastructure/config/templates/crontab"

# Add a cron job from template to user's crontab
add_cronjob() {
    local template_file="$1"
    local user="${2:-torrust}"

    if [[ ! -f "${TEMPLATE_DIR}/${template_file}" ]]; then
        echo "Error: Template not found: ${TEMPLATE_DIR}/${template_file}"
        return 1
    fi

    # Create temp directory
    mkdir -p "${CRONTAB_TEMP_DIR}"

    # Get current crontab (ignore errors if no crontab exists)
    crontab -u "${user}" -l > "${CRONTAB_TEMP_DIR}/current_crontab" 2>/dev/null || true

    # Check if this cron job already exists
    local template_content
    template_content=$(grep -v '^#' "${TEMPLATE_DIR}/${template_file}" || true)

    if [[ -n "${template_content}" ]] && \
       ! grep -Fq "${template_content}" "${CRONTAB_TEMP_DIR}/current_crontab" 2>/dev/null; then
        # Add the new cron job
        {
            cat "${CRONTAB_TEMP_DIR}/current_crontab" 2>/dev/null || true
            echo ""
            cat "${TEMPLATE_DIR}/${template_file}"
        } > "${CRONTAB_TEMP_DIR}/new_crontab"

        # Install the new crontab
        crontab -u "${user}" "${CRONTAB_TEMP_DIR}/new_crontab"
        echo "Added cron job from ${template_file} for user ${user}"
    else
        echo "Cron job from ${template_file} already exists for user ${user}"
    fi

    # Cleanup
    rm -rf "${CRONTAB_TEMP_DIR}"
}

# Remove a cron job by pattern
remove_cronjob() {
    local pattern="$1"
    local user="${2:-torrust}"

    # Create temp directory
    mkdir -p "${CRONTAB_TEMP_DIR}"

    # Get current crontab
    if crontab -u "${user}" -l > "${CRONTAB_TEMP_DIR}/current_crontab" 2>/dev/null; then
        # Remove lines matching the pattern
        grep -v "${pattern}" "${CRONTAB_TEMP_DIR}/current_crontab" \
          > "${CRONTAB_TEMP_DIR}/new_crontab" || true

        # Install the new crontab
        crontab -u "${user}" "${CRONTAB_TEMP_DIR}/new_crontab"
        echo "Removed cron jobs matching '${pattern}' for user ${user}"
    else
        echo "No crontab found for user ${user}"
    fi

    # Cleanup
    rm -rf "${CRONTAB_TEMP_DIR}"
}

# List current cron jobs for user
list_cronjobs() {
    local user="${1:-torrust}"
    echo "Current cron jobs for user ${user}:"
    crontab -u "${user}" -l 2>/dev/null || echo "No crontab found"
}
```

### User Permissions and Security Considerations

**Current Implementation Analysis**:

The existing backup script uses **root user crontab** (`sudo crontab -e`), but this can be
improved for better security:

**Recommended Approach**: Use **`torrust` user** for cron jobs with appropriate sudo permissions

**Benefits**:

- ✅ **Better Security**: Reduces attack surface by avoiding root cron jobs
- ✅ **Easier Management**: User-specific crontabs are easier to manage and audit
- ✅ **Consistent Permissions**: Aligns with application file ownership

**Required Permissions**:

1. **SSL Renewal**: Requires docker group membership (already configured)
2. **Database Backup**: Requires access to MySQL container and backup directory
3. **Container Management**: May require limited sudo for container restart operations

**Sudo Configuration** (if needed):

```bash
# Add to /etc/sudoers.d/torrust-automation
torrust ALL=(ALL) NOPASSWD: /usr/bin/docker, /usr/bin/docker-compose
torrust ALL=(ALL) NOPASSWD: /bin/systemctl restart nginx
```

**Note**: The current cloud-init setup already adds `torrust` to the `docker` group, so most
operations should work without additional sudo permissions.

### Task 3: Integration and Documentation

#### 3.1 Cloud-Init Integration for Crontab Setup

Add to `infrastructure/cloud-init/user-data.yaml.tpl`:

```yaml
runcmd:
  # ... existing commands ...

  # Setup automated maintenance tasks
  - echo "Setting up automated maintenance tasks..."
  - crontab -u torrust /home/torrust/github/torrust/torrust-tracker-demo/application/share/container/default/config/crontab.conf
  - echo "Crontab configured for SSL renewal and database backups"
```

#### 3.2 Create Production Deployment Validation Script

Enhance `infrastructure/scripts/validate-deployment.sh` to check:

- MySQL backup directory exists and is writable
- Crontab is properly configured
- SSL certificate status (if domain provided)

```bash
# Add to validate-deployment.sh
check_backup_system() {
    echo "Checking backup system..."

    local backup_dir="/var/lib/torrust/mysql/backups"
    if [[ -d "$backup_dir" && -w "$backup_dir" ]]; then
        echo "✅ MySQL backup directory: READY"
    else
        echo "❌ MySQL backup directory: NOT ACCESSIBLE"
        return 1
    fi

    # Check if crontab is configured
    if crontab -l -u torrust | grep -q "mysql-backup.sh"; then
        echo "✅ MySQL backup crontab: CONFIGURED"
    else
        echo "❌ MySQL backup crontab: NOT CONFIGURED"
        return 1
    fi
}
```

## Technical Implementation Details

### Implementation Approach

The implementation **extends the existing `infrastructure/scripts/deploy-app.sh`** rather than
modifying cloud-init, since application deployment and automation are already handled by the
twelve-factor deployment scripts.

**Current Working Infrastructure** (already implemented):

- ✅ `infrastructure/scripts/provision-infrastructure.sh` - VM provisioning and system setup
- ✅ `infrastructure/scripts/deploy-app.sh` - Application deployment (Release + Run stages)
- ✅ `infrastructure/scripts/health-check.sh` - Service validation and health checks
- ✅ `infrastructure/scripts/configure-env.sh` - Environment configuration processing

**New Features to Add**:

- 🔄 **SSL automation** in `deploy-app.sh` run_stage() function
- 🔄 **Database backup automation** in `deploy-app.sh` run_stage() function
- 🔄 **New environment variables** in environment templates
- 🔄 **Supporting scripts** in `application/share/bin/`

### Integration Points

#### 1. Environment Template Updates

**File**: `infrastructure/config/environments/production.env.tpl`

```bash
# Add these new variables to existing template
# === SSL CERTIFICATE CONFIGURATION ===
DOMAIN_NAME=REPLACE_WITH_YOUR_DOMAIN
CERTBOT_EMAIL=REPLACE_WITH_YOUR_EMAIL
ENABLE_SSL=true

# === BACKUP CONFIGURATION ===
ENABLE_DB_BACKUPS=true
BACKUP_RETENTION_DAYS=7
```

**File**: `infrastructure/config/environments/local.env.tpl`

```bash
# Add these new variables to existing template
# === SSL CERTIFICATE CONFIGURATION ===
DOMAIN_NAME=test.local
CERTBOT_EMAIL=test@test.local
ENABLE_SSL=false

# === BACKUP CONFIGURATION ===
ENABLE_DB_BACKUPS=false
BACKUP_RETENTION_DAYS=3
```

#### 2. Deploy-App.sh Extensions

**Extend existing `run_stage()` function** in `infrastructure/scripts/deploy-app.sh`:

```bash
run_stage() {
    local vm_ip="$1"

    # ... existing service startup code (unchanged) ...

    # NEW: SSL automation for production
    if [[ "${ENVIRONMENT}" == "production" && "${ENABLE_SSL:-true}" == "true" ]]; then
        setup_ssl_automation "${vm_ip}"
    fi

    # NEW: Database backup automation
    if [[ "${ENABLE_DB_BACKUPS:-true}" == "true" ]]; then
        setup_backup_automation "${vm_ip}"
    fi

    log_success "Run stage completed"
}

# NEW: SSL automation function
setup_ssl_automation() {
    local vm_ip="$1"

    log_info "Setting up SSL certificates (Let's Encrypt)..."

    # Validate environment variables
    if [[ -z "${DOMAIN_NAME:-}" || -z "${CERTBOT_EMAIL:-}" ]]; then
        log_error "SSL requires DOMAIN_NAME and CERTBOT_EMAIL in environment config"
        exit 1
    fi

    # DNS validation and certificate generation
    vm_exec "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo/application
        ./share/bin/ssl_setup.sh '${DOMAIN_NAME}' '${CERTBOT_EMAIL}'
    " "SSL certificate setup"

    # Add SSL renewal crontab using template
    vm_exec "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo/application
        source ./share/bin/crontab_utils.sh
        add_cronjob 'ssl-renewal.cron' 'torrust'
    " "SSL renewal crontab setup"

    log_success "SSL setup completed"
}

# NEW: Database backup automation function
setup_backup_automation() {
    local vm_ip="$1"

    log_info "Setting up automated database backups..."

    # Setup MySQL backup script and directory
    vm_exec "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo/application
        ./share/bin/mysql_setup_backups.sh
    " "MySQL backup setup"

    # Add backup crontab using template
    vm_exec "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo/application
        source ./share/bin/crontab_utils.sh
        add_cronjob 'mysql-backup.cron' 'torrust'
    " "MySQL backup crontab setup"

    log_success "Database backup automation configured"
}
```

#### 3. New Supporting Scripts

**Create `application/share/bin/ssl_setup.sh`** (main SSL automation script):

```bash
#!/bin/bash
# Complete SSL setup automation
# Usage: ./ssl_setup.sh <domain> <email>

set -euo pipefail

DOMAIN="$1"
EMAIL="$2"

echo "🔐 Setting up SSL certificates for $DOMAIN"

# DNS validation
if ! ./ssl_validate_dns.sh "$DOMAIN"; then
    echo "❌ DNS validation failed - skipping SSL setup"
    echo "ℹ️  Run manually after DNS configuration: ./ssl_generate.sh $DOMAIN $EMAIL --production"
    exit 0
fi

# Generate certificates (staging first, then production)
./ssl_generate.sh "$DOMAIN" "$EMAIL" --staging
./ssl_generate.sh "$DOMAIN" "$EMAIL" --production

# Configure nginx for HTTPS
./ssl_configure_nginx.sh "$DOMAIN"

# Setup automatic renewal
./ssl_setup_renewal.sh

echo "✅ SSL setup completed for $DOMAIN"
```

**Supporting scripts** (already shown in implementation plan):

- `application/share/bin/ssl_generate.sh` - Certificate generation
- `application/share/bin/ssl_configure_nginx.sh` - Nginx HTTPS configuration
- `application/share/bin/ssl_setup_renewal.sh` - Crontab renewal setup
- `application/share/bin/ssl_validate_dns.sh` - DNS validation
- `application/share/bin/db_backup.sh` - Database backup execution
- `application/share/bin/db_setup_backups.sh` - Backup automation setup

### Integration with Existing Scripts

**Key advantage**: This approach leverages the existing deployment infrastructure:

- ✅ **Twelve-factor compliance**: Extends Release + Run stages appropriately
- ✅ **Consistent error handling**: Uses existing `vm_exec()` and logging functions
- ✅ **Environment awareness**: Integrates with existing environment system
- ✅ **Health validation**: Works with existing `health-check.sh` validation
- ✅ **CI/CD compatible**: Extends existing testing framework

**No changes required** to:

- `provision-infrastructure.sh` (VM provisioning)
- `health-check.sh` (service validation)
- `configure-env.sh` (environment processing)
- Cloud-init templates (system setup)

**Minimal changes** to:

- `deploy-app.sh` (extend run_stage() function only)
- Environment templates (add new variables)

This approach ensures **backward compatibility** while adding new automation features.

## Success Criteria

### Functional Requirements

1. **Maximum Automation**: Automated deployment minimizes manual steps to unavoidable external
   dependencies only
2. **Service Health**: All automated services (tracker, database, monitoring) start and pass
   health checks
3. **Network Connectivity**: All required ports are accessible and functional
4. **Data Persistence**: Database and configuration survive VM restarts
5. **Guided Manual Steps**: Clear scripts and documentation for required manual configuration

### Non-Functional Requirements

1. **Reliability**: 95% success rate for automated components of deployment
2. **Performance**: Complete automated deployment within 10 minutes of VM creation
3. **User Experience**: Manual steps take <15 minutes total with clear guidance
4. **Recoverability**: Failed deployments provide clear error messages and recovery steps
5. **Maintainability**: All automation scripts follow project coding standards

## Risk Assessment and Mitigation

### High-Risk Areas

1. **Cloud-Init Complexity**

   - **Risk**: Cloud-init failures are hard to debug
   - **Mitigation**: Comprehensive logging, staged deployment, local testing

2. **Service Dependencies**

   - **Risk**: Database startup timing issues
   - **Mitigation**: Health checks, retry logic, proper dependency ordering

3. **Network Configuration**
   - **Risk**: Firewall or networking conflicts
   - **Mitigation**: Comprehensive network testing, fallback configurations

### Medium-Risk Areas

1. **Environment Configuration**

   - **Risk**: Incorrect or missing environment variables
   - **Mitigation**: Template validation, default values, configuration testing

2. **SSL Certificate Management**
   - **Risk**: Let's Encrypt rate limiting or failures
   - **Mitigation**: Staging environment testing, fallback to self-signed certificates

## Testing Strategy

### Unit Testing

- Individual script functionality
- Template generation and validation
- Configuration parsing and validation

### Integration Testing

- Cloud-init configuration validation
- Service deployment and health checks
- Network connectivity and firewall rules

### SSL Workflow Testing

- **Pebble Local Testing**: Complete SSL certificate generation and nginx reconfiguration testing
- **Template Validation**: Nginx template processing and domain substitution
- **Certificate Management**: Staging, production, and test certificate workflows
- **Automation Scripts**: SSL generation, nginx configuration, and renewal scripts

### End-to-End Testing

- Complete VM deployment with automation
- Service functionality validation
- Performance and reliability testing

### Smoke Testing

- Post-deployment functionality verification
- API endpoint testing
- Monitoring system validation

## Success Criteria

### Primary Goals

1. **SSL Certificate Management**: Automated certificate renewal and nginx configuration with guided
   initial setup
2. **Database Backup System**: Automated daily MySQL backups with retention policy
3. **Guided Manual Steps**: Clear scripts and documentation for required manual tasks (DNS, SSL setup)
4. **Production Hardening**: All automated tasks properly configured and validated

### Secondary Goals

1. **User Experience**: Manual steps take <15 minutes total with clear guidance
2. **Error Handling**: Robust error handling and logging for both automated and manual tasks
3. **Backup Verification**: Backup system validation and monitoring
4. **Recovery Procedures**: Clear procedures for backup restoration and certificate issues

## Timeline and Dependencies

### Task 1: SSL Certificate Automation (Week 1)

- **Dependencies**: Existing nginx configuration, domain setup
- **Effort**: 2-3 days development, 1 day testing and documentation

### Task 2: MySQL Backup Automation (Week 1-2)

- **Dependencies**: MySQL service, persistent volume configuration
- **Effort**: 1-2 days development, 1 day testing

### Task 3: Integration and Documentation (Week 2)

- **Dependencies**: Tasks 1 and 2 completion
- **Effort**: 1-2 days integration, 2-3 days documentation

## Acceptance Criteria

### Primary Goals

1. **Maximum Practical Automation**: `make infra-apply` + `make app-deploy` deploys a functional
   Torrust Tracker instance with minimal manual intervention
2. **Guided Manual Steps**: Required manual steps are simple, fast, and well-documented with clear
   guidance
3. **Service Health**: All automated services pass health checks and validation
4. **Documentation Updated**: All guides reflect the actual deployment process and manual requirements

**Manual Steps That Will Still Be Required**:

- **DNS Configuration**: Point domain A records to server IP (one-time setup)
- **Environment Variables**: Configure `DOMAIN_NAME` and `CERTBOT_EMAIL` in production.env
  (one-time setup)
- **SSL Certificate Generation**: Run guided SSL setup script after DNS configuration (one-time setup)
- **Grafana Initial Setup**: Configure dashboards and data sources (optional, post-deployment)

### Secondary Goals

1. **Performance Monitoring**: Grafana dashboards show real-time metrics
2. **SSL Support**: HTTPS endpoints functional (when configured)
3. **Backup Systems**: Automated backup and recovery procedures
4. **Rollback Capability**: Failed deployments can be automatically rolled back

## Related Issues and Dependencies

- **Issue #3**: Overall Hetzner migration tracking
- **Issue #12**: MySQL database migration (prerequisite)
- **Current ADRs**: Docker services, configuration management
- **Infrastructure**: Cloud-init templates, deployment scripts
- **Application**: Docker Compose configuration, service definitions

## Documentation Updates Required

**IMPORTANT**: When implementing changes from this automation plan, ensure the following
documentation is updated to reflect any modifications to the deployment process:

- **[Cloud Deployment Guide](../guides/cloud-deployment-guide.md)**: Update deployment
  procedures, domain configuration, SSL setup, and any new automation workflows
- **[Production Setup Guide](../../application/docs/production-setup.md)**: Reflect
  changes in manual steps, environment configuration, and service deployment
- **[Integration Testing Guide](../guides/integration-testing-guide.md)**: Update
  testing procedures to match new automation workflows
- **[Grafana Setup Guide](../guides/grafana-setup-guide.md)**: Update if domain
  configuration or SSL certificate setup affects Grafana access

**Note**: The official deployment guides should always reflect the current implementation
to ensure users have accurate instructions for deploying Torrust Tracker.

Changes that require documentation updates include:

- New SSL certificate generation procedures
- Modified domain configuration requirements
- Updated nginx template usage
- New environment variable handling
- Changes to database backup automation
- Modified crontab setup procedures

**Note**: The official deployment guides should always reflect the current implementation
to ensure users have accurate instructions for deploying Torrust Tracker.

## Conclusion

Phase 3 focuses on **extending the existing deployment infrastructure** to automate the final
remaining manual steps: SSL certificate management and database backup automation.

**Key Implementation Strategy**:

- ✅ **Leverage existing scripts**: Extend `infrastructure/scripts/deploy-app.sh` instead of
  modifying cloud-init
- ✅ **Maintain twelve-factor compliance**: Add automation to Release + Run stages appropriately
- ✅ **Preserve backward compatibility**: No changes to existing infrastructure provisioning
- ✅ **Environment-specific behavior**: SSL automation only for production with proper DNS validation

**SSL Certificate Automation**:
The approach provides comprehensive SSL automation while handling the realities of DNS-dependent
certificate generation. The system validates DNS configuration before attempting certificate
generation, providing clear guidance when manual DNS setup is required. This balances automation
with reliability, following proven workflows from the [Torrust production deployment guide](https://torrust.com/blog/deploying-torrust-to-production#install-the-application).

**Database Backup Automation**:
Automated daily MySQL backups with configurable retention policies ensure data protection
following production best practices. The backup system integrates seamlessly with the existing
container infrastructure.

**Deployment Process**:
Upon completion, users will have:

1. **Infrastructure provisioning**: `make infra-apply` (unchanged, fully automated)
2. **Application deployment**: `make app-deploy` (enhanced with SSL and backup automation)
3. **Manual configuration**: Simple guided steps for DNS and SSL setup (~10-15 minutes)
4. **Health validation**: `make app-health-check` (unchanged, fully automated)

**Realistic Manual Intervention Required**:

- **DNS configuration**: Point domain to server IP (~5 minutes, external dependency)
- **Environment variables**: Configure domain and email in production.env (~2 minutes)
- **SSL setup**: Run guided SSL script after DNS propagation (~5 minutes)
- **Optional**: Grafana dashboard customization (~10-15 minutes)

**Key Achievement**: **90%+ automation** with remaining manual steps being simple, fast, and
well-guided. The enhanced deployment maintains the same reliable twelve-factor workflow while
minimizing manual operational setup to unavoidable external dependencies.
