# Multi-Provider Architecture Implementation Plan

## Overview

This plan implements a clean multi-provider architecture that properly separates
environments from infrastructure providers, ensuring the system can scale to support
unlimited providers without code changes.

## Implementation Status

### Current Status: PHASE 3 COMPLETED ✅

- ✅ **Phase 1**: Foundation - Rename and Restructure (COMPLETED)
- ✅ **Phase 2**: Provider System Implementation (COMPLETED)
- ✅ **Phase 3**: Enhanced Makefile and Commands (COMPLETED)
- ⏸️ **Phase 4**: Hetzner Provider Implementation (PLANNED)
- ⏸️ **Phase 5**: Testing and Documentation (PLANNED)

### Key Achievements

#### Phase 1 Completed (August 1, 2025)

- ✅ Renamed `local` environment to `development` for clarity
- ✅ Updated all scripts and documentation references
- ✅ Environment validation and testing completed

#### Phase 2 Completed (August 1, 2025)

- ✅ **Multi-Provider Architecture**: Complete pluggable provider system with standardized interface
- ✅ **LibVirt Provider Module**: Full Terraform module implementation as first provider
- ✅ **SSH Key Auto-Detection**: Robust security system that eliminates hardcoded keys
- ✅ **Enhanced User Experience**: Improved messaging and error handling
- ✅ **Performance Validated**: E2E tests completing in ~2m 35s consistently
- ✅ **Security Improvements**: No hardcoded SSH keys, auto-detection from user's ~/.ssh/
- ✅ **Integration Points**: PROVIDER parameter support in Makefile commands

#### Phase 3 Completed (August 1, 2025)

- ✅ **Enhanced Makefile Commands**: Parameter validation for all infrastructure commands
- ✅ **Provider Discovery**: `infra-providers` command lists available providers
- ✅ **Environment Listing**: `infra-environments` command shows available environments
- ✅ **Provider Information**: `provider-info` command displays detailed provider configuration
- ✅ **Parameter Validation**: Robust error handling for invalid provider/environment combinations
- ✅ **User Experience**: Clear error messages and usage examples
- ✅ **Command Integration**: All infrastructure commands use `check-infra-params` validation

#### Current File Structure

```text
infrastructure/terraform/providers/libvirt/
├── main.tf              # Provider-specific infrastructure resources
├── variables.tf         # Provider-specific variables
├── outputs.tf          # Provider-specific outputs
├── versions.tf         # Provider requirements and version constraints
└── provider.sh         # Provider interface implementation with SSH validation
```

#### Working Commands

```bash
# Current working syntax
make infra-apply ENVIRONMENT=development PROVIDER=libvirt
make infra-destroy ENVIRONMENT=development PROVIDER=libvirt
make app-deploy ENVIRONMENT=development
make app-health-check ENVIRONMENT=development

# SSH key auto-detection working
# Checks: ~/.ssh/torrust_rsa.pub, ~/.ssh/id_rsa.pub, ~/.ssh/id_ed25519.pub, ~/.ssh/id_ecdsa.pub
```

## Design Principles

### 1. Clear Separation of Concerns

- **Environment**: What configuration to use (development, staging, production)
- **Provider**: Where to deploy the infrastructure (libvirt, hetzner, aws, digitalocean)

### 2. Pluggable Provider System

- Each provider is self-contained with a standard interface
- Core scripts discover and invoke provider functions
- No hardcoded switches or provider-specific logic in core code

### 3. Scalable Architecture

- Adding new providers requires zero changes to existing code
- Provider implementations are independent and isolated
- Standard interfaces ensure consistency

## Terminology Clarification

### Environments

- **`development`**: Local development and testing configuration
- **`staging`**: Pre-production testing configuration
- **`production`**: Production configuration

### Providers

- **`libvirt`**: Local KVM/libvirt virtualization
- **`hetzner`**: Hetzner Cloud
- **`digitalocean`**: DigitalOcean Droplets
- **`aws`**: Amazon Web Services EC2
- **`gcp`**: Google Cloud Platform

### Usage Examples

