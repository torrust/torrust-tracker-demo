# Implementation Checklist: Phase 1 - Foundation & Configuration

## Overview

This checklist provides detailed implementation steps for Phase 1 of the
Twelve-Factor App refactoring plan. This phase focuses on establishing the
foundation for configuration management and deployment separation.

## Week 1: Configuration Management Refactor

### 1.1 Environment Configuration Structure

#### Task 1.1.1: Create Environment Directory Structure

```bash
mkdir -p infrastructure/config/environments
mkdir -p infrastructure/config/templates
mkdir -p application/config/templates
```

**Files to create:**

- [ ] `infrastructure/config/environments/local.env`
- [ ] `infrastructure/config/environments/staging.env`
- [ ] `infrastructure/config/environments/production.env`
- [ ] `infrastructure/config/templates/tracker.toml.tpl`
- [ ] `infrastructure/config/templates/prometheus.yml.tpl`

#### Task 1.1.2: Environment Variable Definition

**Local Environment (`local.env`):**

```bash
# Infrastructure Configuration
INFRASTRUCTURE_PROVIDER=local
INFRASTRUCTURE_VM_NAME=torrust-tracker-demo
INFRASTRUCTURE_VM_MEMORY=2048
INFRASTRUCTURE_VM_CPUS=2

# Torrust Tracker Core Configuration
TORRUST_TRACKER_MODE=public
TORRUST_TRACKER_LOG_LEVEL=debug
TORRUST_TRACKER_LISTED=false
TORRUST_TRACKER_PRIVATE=false
TORRUST_TRACKER_STATS=true

# Database Configuration
TORRUST_TRACKER_DATABASE_DRIVER=sqlite3
TORRUST_TRACKER_DATABASE_PATH=./storage/tracker/lib/database/sqlite3.db

# Network Configuration
TORRUST_TRACKER_EXTERNAL_IP=0.0.0.0
TORRUST_TRACKER_ON_REVERSE_PROXY=false

# Tracker Policy
TORRUST_TRACKER_CLEANUP_INTERVAL=600
TORRUST_TRACKER_MAX_PEER_TIMEOUT=900
TORRUST_TRACKER_PERSISTENT_COMPLETED_STAT=false
TORRUST_TRACKER_REMOVE_PEERLESS=true

# Announce Policy
TORRUST_TRACKER_ANNOUNCE_INTERVAL=120
TORRUST_TRACKER_ANNOUNCE_INTERVAL_MIN=120

# Port Configuration
TORRUST_TRACKER_UDP_6868_ENABLED=true
TORRUST_TRACKER_UDP_6969_ENABLED=true
TORRUST_TRACKER_HTTP_ENABLED=true
TORRUST_TRACKER_HTTP_PORT=7070
TORRUST_TRACKER_API_PORT=1212
TORRUST_TRACKER_HEALTH_CHECK_PORT=1313

# API Authentication
TORRUST_TRACKER_API_TOKEN=local-dev-token

# Service Configuration
GRAFANA_ADMIN_PASSWORD=admin
PROMETHEUS_RETENTION_TIME=7d

# Docker Configuration
USER_ID=1000
```

**Staging Environment (`staging.env`):**

```bash
# Infrastructure
INFRASTRUCTURE_PROVIDER=hetzner
INFRASTRUCTURE_REGION=fsn1
INFRASTRUCTURE_INSTANCE_TYPE=cx11

# Application
TORRUST_TRACKER_MODE=private
TORRUST_TRACKER_LOG_LEVEL=info
TORRUST_TRACKER_DATABASE_DRIVER=sqlite3
TORRUST_TRACKER_API_TOKEN=${TORRUST_STAGING_API_TOKEN}

# Services
GRAFANA_ADMIN_PASSWORD=${GRAFANA_STAGING_PASSWORD}
PROMETHEUS_RETENTION_TIME=15d

# Security
SSH_PUBLIC_KEY=${SSH_PUBLIC_KEY}
DOMAIN_NAME=staging.torrust-demo.com
SSL_EMAIL=${SSL_EMAIL}
```

**Production Environment (`production.env`):**

