# Twelve-Factor App Refactoring for Torrust Tracker Demo

## 📋 Implementation Status

🚧 **IN PROGRESS**: Twelve-factor refactoring is partially implemented with solid foundation completed

### ✅ Recently Completed (July 2025)

#### Infrastructure/Application Separation

- ✅ **Infrastructure provisioning**: `provision-infrastructure.sh` handles VM setup only
- ✅ **Application deployment**: `deploy-app.sh` handles application configuration
- ✅ **Local repository deployment**: Uses git archive instead of GitHub clone
- ✅ **Integration testing workflow**: 100% reliable end-to-end deployment

#### Quality Improvements

- ✅ **Database migration**: Successfully migrated from SQLite to MySQL in local environment
- ✅ **Endpoint validation**: Updated health checks for nginx proxy architecture
- ✅ **SSH authentication**: Proper key-based authentication throughout
- ✅ **Linting compliance**: All YAML, Shell, and Markdown files pass validation

### 🚧 **IN PROGRESS**: Core Configuration Management

- ❌ **Environment-based templates**: Not yet implemented
- ❌ **Automated configuration generation**: Pending
- ❌ **Secret externalization**: Still needed
- ❌ **Multi-environment support**: Partially complete

## Executive Summary

This document outlines the twelve-factor app refactoring for the Torrust Tracker
Demo repository, following [The Twelve-Factor App](https://12factor.net/) methodology.
The refactoring maintains the current local testing environment while preparing
for multi-cloud production deployments (starting with Hetzner).

## Current State Analysis

### Current Architecture

- **VM Provisioning**: Cloud-init + OpenTofu/Terraform (local KVM/libvirt)
- **Application Deployment**: Manual post-provisioning via `test-integration.sh`
- **Configuration**: Mixed approach with Docker containers and environment
  variables
- **Services**: Tracker, Prometheus, Grafana via Docker Compose
- **Environment Management**: Basic `.env.production` file

### Torrust Tracker Specific Considerations

From the official Torrust Tracker documentation, we need to account for:

#### Configuration Requirements

- **Multiple Database Drivers**: SQLite (development) and MySQL (production)
- **Service Components**: HTTP tracker, UDP tracker, and REST API
- **Port Configuration**: UDP (6868, 6969), HTTP (7070), API (1212)
- **Authentication**: Time-bound keys and access tokens
- **Performance Optimization**: Network tuning for BitTorrent traffic

#### Deployment Modes

- **Private Mode**: Requires authentication keys for tracker access
- **Public Mode**: Open tracker without authentication
- **Whitelisted Mode**: Only specific torrents allowed

#### Docker vs Source Compilation

- **Current**: Using Docker images (torrust/tracker:develop)
- **Future Plans**: Considering source compilation for production performance optimization
- **Dependencies**: pkg-config, libssl-dev, make, build-essential, libsqlite3-dev
- **Demo Repository Decision**: Uses Docker for all services to prioritize simplicity,
  consistency, and frequent updates over peak performance
  (see [ADR-002](../../../docs/adr/002-docker-for-all-services.md))

### Twelve-Factor Violations Identified

<!-- markdownlint-disable MD013 -->

| Factor                   | Current Issue                                                   | Impact |
| ------------------------ | --------------------------------------------------------------- | ------ |
| **I. Codebase**          | ✅ Good - Single repo with multiple environments                | None   |
| **II. Dependencies**     | ⚠️ Partial - Dependencies in cloud-init, not isolated           | Medium |
| **III. Config**          | ❌ Config mixed in files and env vars, not environment-specific | High   |
| **IV. Backing Services** | ✅ Good - Services are attachable resources                     | None   |
| **V. Build/Release/Run** | ❌ No clear separation, deployment mixed with infrastructure    | High   |
| **VI. Processes**        | ✅ Good - Stateless application processes                       | None   |
| **VII. Port Binding**    | ✅ Good - Services export via port binding                      | None   |
| **VIII. Concurrency**    | ✅ Good - Can scale via process model                           | None   |
| **IX. Disposability**    | ⚠️ Partial - VMs not quickly disposable due to app coupling     | Medium |
| **X. Dev/Prod Parity**   | ❌ Local and production have different deployment paths         | High   |
| **XI. Logs**             | ✅ Good - Docker logging configured                             | None   |
| **XII. Admin Processes** | ⚠️ Partial - No clear admin process separation                  | Low    |

<!-- markdownlint-enable MD013 -->

## Target Architecture

### Core Principles

1. **Infrastructure ≠ Application**: Clean separation of concerns
2. **Environment Parity**: Same deployment process for local/production
3. **Configuration as Environment**: All config via environment variables
4. **Immutable Infrastructure**: VMs are cattle, not pets
5. **Deployment Pipeline**: Clear build → release → run stages

### High-Level Architecture

The refactored architecture will separate infrastructure provisioning from
application deployment, ensuring twelve-factor compliance while maintaining
the flexibility to deploy to multiple cloud providers.

## 📋 Detailed Implementation Plan

### Phase 1: Foundation & Configuration ✅🚧 (PARTIALLY COMPLETE)

**Objective**: Establish twelve-factor configuration and deployment foundation

#### ✅ 1.1 Infrastructure/Application Separation (COMPLETED)

- ✅ **Infrastructure provisioning**: `provision-infrastructure.sh` handles VM setup only
- ✅ **Application deployment**: `deploy-app.sh` handles application configuration and deployment
- ✅ **Clean separation**: Infrastructure and application concerns clearly separated
- ✅ **Local repository deployment**: Uses git archive for testing local changes

#### 🚧 1.2 Configuration Management (IN PROGRESS)

- ❌ **Environment structure**: Create `infrastructure/config/environments/` directory
- ❌ **Configuration templates**: Implement `.tpl` files for all configurations
- ❌ **Environment variables**: Replace hardcoded values with environment-based config
- ❌ **Configuration script**: Create `configure-env.sh` for template processing

#### ✅ 1.3 Integration Testing (COMPLETED)

- ✅ **End-to-end workflow**: Complete deployment and validation working
- ✅ **Health checks**: 14/14 validation tests passing consistently
- ✅ **Database migration**: Local environment using MySQL (production parity)
- ✅ **Quality assurance**: All linting and syntax validation passing

**Status**: Infrastructure separation complete, configuration management pending

### Phase 2: Build/Release/Run Separation ✅🚧 (PARTIALLY COMPLETE)

**Objective**: Implement clear separation of build, release, and run stages

#### ✅ 2.1 Build Stage (COMPLETED)

- ✅ **Infrastructure provisioning**: VM creation, networking, base system setup
- ✅ **Base system preparation**: Docker, UFW, SSH configuration via cloud-init
- ✅ **Dependency installation**: All required tools installed during provisioning

#### 🚧 2.2 Release Stage (PARTIALLY COMPLETE)

- ✅ **Application deployment**: Working deployment from local repository
- ❌ **Configuration injection**: Still using hardcoded configuration files
- ✅ **Service orchestration**: Docker Compose working for all services

#### ✅ 2.3 Run Stage (COMPLETED)

- ✅ **Service execution**: All services running correctly
- ✅ **Health monitoring**: Comprehensive health checks implemented
- ✅ **Logging**: Docker logging configured and operational

**Status**: Build and Run stages complete, Release stage needs configuration templates

### Phase 3: Multi-Environment Support 🚧❌ (NOT STARTED)

**Objective**: Enable deployment to multiple environments and cloud providers

#### ❌ 3.1 Environment Abstraction (NOT STARTED)

- ❌ **Local environment**: Template-based configuration for local development
- ❌ **Production environment**: Template-based configuration for Hetzner
- ❌ **Environment switching**: Single command to deploy to different environments
- ❌ **Provider abstraction**: Support for multiple cloud providers

#### ❌ 3.2 Cloud Provider Support (NOT STARTED)

- ❌ **Hetzner integration**: Terraform/OpenTofu configurations for Hetzner
- ❌ **Multi-cloud capability**: Abstract provider interface
- ❌ **Network configuration**: Provider-specific networking setup

**Status**: Planned but not yet implemented

### Phase 4: Operational Excellence 🚧❌ (NOT STARTED)

**Objective**: Implement production-ready operational practices

#### ❌ 4.1 Monitoring & Observability (NOT STARTED)

- ❌ **Centralized logging**: Log aggregation and analysis
- ❌ **Advanced metrics**: Performance and business metrics
- ❌ **Alerting**: Automated alerts for critical issues

#### ❌ 4.2 Maintenance & Updates (NOT STARTED)

- ❌ **Rolling deployments**: Zero-downtime deployments
- ❌ **Backup automation**: Automated backup procedures
- ❌ **Disaster recovery**: Comprehensive recovery procedures

**Status**: Future enhancement

## 🚀 Next Steps: Complete Configuration Management

### Immediate Priority (Phase 1.2)

The next major milestone is completing the configuration management system:

#### 1. Create Environment Structure

```bash
# Create directory structure
mkdir -p infrastructure/config/environments
mkdir -p infrastructure/config/templates
mkdir -p application/config/templates

# Create environment files
infrastructure/config/environments/local.env
infrastructure/config/environments/production.env
```

#### 2. Implement Configuration Templates

- **Tracker configuration**: `infrastructure/config/templates/tracker.toml.tpl`
- **Docker Compose**: `application/config/templates/compose.yaml.tpl`
- **Environment variables**: Template-based `.env` generation

#### 3. Build Configuration Processing

- **Configuration script**: `infrastructure/scripts/configure-env.sh`
- **Template processing**: Replace variables with environment-specific values
- **Validation**: Ensure all required variables are set

#### 4. Update Deployment Scripts

- **Integration**: Use configuration templates in deployment
- **Validation**: Test multi-environment configuration
- **Documentation**: Update guides for new workflow

### Implementation Checklist

- [ ] **Environment structure**: Create config directories and files
- [ ] **Template system**: Implement `.tpl` files for all configurations
- [ ] **Configuration script**: Build template processing system
- [ ] **Environment variables**: Replace hardcoded values
- [ ] **Validation system**: Ensure configuration correctness
- [ ] **Integration testing**: Test new configuration system
- [ ] **Documentation update**: Reflect new workflow

### Success Criteria

Configuration management will be considered complete when:

1. **Environment switching**: Single command deploys to different environments
2. **No hardcoded values**: All configuration via environment variables
3. **Template validation**: All templates process correctly
4. **Documentation**: Clear guide for adding new environments

## 🏗️ Technical Architecture

### Current Working Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                     Infrastructure Layer                    │
├─────────────────────────────────────────────────────────────┤
│  • VM Provisioning (provision-infrastructure.sh)            │
│  • Base System Setup (cloud-init)                           │
│  • Network Configuration (UFW, networking)                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                        │
├─────────────────────────────────────────────────────────────┤
│  • Application Deployment (deploy-app.sh)                   │
│  • Service Configuration (Docker Compose)                   │
│  • Health Validation (health-check.sh)                      │
└─────────────────────────────────────────────────────────────┘
```

### Target Architecture (After Configuration Management)

```text
┌─────────────────────────────────────────────────────────────┐
│                 Configuration Management                    │
├─────────────────────────────────────────────────────────────┤
│  • Environment Templates (local.env, production.env)        │
│  • Configuration Processing (configure-env.sh)              │
│  • Template Rendering (.tpl → actual configs)              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                     Infrastructure Layer                    │
├─────────────────────────────────────────────────────────────┤
│  • VM Provisioning (provision-infrastructure.sh)            │
│  • Environment-specific Setup (templated cloud-init)        │
│  • Provider Abstraction (local/hetzner/aws)                 │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                        │
├─────────────────────────────────────────────────────────────┤
│  • Environment-aware Deployment (templated configs)         │
│  • Dynamic Service Configuration                            │
│  • Comprehensive Health Validation                          │
└─────────────────────────────────────────────────────────────┘
```

## 📚 Integration Testing Improvements (Completed)

This section documents the integration testing workflow improvements that were
completed as part of the foundation work.

### Local Repository Deployment

**Problem**: The deployment script was cloning from GitHub instead of using local changes.

**Solution**: Updated `deploy-app.sh` to use git archive approach:

- Creates tar.gz archive of local repository (tracked files)
- Copies archive to VM via SCP
- Extracts on VM for deployment
- Tests exactly the code being developed (including uncommitted changes)

### SSH Authentication Fixes

**Problem**: SSH authentication was failing due to configuration issues.

**Solution**: Fixed cloud-init and deployment scripts:

- Updated cloud-init template to properly configure SSH keys
- Disabled password authentication in favor of key-based auth
- Added `BatchMode=yes` to SSH commands for automation
- Fixed SSH key permissions and configuration

### Endpoint Validation Corrections

**Problem**: Health checks were testing wrong endpoints and ports.

**Solution**: Updated all endpoint validation to match current architecture:

- **Health Check**: Uses `/health_check` via nginx proxy on port 80
- **API Stats**: Uses `/api/v1/stats?token=...` via nginx proxy with auth
- **HTTP Tracker**: Expects 404 for root path (correct BitTorrent behavior)
- **Grafana**: Corrected port from 3000 to 3100

### Database Migration

**Problem**: Local environment was still configured for SQLite.

**Solution**: Successfully migrated local environment to MySQL:

- Updated Docker Compose configuration
- Fixed database connectivity tests
- Verified data persistence and performance
- Aligned local environment with production architecture

## 🎯 Summary

### What's Working Now (July 2025)

✅ **Infrastructure/Application Separation**: Clean separation implemented
✅ **Integration Testing**: 100% reliable deployment workflow
✅ **Local Development**: Test local changes without pushing to GitHub
✅ **Database Parity**: MySQL working in local environment
✅ **Health Validation**: Comprehensive 14-test validation suite
✅ **Quality Assurance**: All linting and standards compliance

### What's Next

🚧 **Configuration Management**: Template-based configuration system
🚧 **Multi-Environment**: Support for local/production/staging environments
🚧 **Production Deployment**: Hetzner cloud provider integration
🚧 **Operational Excellence**: Advanced monitoring and deployment features

The foundation is solid and the next phase is ready to begin!

## 🛠️ Detailed Migration Guide

### Migration Strategy Overview

The migration from current state to twelve-factor compliance follows a gradual approach
that maintains backward compatibility while introducing new capabilities.

#### Current vs Target Workflow

**Current Setup:**

```bash
make apply                    # Does everything: infrastructure + app
```

**Target Setup:**

```bash
make configure ENVIRONMENT=local     # Process configuration templates
make infra-apply ENVIRONMENT=local   # Infrastructure only
make app-deploy ENVIRONMENT=local    # Application only
make health-check ENVIRONMENT=local  # Validation
```

### Step 1: Create Configuration Management System

#### 1.1 Directory Structure Setup

```bash
# Create configuration management structure
mkdir -p infrastructure/config/environments
mkdir -p infrastructure/config/templates
mkdir -p application/config/templates

# Create environment-specific configuration files
infrastructure/config/environments/local.env
infrastructure/config/environments/production.env
```

#### 1.2 Environment Configuration Files

**Local Environment** (`infrastructure/config/environments/local.env`):

```bash
# Infrastructure Configuration
INFRASTRUCTURE_PROVIDER=local
INFRASTRUCTURE_VM_NAME=torrust-tracker-demo
INFRASTRUCTURE_VM_MEMORY=2048
INFRASTRUCTURE_VM_CPUS=2

# Torrust Tracker Core Configuration
TORRUST_TRACKER_MODE=public
TORRUST_TRACKER_LOG_LEVEL=debug
TORRUST_TRACKER_PRIVATE=false
TORRUST_TRACKER_STATS=true

# Database Configuration
TORRUST_TRACKER_DATABASE_DRIVER=mysql
TORRUST_TRACKER_DATABASE_HOST=mysql
TORRUST_TRACKER_DATABASE_PORT=3306
TORRUST_TRACKER_DATABASE_NAME=torrust_tracker
TORRUST_TRACKER_DATABASE_USER=torrust
TORRUST_TRACKER_DATABASE_PASSWORD=secret

# Network Configuration
TORRUST_TRACKER_UDP_PORT_6868=6868
TORRUST_TRACKER_UDP_PORT_6969=6969
TORRUST_TRACKER_HTTP_PORT=7070
TORRUST_TRACKER_API_PORT=1212

# Security Configuration
TORRUST_TRACKER_API_TOKEN=MyAccessToken

# Service Configuration
GRAFANA_ADMIN_PASSWORD=admin
PROMETHEUS_RETENTION_TIME=7d
```

**Production Environment** (`infrastructure/config/environments/production.env`):

```bash
# Infrastructure Configuration
INFRASTRUCTURE_PROVIDER=hetzner
INFRASTRUCTURE_VM_TYPE=cx31
INFRASTRUCTURE_VM_LOCATION=nbg1

# Torrust Tracker Core Configuration (production-specific)
TORRUST_TRACKER_MODE=private
TORRUST_TRACKER_LOG_LEVEL=warn
TORRUST_TRACKER_PRIVATE=true
TORRUST_TRACKER_STATS=false

# Database Configuration (production uses external values)
TORRUST_TRACKER_DATABASE_DRIVER=mysql
TORRUST_TRACKER_DATABASE_HOST=${MYSQL_HOST}
TORRUST_TRACKER_DATABASE_PORT=3306
TORRUST_TRACKER_DATABASE_NAME=torrust_tracker_prod
TORRUST_TRACKER_DATABASE_USER=${MYSQL_USER}
TORRUST_TRACKER_DATABASE_PASSWORD=${MYSQL_PASSWORD}

# Security Configuration (from CI/CD environment)
TORRUST_TRACKER_API_TOKEN=${TRACKER_ADMIN_TOKEN}
```

#### 1.3 Configuration Templates

**Tracker Configuration Template** (`infrastructure/config/templates/tracker.toml.tpl`):

```toml
[logging]
threshold = "${TORRUST_TRACKER_LOG_LEVEL}"

[core]
inactive_peer_cleanup_interval = 600
listed = false
private = ${TORRUST_TRACKER_PRIVATE:-false}
tracker_usage_statistics = ${TORRUST_TRACKER_STATS:-true}

[core.announce_policy]
interval = ${TORRUST_TRACKER_ANNOUNCE_INTERVAL:-120}
interval_min = ${TORRUST_TRACKER_ANNOUNCE_INTERVAL_MIN:-120}

[core.database]
driver = "${TORRUST_TRACKER_DATABASE_DRIVER}"
host = "${TORRUST_TRACKER_DATABASE_HOST}"
port = ${TORRUST_TRACKER_DATABASE_PORT}
database = "${TORRUST_TRACKER_DATABASE_NAME}"
username = "${TORRUST_TRACKER_DATABASE_USER}"
password = "${TORRUST_TRACKER_DATABASE_PASSWORD}"

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

**Docker Compose Template** (`application/config/templates/compose.yaml.tpl`):

```yaml
services:
  tracker:
    image: torrust/tracker:develop
    environment:
      - TORRUST_TRACKER_CONFIG=/etc/torrust/tracker/config.toml
    volumes:
      - ./config/tracker.toml:/etc/torrust/tracker/config.toml:ro
    ports:
      - "${TORRUST_TRACKER_UDP_PORT_6868}:${TORRUST_TRACKER_UDP_PORT_6868}/udp"
      - "${TORRUST_TRACKER_UDP_PORT_6969}:${TORRUST_TRACKER_UDP_PORT_6969}/udp"
      - "${TORRUST_TRACKER_HTTP_PORT}:${TORRUST_TRACKER_HTTP_PORT}"
      - "${TORRUST_TRACKER_API_PORT}:${TORRUST_TRACKER_API_PORT}"

  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: "${MYSQL_ROOT_PASSWORD}"
      MYSQL_DATABASE: "${TORRUST_TRACKER_DATABASE_NAME}"
      MYSQL_USER: "${TORRUST_TRACKER_DATABASE_USER}"
      MYSQL_PASSWORD: "${TORRUST_TRACKER_DATABASE_PASSWORD}"
    ports:
      - "3306:3306"

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml:ro

  grafana:
    image: grafana/grafana:latest
    environment:
      GF_SECURITY_ADMIN_PASSWORD: "${GRAFANA_ADMIN_PASSWORD}"
    ports:
      - "3100:3000"
```

### Step 2: Implement Configuration Processing

#### 2.1 Configuration Processing Script

**Configuration Script** (`infrastructure/scripts/configure-env.sh`):

```bash
#!/bin/bash
set -euo pipefail

# Configuration processing script
# Usage: configure-env.sh ENVIRONMENT

ENVIRONMENT="${1:-}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="${PROJECT_ROOT}/infrastructure/config"
TEMPLATES_DIR="${CONFIG_DIR}/templates"
ENV_DIR="${CONFIG_DIR}/environments"
OUTPUT_DIR="${PROJECT_ROOT}/application/config"

if [ -z "${ENVIRONMENT}" ]; then
    echo "ERROR: Environment not specified"
    echo "Usage: $0 ENVIRONMENT"
    echo "Available environments: local, production"
    exit 1
fi

ENV_FILE="${ENV_DIR}/${ENVIRONMENT}.env"
if [ ! -f "${ENV_FILE}" ]; then
    echo "ERROR: Environment file not found: ${ENV_FILE}"
    exit 1
fi

echo "Processing configuration for environment: ${ENVIRONMENT}"

# Load environment variables
set -a  # Automatically export variables
source "${ENV_FILE}"
set +a

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Process templates
for template in "${TEMPLATES_DIR}"/*.tpl; do
    if [ -f "${template}" ]; then
        filename=$(basename "${template}" .tpl)
        output_file="${OUTPUT_DIR}/${filename}"

        echo "Processing template: ${template} -> ${output_file}"
        envsubst < "${template}" > "${output_file}"
    fi
done

# Process application templates
if [ -d "${PROJECT_ROOT}/application/config/templates" ]; then
    for template in "${PROJECT_ROOT}/application/config/templates"/*.tpl; do
        if [ -f "${template}" ]; then
            filename=$(basename "${template}" .tpl)
            output_file="${PROJECT_ROOT}/application/${filename}"

            echo "Processing application template: ${template} -> ${output_file}"
            envsubst < "${template}" > "${output_file}"
        fi
    done
fi

echo "Configuration processing completed for environment: ${ENVIRONMENT}"
```

#### 2.2 Configuration Validation Script

**Validation Script** (`infrastructure/scripts/validate-config.sh`):

```bash
#!/bin/bash
set -euo pipefail

# Configuration validation script
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

validate_environment_file() {
    local env_file="$1"
    local env_name="$2"

    echo "Validating environment: ${env_name}"

    # Check required variables
    local required_vars=(
        "INFRASTRUCTURE_PROVIDER"
        "TORRUST_TRACKER_MODE"
        "TORRUST_TRACKER_DATABASE_DRIVER"
        "TORRUST_TRACKER_API_TOKEN"
    )

    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" "${env_file}"; then
            echo "ERROR: Required variable ${var} not found in ${env_file}"
            return 1
        fi
    done

    echo "✅ Environment ${env_name} validation passed"
    return 0
}

# Validate all environment files
for env_file in "${PROJECT_ROOT}/infrastructure/config/environments"/*.env; do
    if [ -f "${env_file}" ]; then
        env_name=$(basename "${env_file}" .env)
        validate_environment_file "${env_file}" "${env_name}"
    fi
done

echo "All environment configurations validated successfully"
```

### Step 3: Update Deployment Scripts

#### 3.1 Enhanced Makefile Commands

Add new commands to the Makefile while maintaining backward compatibility:

```makefile
# New twelve-factor commands
configure: ## Process configuration templates for environment
    @echo "Processing configuration for environment: $(ENVIRONMENT)"
    @if [ -z "$(ENVIRONMENT)" ]; then \
        echo "ERROR: ENVIRONMENT not specified. Use: make configure ENVIRONMENT=local"; \
        exit 1; \
    fi
    ./infrastructure/scripts/configure-env.sh $(ENVIRONMENT)

validate-config: ## Validate configuration files
    @echo "Validating configuration files..."
    ./infrastructure/scripts/validate-config.sh

infra-apply: ## Deploy infrastructure for environment
    @echo "Deploying infrastructure for environment: $(ENVIRONMENT)"
    @if [ -z "$(ENVIRONMENT)" ]; then \
        echo "ERROR: ENVIRONMENT not specified. Use: make infra-apply ENVIRONMENT=local"; \
        exit 1; \
    fi
    ./infrastructure/scripts/provision-infrastructure.sh $(ENVIRONMENT)

app-deploy: configure ## Deploy application for environment
    @echo "Deploying application for environment: $(ENVIRONMENT)"
    @if [ -z "$(ENVIRONMENT)" ]; then \
        echo "ERROR: ENVIRONMENT not specified. Use: make app-deploy ENVIRONMENT=local"; \
        exit 1; \
    fi
    ./infrastructure/scripts/deploy-app.sh $(ENVIRONMENT)

deploy: infra-apply app-deploy health-check ## Full deployment (infrastructure + application + validation)
    @echo "Full deployment completed for environment: $(ENVIRONMENT)"

# Legacy commands with deprecation warnings
apply: ## Deploy VM with application (DEPRECATED - use 'make deploy ENVIRONMENT=local')
    @echo "⚠️  DEPRECATED: 'make apply' is deprecated."
    @echo "⚠️  Use: 'make deploy ENVIRONMENT=local' for twelve-factor deployment"
    @echo "⚠️  Continuing with legacy deployment..."
    $(MAKE) deploy ENVIRONMENT=local
```

### Step 4: Migration Timeline

#### Week 1: Foundation

- [ ] Create configuration directory structure
- [ ] Implement basic environment files (local.env, production.env)
- [ ] Create configuration processing script (`configure-env.sh`)
- [ ] Test template processing with existing hardcoded values

#### Week 2: Template System

- [ ] Create configuration templates (.tpl files)
- [ ] Update deployment scripts to use templates
- [ ] Test local deployment with template system
- [ ] Validate all services work with templated configuration

#### Week 3: Integration and Testing

- [ ] Update Makefile with new commands
- [ ] Test backward compatibility with legacy commands
- [ ] Update documentation and guides
- [ ] Comprehensive testing of new workflow

#### Week 4: Production Preparation

- [ ] Create production environment configuration
- [ ] Test environment switching (local ↔ production)
- [ ] Implement secret management for production
- [ ] Final validation and documentation

### Migration Validation Checklist

#### Configuration Management

- [ ] Environment files created and validated
- [ ] Template processing script working
- [ ] All templates render correctly
- [ ] No hardcoded values remaining in configurations

#### Deployment Workflow

- [ ] New deployment commands working (`configure`, `infra-apply`, `app-deploy`)
- [ ] Legacy commands still functional with deprecation warnings
- [ ] Environment switching working correctly
- [ ] Health checks passing for templated deployments

#### Documentation and Training

- [ ] Documentation updated to reflect new workflow
- [ ] Migration guide completed and tested
- [ ] Team trained on new commands and processes
- [ ] Troubleshooting guide available

### Rollback Strategy

In case issues arise during migration:

1. **Immediate rollback**: Legacy commands (`make apply`) continue to work
2. **Partial rollback**: Disable new commands, use hardcoded configurations
3. **Configuration rollback**: Revert to `.env.production` file approach
4. **Documentation**: Clear rollback procedures documented

The migration is designed to be low-risk with multiple safety nets to ensure
continuous operation throughout the transition.