```bash
# Development environment on local infrastructure
make infra-apply ENVIRONMENT=development PROVIDER=libvirt

# Staging environment on DigitalOcean
make infra-apply ENVIRONMENT=staging PROVIDER=digitalocean

# Production environment on Hetzner
make infra-apply ENVIRONMENT=production PROVIDER=hetzner

# Production environment on AWS (alternative)
make infra-apply ENVIRONMENT=production PROVIDER=aws
```

## Target Architecture

### Directory Structure

```text
infrastructure/
├── terraform/
│   ├── main.tf                    # Provider-agnostic orchestration
│   ├── variables.tf               # Standard interface variables
│   ├── outputs.tf                 # Standard interface outputs
│   └── providers/                 # Pluggable provider modules
│       ├── libvirt/              # Local KVM/libvirt provider
│       │   ├── main.tf
│       │   ├── variables.tf      # Implements standard interface
│       │   ├── outputs.tf        # Implements standard interface
│       │   └── provider.sh       # Provider-specific functions
│       ├── hetzner/              # Hetzner Cloud provider
│       │   ├── main.tf
│       │   ├── variables.tf      # Implements standard interface
│       │   ├── outputs.tf        # Implements standard interface
│       │   └── provider.sh       # Provider-specific functions
│       └── [future-providers]/   # AWS, GCP, etc.
├── config/
│   ├── environments/
│   │   ├── development.env       # Development environment config
│   │   ├── staging.env.tpl       # Staging environment template
│   │   └── production.env.tpl    # Production environment template
│   └── providers/                # Provider-specific configurations
│       ├── libvirt.env           # LibVirt provider defaults
│       ├── hetzner.env.tpl       # Hetzner provider template
│       └── [provider].env.tpl    # Other provider templates
└── scripts/
    ├── providers/                # Provider interface
    │   └── provider-interface.sh # Standard provider functions
    └── [existing scripts]
```

### Provider Interface Standard

Each provider must implement these functions in `providers/[name]/provider.sh`:

```bash
#!/bin/bash
# Provider interface implementation for [PROVIDER_NAME]

# Validate provider-specific prerequisites
provider_validate_prerequisites() {
    # Provider-specific validation logic
}

# Generate provider-specific Terraform variables
provider_generate_terraform_vars() {
    local vars_file="$1"
    # Generate provider-specific .auto.tfvars file
}

# Get provider-specific information
provider_get_info() {
    echo "Provider: [PROVIDER_NAME]"
    echo "Description: [PROVIDER_DESCRIPTION]"
    echo "Required variables: [LIST]"
}

# Provider-specific cleanup
provider_cleanup() {
    # Optional cleanup logic
}
```

## Implementation Plan

### Phase 1: Foundation - Rename and Restructure ✅ COMPLETED

#### 1.1 Rename Environment Files ✅ COMPLETED

```bash
# Completed: Renamed to avoid confusion
mv infrastructure/config/environments/local.defaults infrastructure/config/environments/development.defaults

# Completed: Updated references in scripts
sed -i 's/local\.env/development.env/g' infrastructure/scripts/*.sh
sed -i 's/ENVIRONMENT=local/ENVIRONMENT=development/g' infrastructure/scripts/*.sh
```

#### 1.2 Create Provider Interface ✅ COMPLETED

**Implemented `infrastructure/terraform/providers/libvirt/provider.sh`**:

Provider interface successfully implemented with:

- ✅ `provider_validate_prerequisites()` - LibVirt validation
- ✅ `provider_generate_terraform_vars()` - Auto-generates .tfvars
- ✅ `provider_get_info()` - Provider information display
- ✅ `provider_cleanup()` - Cleanup operations
- ✅ `provider_validate_ssh_key()` - SSH key auto-detection and validation

#### 1.3 Validation ✅ COMPLETED

```bash
# ✅ Completed: Test renamed environment
make infra-config ENVIRONMENT=development
make test-e2e ENVIRONMENT=development  # Passes in ~2m 35s
```

**✅ Expected outcome achieved**: Development environment works with new naming.

---

### Phase 2: Provider System Implementation ✅ COMPLETED

#### 2.1 Create LibVirt Provider Module ✅ COMPLETED

**✅ Implemented**: Moved existing logic to `infrastructure/terraform/providers/libvirt/`