```bash
# Infrastructure Configuration
INFRASTRUCTURE_PROVIDER=hetzner
INFRASTRUCTURE_REGION=fsn1
INFRASTRUCTURE_INSTANCE_TYPE=cx21

# Torrust Tracker Core Configuration
TORRUST_TRACKER_MODE=private
TORRUST_TRACKER_LOG_LEVEL=info
TORRUST_TRACKER_LISTED=false
TORRUST_TRACKER_PRIVATE=true
TORRUST_TRACKER_STATS=true

# Database Configuration (MySQL for production)
TORRUST_TRACKER_DATABASE_DRIVER=mysql
TORRUST_TRACKER_DATABASE_URL=${TORRUST_PROD_DATABASE_URL}

# Network Configuration
TORRUST_TRACKER_EXTERNAL_IP=${PRODUCTION_EXTERNAL_IP}
TORRUST_TRACKER_ON_REVERSE_PROXY=true

# Tracker Policy (production optimized)
TORRUST_TRACKER_CLEANUP_INTERVAL=300
TORRUST_TRACKER_MAX_PEER_TIMEOUT=1800
TORRUST_TRACKER_PERSISTENT_COMPLETED_STAT=true
TORRUST_TRACKER_REMOVE_PEERLESS=false

# Announce Policy (production optimized)
TORRUST_TRACKER_ANNOUNCE_INTERVAL=600
TORRUST_TRACKER_ANNOUNCE_INTERVAL_MIN=300

# Port Configuration
TORRUST_TRACKER_UDP_6868_ENABLED=true
TORRUST_TRACKER_UDP_6969_ENABLED=true
TORRUST_TRACKER_HTTP_ENABLED=true
TORRUST_TRACKER_HTTP_PORT=7070
TORRUST_TRACKER_API_PORT=1212
TORRUST_TRACKER_HEALTH_CHECK_PORT=1313

# API Authentication (from secrets)
TORRUST_TRACKER_API_TOKEN=${TORRUST_PROD_API_TOKEN}

# Service Configuration
GRAFANA_ADMIN_PASSWORD=${GRAFANA_PROD_PASSWORD}
PROMETHEUS_RETENTION_TIME=30d

# Security Configuration
SSH_PUBLIC_KEY=${SSH_PUBLIC_KEY}
DOMAIN_NAME=torrust-demo.com
SSL_EMAIL=${SSL_EMAIL}

# Docker Configuration
USER_ID=1000
```

#### Task 1.1.3: Configuration Template Creation

**Tracker Configuration Template (`tracker.toml.tpl`):**

```toml
[logging]
threshold = "${TORRUST_TRACKER_LOG_LEVEL}"

[core]
inactive_peer_cleanup_interval = ${TORRUST_TRACKER_CLEANUP_INTERVAL:-600}
listed = ${TORRUST_TRACKER_LISTED:-false}
private = ${TORRUST_TRACKER_PRIVATE:-false}
tracker_usage_statistics = ${TORRUST_TRACKER_STATS:-true}

[core.announce_policy]
interval = ${TORRUST_TRACKER_ANNOUNCE_INTERVAL:-120}
interval_min = ${TORRUST_TRACKER_ANNOUNCE_INTERVAL_MIN:-120}

[core.database]
driver = "${TORRUST_TRACKER_DATABASE_DRIVER}"
{{#if (eq TORRUST_TRACKER_DATABASE_DRIVER "sqlite3")}}
path = "${TORRUST_TRACKER_DATABASE_PATH:-./storage/tracker/lib/database/sqlite3.db}"
{{else}}
url = "${TORRUST_TRACKER_DATABASE_URL}"
{{/if}}

[core.net]
external_ip = "${TORRUST_TRACKER_EXTERNAL_IP:-0.0.0.0}"
on_reverse_proxy = ${TORRUST_TRACKER_ON_REVERSE_PROXY:-false}

[core.tracker_policy]
max_peer_timeout = ${TORRUST_TRACKER_MAX_PEER_TIMEOUT:-900}
persistent_torrent_completed_stat = ${TORRUST_TRACKER_PERSISTENT_COMPLETED_STAT:-false}
remove_peerless_torrents = ${TORRUST_TRACKER_REMOVE_PEERLESS:-true}

# Health check API (separate from main API)
[health_check_api]
bind_address = "127.0.0.1:${TORRUST_TRACKER_HEALTH_CHECK_PORT:-1313}"

# Main HTTP API
[http_api]
bind_address = "0.0.0.0:${TORRUST_TRACKER_API_PORT:-1212}"

[http_api.access_tokens]
admin = "${TORRUST_TRACKER_API_TOKEN}"

# UDP Trackers (multiple instances supported)
{{#if TORRUST_TRACKER_UDP_6868_ENABLED}}
[[udp_trackers]]
bind_address = "0.0.0.0:6868"
{{/if}}

{{#if TORRUST_TRACKER_UDP_6969_ENABLED}}
[[udp_trackers]]
bind_address = "0.0.0.0:6969"
{{/if}}

# HTTP Trackers (multiple instances supported)
{{#if TORRUST_TRACKER_HTTP_ENABLED}}
[[http_trackers]]
bind_address = "0.0.0.0:${TORRUST_TRACKER_HTTP_PORT:-7070}"
{{/if}}
```

