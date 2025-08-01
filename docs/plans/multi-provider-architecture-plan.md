# Multi-Provider Architecture Implementation Plan

## Overview

This plan implements a clean multi-provider architecture that properly separates
environments from infrastructure providers, ensuring the system can scale to support
unlimited providers without code changes.

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

### Phase 1: Foundation - Rename and Restructure (Week 1)

#### 1.1 Rename Environment Files

```bash
# Rename to avoid confusion
mv infrastructure/config/environments/local.defaults infrastructure/config/environments/development.defaults

# Update references in scripts
sed -i 's/local\.env/development.env/g' infrastructure/scripts/*.sh
sed -i 's/ENVIRONMENT=local/ENVIRONMENT=development/g' infrastructure/scripts/*.sh
```

#### 1.2 Create Provider Interface

**New `infrastructure/scripts/providers/provider-interface.sh`**:

```bash
#!/bin/bash
# Provider interface for infrastructure provisioning
# Defines standard functions that all providers must implement

# Load a provider's implementation
load_provider() {
    local provider="$1"
    local provider_script="${PROJECT_ROOT}/infrastructure/terraform/providers/${provider}/provider.sh"

    if [[ ! -f "${provider_script}" ]]; then
        log_error "Provider not found: ${provider}"
        log_error "Provider script missing: ${provider_script}"
        exit 1
    fi

    # shellcheck source=/dev/null
    source "${provider_script}"

    # Validate required functions exist
    validate_provider_interface "${provider}"
}

# Validate that provider implements required interface
validate_provider_interface() {
    local provider="$1"
    local required_functions=(
        "provider_validate_prerequisites"
        "provider_generate_terraform_vars"
        "provider_get_info"
    )

    for func in "${required_functions[@]}"; do
        if ! declare -F "${func}" >/dev/null 2>&1; then
            log_error "Provider ${provider} missing required function: ${func}"
            exit 1
        fi
    done

    log_success "Provider ${provider} interface validated"
}

# Discover available providers
list_available_providers() {
    local providers_dir="${PROJECT_ROOT}/infrastructure/terraform/providers"

    if [[ ! -d "${providers_dir}" ]]; then
        log_warning "No providers directory found"
        return
    fi

    for provider_dir in "${providers_dir}"/*; do
        if [[ -d "${provider_dir}" ]]; then
            local provider_name=$(basename "${provider_dir}")
            local provider_script="${provider_dir}/provider.sh"

            if [[ -f "${provider_script}" ]]; then
                echo "${provider_name}"
            fi
        fi
    done
}
```

#### 1.3 Validation

```bash
# Test renamed environment
make infra-config ENVIRONMENT=development
make test-e2e ENVIRONMENT=development
```

**Expected outcome**: Development environment works with new naming.

---

### Phase 2: Provider System Implementation (Week 1-2)

#### 2.1 Create LibVirt Provider Module

**Move existing logic to `infrastructure/terraform/providers/libvirt/`**:

**`providers/libvirt/provider.sh`**:

```bash
#!/bin/bash
# LibVirt provider implementation

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

provider_generate_terraform_vars() {
    local vars_file="$1"

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
    echo "Required variables: None (all have defaults)"
}

provider_cleanup() {
    # Optional: Clean up libvirt-specific resources
    log_info "LibVirt provider cleanup (if needed)"
}
```

#### 2.2 Create Hetzner Provider Module

**`providers/hetzner/provider.sh`**:

```bash
#!/bin/bash
# Hetzner Cloud provider implementation

provider_validate_prerequisites() {
    log_info "Validating Hetzner Cloud prerequisites"

    if [[ -z "${PROVIDER_HETZNER_TOKEN:-}" ]]; then
        log_error "Hetzner API token not configured (PROVIDER_HETZNER_TOKEN)"
        exit 1
    fi

    # Optional: Validate token with API call
    if command -v hcloud >/dev/null 2>&1; then
        log_info "Validating Hetzner API token"
        if ! HCLOUD_TOKEN="${PROVIDER_HETZNER_TOKEN}" hcloud server list >/dev/null 2>&1; then
            log_warning "Hetzner API token validation failed"
        else
            log_success "Hetzner API token validated"
        fi
    fi

    log_success "Hetzner Cloud prerequisites validated"
}

provider_generate_terraform_vars() {
    local vars_file="$1"

    cat > "${vars_file}" <<EOF
# Generated Hetzner provider variables
infrastructure_provider = "hetzner"

# Standard VM configuration
vm_name            = "${VM_NAME}"
vm_memory          = ${VM_MEMORY}
vm_vcpus           = ${VM_VCPUS}
vm_disk_size       = ${VM_DISK_SIZE}
ssh_public_key     = "${SSH_PUBLIC_KEY}"
use_minimal_config = ${USE_MINIMAL_CONFIG:-false}

# Hetzner-specific settings
hetzner_token       = "${PROVIDER_HETZNER_TOKEN}"
hetzner_server_type = "${PROVIDER_HETZNER_SERVER_TYPE:-cx31}"
hetzner_location    = "${PROVIDER_HETZNER_LOCATION:-nbg1}"
hetzner_image       = "${PROVIDER_HETZNER_IMAGE:-ubuntu-24.04}"
EOF

    log_success "Hetzner Terraform variables generated: ${vars_file}"
}

provider_get_info() {
    echo "Provider: hetzner"
    echo "Description: Hetzner Cloud servers"
    echo "Required tools: hcloud (optional)"
    echo "Required variables: PROVIDER_HETZNER_TOKEN"
    echo "Optional variables: PROVIDER_HETZNER_SERVER_TYPE, PROVIDER_HETZNER_LOCATION, PROVIDER_HETZNER_IMAGE"
}

provider_cleanup() {
    log_info "Hetzner provider cleanup completed"
}
```