**Current working `providers/libvirt/provider.sh`**:

```bash
#!/bin/bash
# LibVirt provider implementation - FULLY FUNCTIONAL

provider_validate_prerequisites() {
    log_info "Validating LibVirt prerequisites"

    if ! command -v virsh >/dev/null 2>&1; then
        log_error "virsh not found. Please install libvirt-clients."
        exit 1
    fi

    if ! virsh list >/dev/null 2>&1; then
        log_error "No libvirt access. Please add user to libvirt group."
        exit 1
    fi

    log_success "LibVirt prerequisites validated"
}

provider_validate_ssh_key() {
    log_info "Validating SSH key configuration"

    # SSH key auto-detection hierarchy
    local ssh_key_candidates=(
        "${HOME}/.ssh/torrust_rsa.pub"
        "${HOME}/.ssh/id_rsa.pub"
        "${HOME}/.ssh/id_ed25519.pub"
        "${HOME}/.ssh/id_ecdsa.pub"
    )

    # Check if SSH_PUBLIC_KEY is already set
    if [[ -n "${SSH_PUBLIC_KEY:-}" ]]; then
        log_info "Using explicitly set SSH_PUBLIC_KEY"
        return 0
    fi

    # Auto-detect SSH key
    for key_file in "${ssh_key_candidates[@]}"; do
        if [[ -f "${key_file}" ]]; then
            SSH_PUBLIC_KEY=$(cat "${key_file}")
            log_info "Found SSH public key: ${key_file}"
            log_success "SSH public key auto-detected from: ${key_file}"
            return 0
        fi
    done

    log_error "No SSH public key found in standard locations:"
    for key_file in "${ssh_key_candidates[@]}"; do
        log_error "  - ${key_file}"
    done
    log_error ""
    log_error "Please either:"
    log_error "  1. Generate an SSH key: ssh-keygen -t rsa -b 4096 -f ~/.ssh/torrust_rsa"
    log_error "  2. Set SSH_PUBLIC_KEY environment variable explicitly"
    exit 1
}

provider_generate_terraform_vars() {
    local vars_file="$1"

    # Validate SSH key before generating vars
    provider_validate_ssh_key

    cat > "${vars_file}" <<EOF
# Generated LibVirt provider variables
infrastructure_provider = "libvirt"

# Standard VM configuration
vm_name            = "${VM_NAME}"
vm_memory          = ${VM_MEMORY}
vm_vcpus           = ${VM_VCPUS}
vm_disk_size       = ${VM_DISK_SIZE}
ssh_public_key     = "${SSH_PUBLIC_KEY}"
use_minimal_config = ${USE_MINIMAL_CONFIG:-false}

# LibVirt-specific settings
libvirt_uri         = "${PROVIDER_LIBVIRT_URI:-qemu:///system}"
libvirt_pool        = "${PROVIDER_LIBVIRT_POOL:-user-default}"
libvirt_network     = "${PROVIDER_LIBVIRT_NETWORK:-default}"
base_image_url      = "${PROVIDER_LIBVIRT_BASE_IMAGE_URL:-https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img}"
EOF

    log_success "LibVirt Terraform variables generated: ${vars_file}"
}

provider_get_info() {
    echo "Provider: libvirt"
    echo "Description: Local KVM/libvirt virtualization"
    echo "Required tools: virsh, libvirt"
    echo "Required variables: None (SSH key auto-detected)"
    echo "Optional variables: PROVIDER_LIBVIRT_URI, PROVIDER_LIBVIRT_POOL, PROVIDER_LIBVIRT_NETWORK"
}

provider_cleanup() {
    log_info "LibVirt provider cleanup completed"
}
```

#### 2.2 Create Hetzner Provider Module ⏸️ PLANNED

**Status**: Template created in plan, implementation pending Phase 4.

#### 2.3 Update Core Scripts ✅ COMPLETED

**✅ Enhanced `provision-infrastructure.sh`** now includes:

- ✅ Provider interface loading and validation
- ✅ SSH key auto-detection integration
- ✅ Multi-provider Terraform variable generation
- ✅ Enhanced error handling and messaging
- ✅ Sudo cache management for better UX

#### 2.4 Validation ✅ COMPLETED