#### Task 1.1.4: Torrust Tracker Configuration Strategy

Based on the official Torrust Tracker documentation, the tracker supports
multiple configuration methods with the following priority order:

1. **Environment Variable TORRUST_TRACKER_CONFIG_TOML** (highest priority)
2. **tracker.toml file** (medium priority)
3. **Default configuration** (lowest priority)

For twelve-factor compliance, we'll use method #1 (environment variables) with
the following approach:

**Configuration Generation Script (`generate-tracker-config.sh`):**

```bash
#!/bin/bash
# Generate tracker configuration from environment variables

set -euo pipefail

# Generate tracker.toml from template
envsubst < "${CONFIG_DIR}/templates/tracker.toml.tpl" > "/tmp/tracker.toml"

# Set the TORRUST_TRACKER_CONFIG_TOML environment variable
export TORRUST_TRACKER_CONFIG_TOML="$(cat /tmp/tracker.toml)"

# Clean up temporary file
rm -f "/tmp/tracker.toml"

echo "Tracker configuration generated from environment variables"
```

#### Alternative: Direct Environment Variable Configuration

For even better twelve-factor compliance, we can use the tracker's support
for environment variable overrides:

```bash
# Core configuration
export TORRUST_TRACKER_CONFIG_OVERRIDE_CORE__DATABASE__DRIVER="${TORRUST_TRACKER_DATABASE_DRIVER}"
export TORRUST_TRACKER_CONFIG_OVERRIDE_CORE__DATABASE__PATH="${TORRUST_TRACKER_DATABASE_PATH}"
export TORRUST_TRACKER_CONFIG_OVERRIDE_CORE__NET__EXTERNAL_IP="${TORRUST_TRACKER_EXTERNAL_IP}"

# HTTP API configuration
export TORRUST_TRACKER_CONFIG_OVERRIDE_HTTP_API__ACCESS_TOKENS__ADMIN="${TORRUST_TRACKER_API_TOKEN}"

# Logging configuration
export TORRUST_TRACKER_CONFIG_OVERRIDE_LOGGING__THRESHOLD="${TORRUST_TRACKER_LOG_LEVEL}"
```

### 1.2 Configuration Processing Scripts

#### Task 1.2.1: Create Configuration Processing Script

**File:** `infrastructure/scripts/configure-env.sh`