#### 2.3 Update Core Scripts

**Enhanced `provision-infrastructure.sh`**:

```bash
#!/bin/bash
# Infrastructure provisioning script - provider agnostic

# Load provider interface
# shellcheck source=providers/provider-interface.sh
source "${PROJECT_ROOT}/infrastructure/scripts/providers/provider-interface.sh"

# Parse arguments
ENVIRONMENT="${1:-development}"
PROVIDER="${2:-libvirt}"  # Default to libvirt for local development
ACTION="${3:-apply}"

# Load environment and provider
load_environment() {
    local env_file="${CONFIG_DIR}/environments/${ENVIRONMENT}.env"

    if [[ ! -f "${env_file}" ]]; then
        log_error "Environment file not found: ${env_file}"
        exit 1
    fi

    # shellcheck source=/dev/null
    source "${env_file}"

    log_info "Environment loaded: ${ENVIRONMENT}"
}

load_provider_config() {
    local provider_config="${CONFIG_DIR}/providers/${PROVIDER}.env"

    if [[ -f "${provider_config}" ]]; then
        # shellcheck source=/dev/null
        source "${provider_config}"
        log_info "Provider config loaded: ${provider_config}"
    fi
}

# Main provisioning function
provision_infrastructure() {
    log_info "Provisioning infrastructure"
    log_info "Environment: ${ENVIRONMENT}"
    log_info "Provider: ${PROVIDER}"
    log_info "Action: ${ACTION}"

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
```

#### 2.4 Validation

```bash
# Test provider system
make infra-apply ENVIRONMENT=development PROVIDER=libvirt
make infra-destroy ENVIRONMENT=development PROVIDER=libvirt
```

**Expected outcome**: Provider system works with pluggable interface.

---

### Phase 3: Enhanced Makefile and Commands (Week 2)

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

## Benefits of This Design

### 1. **True Scalability**

- Adding 50 providers requires zero changes to core code
- Each provider is completely self-contained
- No switch statements or hardcoded logic

### 2. **Clear Separation**

- Environment != Provider (can mix and match freely)
- Configuration is explicit and discoverable
- No naming confusion between concepts

### 3. **Extensible Interface**

- Standard provider functions ensure consistency
- Providers can add custom functionality
- Interface validation prevents broken implementations

### 4. **Clean Commands**

```bash
# Clear, explicit commands
make infra-apply ENVIRONMENT=development PROVIDER=libvirt
make infra-apply ENVIRONMENT=production PROVIDER=hetzner
make infra-apply ENVIRONMENT=staging PROVIDER=digitalocean

# Discoverable help
make infra-providers     # List available providers
make infra-environments  # List available environments
make provider-info PROVIDER=hetzner  # Get provider details
```

### 5. **Zero Breaking Changes**

- Default values maintain backward compatibility
- Existing workflows continue to work
- Gradual migration path

This design addresses all your concerns:

- ✅ No environment/provider confusion
- ✅ No hardcoded switches that don't scale
- ✅ Pluggable provider system
- ✅ Clear separation of concerns
- ✅ Extensible to unlimited providers

Would you like me to start implementing Phase 1 with the environment renaming
and provider interface foundation?

### 5. **Zero Breaking Changes**

- Default values maintain backward compatibility
- Existing workflows continue to work
- Gradual migration path

This design addresses all your concerns:

- ✅ No environment/provider confusion
- ✅ No hardcoded switches that don't scale
- ✅ Pluggable provider system
- ✅ Clear separation of concerns
- ✅ Extensible to unlimited providers