```bash
# ✅ Completed: Test provider system
make infra-apply ENVIRONMENT=development PROVIDER=libvirt   # ✅ WORKING
make infra-destroy ENVIRONMENT=development PROVIDER=libvirt # ✅ WORKING
make test-e2e                                              # ✅ PASSES (~2m 35s)
```

**✅ Expected outcome achieved**: Provider system works with pluggable interface.

---

### Phase 3: Enhanced Makefile and Commands ✅ COMPLETED

    # Load environment configuration
    load_environment
    load_provider_config

    # Load and validate provider
    load_provider "${PROVIDER}"

    # Provider-specific validation
    provider_validate_prerequisites

    # Generate provider-specific Terraform variables
    local vars_file="${TERRAFORM_DIR}/${PROVIDER}.auto.tfvars"
    provider_generate_terraform_vars "${vars_file}"

    # Continue with Terraform operations...
    cd "${TERRAFORM_DIR}"

    case "${ACTION}" in
        "init")
            tofu init
            ;;
        "plan")
            tofu plan
            ;;
        "apply")
            tofu apply -auto-approve
            ;;
        "destroy")
            tofu destroy -auto-approve
            ;;
        *)
            log_error "Unknown action: ${ACTION}"
            exit 1
            ;;
    esac

}

````

#### 2.4 Validation

```bash
# Test provider system
make infra-apply ENVIRONMENT=development PROVIDER=libvirt
make infra-destroy ENVIRONMENT=development PROVIDER=libvirt
````

**Expected outcome**: Provider system works with pluggable interface.

---

### Phase 3: Enhanced Makefile and Commands ✅ COMPLETED

**Status**: All enhanced commands implemented with parameter validation and provider discovery.

#### 3.1 Provider-Aware Makefile ✅ COMPLETED

**Current working commands**:

```makefile
# Working commands (basic provider support)
ENVIRONMENT ?= development
PROVIDER ?= libvirt

infra-apply: ## Apply infrastructure changes
    @echo "Applying infrastructure for $(ENVIRONMENT) on $(PROVIDER)..."
    infrastructure/scripts/provision-infrastructure.sh $(ENVIRONMENT) $(PROVIDER) apply

infra-destroy: ## Destroy infrastructure
    @echo "Destroying infrastructure for $(ENVIRONMENT) on $(PROVIDER)..."
    infrastructure/scripts/provision-infrastructure.sh $(ENVIRONMENT) $(PROVIDER) destroy
```

**⏸️ Planned enhancements**:

- Provider discovery commands (`make infra-providers`)
- Environment listing (`make infra-environments`)
- Provider information (`make provider-info PROVIDER=libvirt`)
- Parameter validation (`check-params` target)

#### 3.2 Enhanced Configuration Commands ⏸️ PLANNED

Provider interface helper commands for discovery and information.

#### 3.3 Validation ⏸️ PLANNED

```bash
# Planned testing for Phase 3
make infra-providers
make infra-environments
make provider-info PROVIDER=libvirt
```

---

### Phase 4: Hetzner Provider Implementation ⏸️ PLANNED

**Status**: Design completed, implementation pending.

#### 4.1 Hetzner Terraform Module ⏸️ PLANNED

Implementation of complete Hetzner Cloud provider module.

#### 4.2 Provider Configuration Templates ⏸️ PLANNED

Templates for Hetzner-specific configuration.

#### 4.3 Environment Templates ⏸️ PLANNED

Production environment templates for Hetzner deployment.

#### 4.4 Validation ⏸️ PLANNED

End-to-end testing with Hetzner Cloud infrastructure.

---

### Phase 5: Testing and Documentation ⏸️ PLANNED

**Status**: Comprehensive testing and documentation updates.

#### 5.1 Comprehensive Testing ⏸️ PLANNED

Cross-matrix testing of Environment x Provider combinations.

#### 5.2 Documentation Updates ⏸️ PLANNED

Updated guides, ADRs, and migration documentation.

#### 5.3 Future Provider Template ⏸️ PLANNED

Template and guide for adding new providers.

## Current Working State

### Functional Commands

```bash
# ✅ WORKING: Basic provider system
make infra-apply ENVIRONMENT=development PROVIDER=libvirt
make infra-destroy ENVIRONMENT=development PROVIDER=libvirt
make app-deploy ENVIRONMENT=development
make app-health-check ENVIRONMENT=development
make test-e2e  # Completes in ~2m 35s