```bash
#!/bin/bash
# Configuration processing script for Torrust Tracker Demo
# Processes environment variables and generates configuration files

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_DIR="${PROJECT_ROOT}/infrastructure/config"

# Default values
ENVIRONMENT="${1:-local}"
VERBOSE="${VERBOSE:-false}"

# Logging functions
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

# Load environment configuration
load_environment() {
    local env_file="${CONFIG_DIR}/environments/${ENVIRONMENT}.env"

    if [[ ! -f "${env_file}" ]]; then
        log_error "Environment file not found: ${env_file}"
        exit 1
    fi

    log_info "Loading environment: ${ENVIRONMENT}"
    # shellcheck source=/dev/null
    source "${env_file}"
}

# Validate required environment variables
validate_environment() {
    local required_vars=(
        "INFRASTRUCTURE_PROVIDER"
        "TORRUST_TRACKER_MODE"
        "TORRUST_TRACKER_LOG_LEVEL"
        "TORRUST_TRACKER_API_TOKEN"
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required environment variable not set: ${var}"
            exit 1
        fi
    done

    log_info "Environment validation passed"
}

# Process configuration templates
process_templates() {
    local templates_dir="${CONFIG_DIR}/templates"
    local output_dir="${PROJECT_ROOT}/application/storage/tracker/etc"

    # Ensure output directory exists
    mkdir -p "${output_dir}"

    # Process tracker configuration template
    if [[ -f "${templates_dir}/tracker.toml.tpl" ]]; then
        log_info "Processing tracker configuration template"
        envsubst < "${templates_dir}/tracker.toml.tpl" > "${output_dir}/tracker.toml"
    fi

    log_info "Configuration templates processed"
}

# Main execution
main() {
    log_info "Starting configuration processing for environment: ${ENVIRONMENT}"

    load_environment
    validate_environment
    process_templates

    log_info "Configuration processing completed successfully"
}

# Show help
show_help() {
    cat <<EOF
Configuration Processing Script

Usage: $0 [ENVIRONMENT]

Arguments:
    ENVIRONMENT    Environment name (local, staging, production)

Examples:
    $0 local       # Process local environment configuration
    $0 staging     # Process staging environment configuration
    $0 production  # Process production environment configuration

Environment Variables:
    VERBOSE        Enable verbose output (true/false)
EOF
}

# Handle arguments
case "${1:-}" in
    "help"|"-h"|"--help")
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
```

#### Task 1.2.2: Create Configuration Validation Script

**File:** `infrastructure/scripts/validate-config.sh`

```bash
#!/bin/bash
# Configuration validation script for Torrust Tracker Demo

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_DIR="${PROJECT_ROOT}/infrastructure/config"

# Validation functions
validate_env_file() {
    local env_file="$1"
    local environment="$2"

    echo "[INFO] Validating environment file: ${env_file}"

    # Check file exists and is readable
    if [[ ! -f "${env_file}" ]]; then
        echo "[ERROR] Environment file not found: ${env_file}"
        return 1
    fi

    # Check for required variables
    local required_vars=(
        "INFRASTRUCTURE_PROVIDER"
        "TORRUST_TRACKER_MODE"
        "TORRUST_TRACKER_LOG_LEVEL"
        "TORRUST_TRACKER_API_TOKEN"
    )

    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" "${env_file}"; then
            echo "[ERROR] Required variable ${var} not found in ${env_file}"
            return 1
        fi
    done

    echo "[SUCCESS] Environment file validation passed: ${environment}"
    return 0
}

validate_templates() {
    local templates_dir="${CONFIG_DIR}/templates"

    echo "[INFO] Validating configuration templates"

    # Check tracker template
    local tracker_template="${templates_dir}/tracker.toml.tpl"
    if [[ ! -f "${tracker_template}" ]]; then
        echo "[ERROR] Tracker template not found: ${tracker_template}"
        return 1
    fi

    # Basic TOML syntax validation (if available)
    if command -v taplo >/dev/null 2>&1; then
        # Create temporary file with sample values for validation
        local temp_file
        temp_file=$(mktemp)

        # Set sample environment variables
        export TORRUST_TRACKER_LOG_LEVEL="info"
        export TORRUST_TRACKER_DATABASE_DRIVER="sqlite3"
        export TORRUST_TRACKER_API_TOKEN="sample-token"
        export TORRUST_TRACKER_API_PORT="1212"

        # Process template and validate
        envsubst < "${tracker_template}" > "${temp_file}"

        if taplo fmt --check "${temp_file}" >/dev/null 2>&1; then
            echo "[SUCCESS] Tracker template TOML syntax validation passed"
        else
            echo "[ERROR] Tracker template TOML syntax validation failed"
            rm -f "${temp_file}"
            return 1
        fi

        rm -f "${temp_file}"
    else
        echo "[WARNING] taplo not available, skipping TOML syntax validation"
    fi

    echo "[SUCCESS] Template validation passed"
    return 0
}

# Main validation
main() {
    echo "[INFO] Starting configuration validation"

    local failed=0

    # Validate environment files
    for env in local staging production; do
        env_file="${CONFIG_DIR}/environments/${env}.env"
        if ! validate_env_file "${env_file}" "${env}"; then
            failed=1
        fi
    done

    # Validate templates
    if ! validate_templates; then
        failed=1
    fi

    if [[ ${failed} -eq 0 ]]; then
        echo "[SUCCESS] All configuration validation passed"
        return 0
    else
        echo "[ERROR] Configuration validation failed"
        return 1
    fi
}

# Run validation
main "$@"
```

## Week 2: Deployment Separation

### 2.1 Infrastructure Provisioning Scripts

#### Task 2.1.1: Create Infrastructure Provisioning Script

**File:** `infrastructure/scripts/provision-infrastructure.sh`

```bash
#!/bin/bash
# Infrastructure provisioning script for Torrust Tracker Demo
# Provisions base infrastructure without application deployment

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/infrastructure/terraform"

# Default values
ENVIRONMENT="${1:-local}"
ACTION="${2:-apply}"

# Logging functions
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

# Load environment configuration
load_environment() {
    local config_script="${SCRIPT_DIR}/configure-env.sh"

    if [[ -f "${config_script}" ]]; then
        log_info "Loading environment configuration: ${ENVIRONMENT}"
        "${config_script}" "${ENVIRONMENT}"
    else
        log_error "Configuration script not found: ${config_script}"
        exit 1
    fi
}

# Provision infrastructure
provision_infrastructure() {
    log_info "Provisioning infrastructure for environment: ${ENVIRONMENT}"

    cd "${TERRAFORM_DIR}"

    case "${ACTION}" in
        "init")
            log_info "Initializing Terraform"
            tofu init
            ;;
        "plan")
            log_info "Planning infrastructure changes"
            tofu plan -var="environment=${ENVIRONMENT}"
            ;;
        "apply")
            log_info "Applying infrastructure changes"
            tofu apply -var="environment=${ENVIRONMENT}" -auto-approve
            ;;
        "destroy")
            log_info "Destroying infrastructure"
            tofu destroy -var="environment=${ENVIRONMENT}" -auto-approve
            ;;
        *)
            log_error "Unknown action: ${ACTION}"
            exit 1
            ;;
    esac
}

# Main execution
main() {
    log_info "Starting infrastructure provisioning"

    load_environment
    provision_infrastructure

    log_info "Infrastructure provisioning completed"
}

# Show help
show_help() {
    cat <<EOF
Infrastructure Provisioning Script

Usage: $0 [ENVIRONMENT] [ACTION]

Arguments:
    ENVIRONMENT    Environment name (local, staging, production)
    ACTION         Action to perform (init, plan, apply, destroy)

Examples:
    $0 local init     # Initialize Terraform for local environment
    $0 local plan     # Plan infrastructure changes for local
    $0 local apply    # Apply infrastructure changes for local
    $0 local destroy  # Destroy local infrastructure
EOF
}

# Handle arguments
case "${1:-}" in
    "help"|"-h"|"--help")
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
```

#### Task 2.1.2: Create Application Deployment Script

**File:** `infrastructure/scripts/deploy-app.sh`