# ✅ WORKING: SSH key auto-detection
# Automatically detects: ~/.ssh/torrust_rsa.pub, ~/.ssh/id_rsa.pub, etc.
```

### Test Results

- ✅ **E2E Tests**: Consistently passing in ~2m 35s
- ✅ **CI Tests**: All syntax validation and unit tests passing
- ✅ **SSH Security**: Auto-detection working, no hardcoded keys
- ✅ **Performance**: Infrastructure provisioning time stable and acceptable

### Next Immediate Steps

1. **Begin Phase 4**: Implement Hetzner provider for cloud deployment
2. **Phase 5 Planning**: Document all provider implementations and testing strategies
3. **Documentation**: Update all guides to reflect enhanced command interface

## Benefits of Current Implementation

#### 3.1 Provider-Aware Makefile

```makefile
# Default values
ENVIRONMENT ?= development
PROVIDER ?= libvirt

# Validate that environment and provider are specified
check-params:
    @if [ -z "$(ENVIRONMENT)" ]; then \
        echo "Error: ENVIRONMENT not specified"; \
        echo "Usage: make infra-apply ENVIRONMENT=<env> PROVIDER=<provider>"; \
        exit 1; \
    fi
    @if [ -z "$(PROVIDER)" ]; then \
        echo "Error: PROVIDER not specified"; \
        echo "Usage: make infra-apply ENVIRONMENT=<env> PROVIDER=<provider>"; \
        exit 1; \
    fi

# Provider and environment information
infra-providers: ## List available infrastructure providers
    @echo "Available Infrastructure Providers:"
    @$(SCRIPTS_DIR)/providers/provider-interface.sh list || echo "No providers found"
    @echo ""
    @echo "Usage examples:"
    @echo "  make infra-apply ENVIRONMENT=development PROVIDER=libvirt"
    @echo "  make infra-apply ENVIRONMENT=staging PROVIDER=digitalocean"
    @echo "  make infra-apply ENVIRONMENT=production PROVIDER=hetzner"

infra-environments: ## List available environments
    @echo "Available Environments:"
    @ls infrastructure/config/environments/*.env \
        infrastructure/config/environments/*.env.tpl 2>/dev/null | \
        xargs -I {} basename {} | sed 's/\.env.*//g' | sort | uniq || \
        echo "No environments found"
    @echo ""
    @echo "Environments:"
    @echo "  development - Local development and testing"
    @echo "  staging     - Pre-production testing"
    @echo "  production  - Production deployment"

# Configuration commands
infra-config: check-params ## Generate configuration for environment
    @echo "Configuring $(ENVIRONMENT) environment..."
    $(SCRIPTS_DIR)/configure-env.sh $(ENVIRONMENT)

provider-info: check-params ## Show provider information
    @echo "Getting information for provider: $(PROVIDER)"
    @$(SCRIPTS_DIR)/providers/provider-interface.sh info $(PROVIDER)

# Infrastructure commands (now require both ENVIRONMENT and PROVIDER)
infra-init: check-params ## Initialize infrastructure
    @echo "Initializing infrastructure for $(ENVIRONMENT) on $(PROVIDER)..."
    $(SCRIPTS_DIR)/provision-infrastructure.sh $(ENVIRONMENT) $(PROVIDER) init

infra-plan: check-params ## Plan infrastructure changes
    @echo "Planning infrastructure for $(ENVIRONMENT) on $(PROVIDER)..."
    $(SCRIPTS_DIR)/provision-infrastructure.sh $(ENVIRONMENT) $(PROVIDER) plan

infra-apply: check-params ## Apply infrastructure changes
    @echo "Applying infrastructure for $(ENVIRONMENT) on $(PROVIDER)..."
    $(SCRIPTS_DIR)/provision-infrastructure.sh $(ENVIRONMENT) $(PROVIDER) apply