```bash
#!/bin/bash
# Application deployment script for Torrust Tracker Demo
# Deploys application to provisioned infrastructure

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/infrastructure/terraform"

# Default values
ENVIRONMENT="${1:-local}"
VM_IP="${2:-}"

# Logging functions
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

# Get VM IP from Terraform output
get_vm_ip() {
    if [[ -n "${VM_IP}" ]]; then
        echo "${VM_IP}"
        return 0
    fi

    cd "${TERRAFORM_DIR}"
    local vm_ip
    vm_ip=$(tofu output -raw vm_ip 2>/dev/null || echo "")

    if [[ -z "${vm_ip}" ]]; then
        log_error "Could not get VM IP from Terraform output"
        return 1
    fi

    echo "${vm_ip}"
}

# Execute command on VM via SSH
vm_exec() {
    local vm_ip="$1"
    local command="$2"
    local description="${3:-}"

    if [[ -n "${description}" ]]; then
        log_info "${description}"
    fi

    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30 torrust@"${vm_ip}" "${command}"
}

# Deploy application
deploy_application() {
    local vm_ip="$1"

    log_info "Deploying application to ${vm_ip}"

    # Clone/update repository
    vm_exec "${vm_ip}" "
        mkdir -p /home/torrust/github/torrust
        cd /home/torrust/github/torrust

        if [ -d torrust-tracker-demo ]; then
            cd torrust-tracker-demo && git pull
        else
            git clone https://github.com/torrust/torrust-tracker-demo.git
        fi
    " "Setting up application repository"

    # Process configuration
    vm_exec "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo
        infrastructure/scripts/configure-env.sh ${ENVIRONMENT}
    " "Processing configuration for environment: ${ENVIRONMENT}"

    # Start services
    vm_exec "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo/application
        docker compose up -d
    " "Starting application services"

    log_info "Application deployment completed"
}

# Validate deployment
validate_deployment() {
    local vm_ip="$1"

    log_info "Validating deployment"

    # Wait for services to be ready
    sleep 30

    # Check service health
    vm_exec "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo/application
        docker compose ps
    " "Checking service status"

    # Test endpoints
    vm_exec "${vm_ip}" "
        curl -f -s http://localhost:7070/health_check || exit 1
        curl -f -s http://localhost:1212/api/v1/stats || exit 1
    " "Testing application endpoints"

    log_info "Deployment validation completed successfully"
}

# Main execution
main() {
    log_info "Starting application deployment for environment: ${ENVIRONMENT}"

    local vm_ip
    vm_ip=$(get_vm_ip)

    deploy_application "${vm_ip}"
    validate_deployment "${vm_ip}"

    log_info "Application deployment completed successfully"
}

# Show help
show_help() {
    cat <<EOF
Application Deployment Script

Usage: $0 [ENVIRONMENT] [VM_IP]

Arguments:
    ENVIRONMENT    Environment name (local, staging, production)
    VM_IP          VM IP address (optional, will get from Terraform if not provided)

Examples:
    $0 local                    # Deploy to local environment
    $0 staging 192.168.1.100   # Deploy to staging with specific IP
    $0 production               # Deploy to production (get IP from Terraform)
EOF
}

# Handle arguments
case "${1:-}" in
    "help"|"-h"|"--help")
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
```

## Completion Checklist

### Week 1 Deliverables

- [ ] Environment configuration structure created
- [ ] Environment-specific `.env` files created
- [ ] Configuration templates created
- [ ] Configuration processing script implemented
- [ ] Configuration validation script implemented
- [ ] All scripts are executable and tested
- [ ] Documentation updated

### Week 2 Deliverables

- [ ] Infrastructure provisioning script created
- [ ] Application deployment script created
- [ ] Deployment validation implemented
- [ ] Scripts integrated with existing Makefile
- [ ] End-to-end testing completed
- [ ] Documentation updated

### Integration Tasks

- [ ] Update Makefile with new targets
- [ ] Update existing scripts to use new configuration system
- [ ] Ensure backward compatibility maintained
- [ ] Add integration tests for new deployment process
- [ ] Update CI/CD workflows if applicable

### Testing Requirements

- [ ] Test all environment configurations
- [ ] Test infrastructure provisioning for all environments
- [ ] Test application deployment for all environments
- [ ] Test configuration validation
- [ ] Test error handling and rollback scenarios
- [ ] Performance testing for deployment speed

### Documentation Requirements

- [ ] Update README.md with new deployment process
- [ ] Create deployment guides for each environment
- [ ] Document configuration variables and their purposes
- [ ] Create troubleshooting guide
- [ ] Update architecture documentation

## Notes

- Ensure all scripts follow POSIX compliance
- Implement proper error handling and logging
- Use shellcheck for script validation
- Test on clean environment before proceeding to next phase
- Maintain backward compatibility during transition period