infra-destroy: check-params ## Destroy infrastructure
    @echo "Destroying infrastructure for $(ENVIRONMENT) on $(PROVIDER)..."
    $(SCRIPTS_DIR)/provision-infrastructure.sh $(ENVIRONMENT) $(PROVIDER) destroy

infra-status: check-params ## Show infrastructure status
    @echo "Infrastructure status:"
    @echo "Environment: $(ENVIRONMENT)"
    @echo "Provider: $(PROVIDER)"
    @cd $(TERRAFORM_DIR) && tofu show -no-color | head -20 || \
        echo "No infrastructure found"
```

#### 3.2 Enhanced Configuration Commands

**New helper script `infrastructure/scripts/providers/provider-interface.sh`**:

```bash
#!/bin/bash
# Provider interface helper commands

case "${1:-}" in
    "list")
        list_available_providers
        ;;
    "info")
        if [[ -z "${2:-}" ]]; then
            echo "Usage: $0 info <provider>"
            exit 1
        fi
        load_provider "$2"
        provider_get_info
        ;;
    *)
        echo "Usage: $0 {list|info <provider>}"
        exit 1
        ;;
esac
```

#### 3.3 Validation

```bash
# Test new commands
make infra-providers
make infra-environments
make provider-info PROVIDER=libvirt
make provider-info PROVIDER=hetzner

# Test infrastructure workflow
make infra-apply ENVIRONMENT=development PROVIDER=libvirt
make infra-status ENVIRONMENT=development PROVIDER=libvirt
make infra-destroy ENVIRONMENT=development PROVIDER=libvirt
```

**Expected outcome**: Clean command interface with proper parameter validation.

---

### Phase 4: Hetzner Provider Implementation (Week 3)

#### 4.1 Hetzner Terraform Module

**`providers/hetzner/main.tf`** (same as previous plan)

#### 4.2 Provider Configuration Templates

**`infrastructure/config/providers/hetzner.env.tpl`**:

```bash
# Hetzner Cloud Provider Configuration Template
# Copy this file to hetzner.env and replace placeholder values

# === HETZNER CLOUD SETTINGS ===
PROVIDER_HETZNER_TOKEN=REPLACE_WITH_HETZNER_API_TOKEN
PROVIDER_HETZNER_SERVER_TYPE=cx31  # cx21, cx31, cx41, cx51
PROVIDER_HETZNER_LOCATION=nbg1     # nbg1, fsn1, hel1, ash
PROVIDER_HETZNER_IMAGE=ubuntu-24.04

# === VM DEFAULTS (can be overridden by environment) ===
VM_MEMORY_DEFAULT=4096
VM_VCPUS_DEFAULT=2
VM_DISK_SIZE_DEFAULT=40
```

#### 4.3 Environment Templates

**`infrastructure/config/environments/production.env.tpl`**:

```bash
# Production Environment Configuration Template
# Copy this file to production.env and replace placeholder values

ENVIRONMENT=production

# === VM CONFIGURATION ===
VM_NAME=torrust-tracker-prod
VM_MEMORY=${VM_MEMORY_DEFAULT:-8192}  # Use provider default or override
VM_VCPUS=${VM_VCPUS_DEFAULT:-4}
VM_DISK_SIZE=${VM_DISK_SIZE_DEFAULT:-50}

# === APPLICATION SECRETS ===
MYSQL_ROOT_PASSWORD=REPLACE_WITH_SECURE_ROOT_PASSWORD
MYSQL_PASSWORD=REPLACE_WITH_SECURE_PASSWORD
TRACKER_ADMIN_TOKEN=REPLACE_WITH_SECURE_ADMIN_TOKEN
GF_SECURITY_ADMIN_PASSWORD=REPLACE_WITH_SECURE_GRAFANA_PASSWORD

# === SSL CONFIGURATION ===
DOMAIN_NAME=REPLACE_WITH_YOUR_DOMAIN
CERTBOT_EMAIL=REPLACE_WITH_YOUR_EMAIL
ENABLE_SSL=true

# === OTHER SETTINGS ===
ENABLE_DB_BACKUPS=true
BACKUP_RETENTION_DAYS=7
USER_ID=1000
```

#### 4.4 Validation

```bash
# Generate Hetzner provider config
make infra-config ENVIRONMENT=production

# Edit with real values
vim infrastructure/config/providers/hetzner.env
vim infrastructure/config/environments/production.env

# Test Hetzner deployment
make infra-apply ENVIRONMENT=production PROVIDER=hetzner
make app-deploy ENVIRONMENT=production
make infra-destroy ENVIRONMENT=production PROVIDER=hetzner
```

**Expected outcome**: Working Hetzner provider with clean configuration.

---

### Phase 5: Testing and Documentation (Week 4)

#### 5.1 Comprehensive Testing

```bash
# Test matrix: Environment x Provider combinations
make infra-apply ENVIRONMENT=development PROVIDER=libvirt
make infra-apply ENVIRONMENT=staging PROVIDER=hetzner     # If configured
make infra-apply ENVIRONMENT=production PROVIDER=hetzner  # If configured

# Test provider discovery
make infra-providers
make infra-environments

# Test error handling
make infra-apply ENVIRONMENT=nonexistent PROVIDER=libvirt  # Should fail
make infra-apply ENVIRONMENT=development PROVIDER=nonexistent  # Should fail
```

#### 5.2 Documentation Updates

1. **Update guides** to use new ENVIRONMENT/PROVIDER pattern
2. **Create provider setup guides** for each provider
3. **Update ADRs** to document the design decisions
4. **Migration guide** for existing users

#### 5.3 Future Provider Template

Create a template for adding new providers:

**`docs/providers/provider-template.md`**:

````markdown
# Adding a New Provider

## 1. Create Provider Directory

```bash
mkdir -p infrastructure/terraform/providers/[PROVIDER_NAME]
```
````

## 2. Implement Required Files

- `main.tf` - Terraform resources
- `variables.tf` - Standard + provider-specific variables
- `outputs.tf` - Standard outputs (vm_ip, vm_name, connection_info)
- `provider.sh` - Provider interface implementation

## 3. Test Provider

```bash
make provider-info PROVIDER=[PROVIDER_NAME]
make infra-apply ENVIRONMENT=development PROVIDER=[PROVIDER_NAME]
```

No changes to core code required!

## Benefits of Current Implementation

### 1. **True Scalability**

- ✅ **Provider System**: Adding new providers requires zero changes to core code
- ✅ **Self-Contained**: Each provider is completely independent (libvirt implemented)
- ✅ **No Hardcoded Logic**: Pluggable interface eliminates switch statements

### 2. **Clear Separation**

- ✅ **Environment != Provider**: Can mix and match freely (`development` + `libvirt`)
- ✅ **Explicit Configuration**: All settings are discoverable and documented
- ✅ **No Naming Confusion**: Clear distinction between concepts

### 3. **Extensible Interface**

- ✅ **Standard Functions**: All providers implement same interface
- ✅ **SSH Key Security**: Auto-detection eliminates hardcoded credentials
- ✅ **Interface Validation**: Prevents broken implementations

### 4. **Clean Commands**

```bash
# ✅ WORKING: Clear, explicit commands
make infra-apply ENVIRONMENT=development PROVIDER=libvirt
make infra-destroy ENVIRONMENT=development PROVIDER=libvirt

# ⏸️ PLANNED: Discoverable help (Phase 3)
make infra-providers     # List available providers
make infra-environments  # List available environments
make provider-info PROVIDER=libvirt  # Get provider details
```

### 5. **Zero Breaking Changes**

- ✅ **Backward Compatibility**: Default values maintain existing workflows
- ✅ **Gradual Migration**: Existing workflows continue to work
- ✅ **Enhanced Security**: SSH key auto-detection improves security

## Implementation Summary

This design addresses all requirements:

- ✅ **No environment/provider confusion**: Clear separation implemented
- ✅ **No hardcoded switches**: Pluggable provider system working
- ✅ **Extensible architecture**: Easy to add unlimited providers
- ✅ **Clear separation of concerns**: Environment vs Provider distinction
- ✅ **SSH Security**: Auto-detection prevents hardcoded credentials
- ✅ **Performance**: E2E tests complete in ~2m 35s consistently

**Phase 2 is COMPLETE and production-ready** - the foundation is solid for continued development.
