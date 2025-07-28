# Multi-Provider Abstraction Plan

## 📋 Overview

This document outlines the architectural changes needed to support multiple cloud providers
in the Torrust Tracker Demo repository while maintaining twelve-factor methodology compliance.
Currently, the infrastructure is tightly coupled to the local libvirt provider, making it
difficult to add new providers like Hetzner.

## 🎯 Objectives

- **Easy Provider Addition**: New cloud providers can be added with minimal changes
- **Twelve-Factor Compliance**: Maintain clear separation of configuration and infrastructure
- **Backward Compatibility**: Existing local workflow remains unchanged
- **Standardized Interface**: Same commands work across all providers
- **Provider Isolation**: Provider-specific logic contained in dedicated modules

## 📊 Current State Analysis

### Current Limitations

1. **Hardcoded Provider**: Terraform configuration in `main.tf` is libvirt-specific
2. **Mixed Validation Logic**: Provider-specific prerequisites mixed with generic logic
3. **Single Configuration Path**: No provider-specific configuration structure
4. **Shared Resources**: No provider-specific resource definitions or modules

### Current Architecture Issues

```text
infrastructure/terraform/main.tf
├── Hardcoded libvirt provider configuration
├── Libvirt-specific resources (volumes, domains, networks)
├── Mixed provider-specific and generic variables
└── No abstraction for other cloud providers
```

### Supported Providers

- ✅ **Local**: KVM/libvirt for local testing (current implementation)
- 🚧 **Hetzner**: Hetzner Cloud for production (planned)
- 🔮 **Future**: AWS, GCP, Azure, DigitalOcean (potential)

## 🏗️ Proposed Architecture

### Target Directory Structure

```text
infrastructure/
├── terraform/
│   ├── providers/              # NEW: Provider-specific modules
│   │   ├── local/             # Libvirt provider (existing logic)
│   │   │   ├── main.tf        # Libvirt resources
│   │   │   ├── variables.tf   # Provider-specific variables
│   │   │   ├── outputs.tf     # Standardized outputs
│   │   │   └── versions.tf    # Provider requirements
│   │   ├── hetzner/           # NEW: Hetzner provider
│   │   │   ├── main.tf        # Hetzner Cloud resources
│   │   │   ├── variables.tf   # Provider-specific variables
│   │   │   ├── outputs.tf     # Standardized outputs
│   │   │   └── versions.tf    # Provider requirements
│   │   └── [future providers]/
│   ├── main.tf                # NEW: Provider-agnostic orchestration
│   ├── variables.tf           # NEW: Common variables
│   ├── outputs.tf             # NEW: Standardized outputs
│   └── local.tfvars           # Existing local config
├── config/
│   ├── environments/
│   │   ├── local.env          # Enhanced with infrastructure provider
│   │   ├── production.env.tpl # Enhanced with infrastructure provider
│   │   └── hetzner.env.tpl    # NEW: Hetzner-specific environment
│   └── templates/
│       ├── terraform/         # NEW: Provider-specific templates
│       │   ├── local.tf.tpl
│       │   └── hetzner.tf.tpl
│       └── cloud-init/        # Provider-specific cloud-init
│           ├── local/
│           └── hetzner/
```

### Provider Abstraction Layer

The new architecture introduces a clear separation between:

1. **Provider-Agnostic Orchestration**: Main Terraform configuration that selects the
   appropriate provider module
2. **Provider-Specific Modules**: Self-contained modules for each cloud provider
3. **Standardized Interfaces**: Common variables and outputs across all providers
4. **Enhanced Configuration**: Environment-based provider selection and settings

## 📋 Detailed Implementation Plan

### Phase 1: Provider Module Structure

#### 1.1 Create Provider Directory Structure

```bash
# Create provider module directories
mkdir -p infrastructure/terraform/providers/local
mkdir -p infrastructure/terraform/providers/hetzner

# Create provider-specific files
touch infrastructure/terraform/providers/local/{main.tf,variables.tf,outputs.tf,versions.tf}
touch infrastructure/terraform/providers/hetzner/{main.tf,variables.tf,outputs.tf,versions.tf}
```

#### 1.2 Move Local Provider Logic

**Current `main.tf` → `providers/local/main.tf`**:

```hcl
# Move all existing libvirt resources to local provider module
terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7"
    }
  }
}

provider "libvirt" {
  uri = var.libvirt_uri
}

# All existing libvirt resources (volumes, domains, cloud-init)...
```

#### 1.3 Create Provider-Agnostic Orchestration

**New `main.tf`**:

```hcl
terraform {
  required_version = ">= 1.0"
}

# Conditional module inclusion based on provider
module "local_infrastructure" {
  count  = var.infrastructure_provider == "local" ? 1 : 0
  source = "./providers/local"

  # Standardized variables
  vm_name            = var.vm_name
  vm_memory          = var.vm_memory
  vm_vcpus           = var.vm_vcpus
  vm_disk_size       = var.vm_disk_size
  ssh_public_key     = var.ssh_public_key
  use_minimal_config = var.use_minimal_config

  # Provider-specific variables
  libvirt_uri    = var.libvirt_uri
  libvirt_pool   = var.libvirt_pool
  libvirt_network = var.libvirt_network
}

module "hetzner_infrastructure" {
  count  = var.infrastructure_provider == "hetzner" ? 1 : 0
  source = "./providers/hetzner"

  # Standardized variables
  vm_name        = var.vm_name
  vm_memory      = var.vm_memory
  vm_vcpus       = var.vm_vcpus
  vm_disk_size   = var.vm_disk_size
  ssh_public_key = var.ssh_public_key

  # Provider-specific variables
  hetzner_token      = var.hetzner_token
  hetzner_server_type = var.hetzner_server_type
  hetzner_location   = var.hetzner_location
  hetzner_image      = var.hetzner_image
}

# Standardized outputs (regardless of provider)
output "vm_ip" {
  value = var.infrastructure_provider == "local" ?
    (length(module.local_infrastructure) > 0 ? 
     module.local_infrastructure[0].vm_ip : "No IP assigned yet") :
    (length(module.hetzner_infrastructure) > 0 ? 
     module.hetzner_infrastructure[0].vm_ip : "No IP assigned yet")
  description = "IP address of the created VM"
}

output "vm_name" {
  value = var.infrastructure_provider == "local" ?
    (length(module.local_infrastructure) > 0 ? module.local_infrastructure[0].vm_name : "") :
    (length(module.hetzner_infrastructure) > 0 ? module.hetzner_infrastructure[0].vm_name : "")
  description = "Name of the created VM"
}

output "connection_info" {
  value = var.infrastructure_provider == "local" ?
    (length(module.local_infrastructure) > 0 ? 
     module.local_infrastructure[0].connection_info : "VM not created") :
    (length(module.hetzner_infrastructure) > 0 ? 
     module.hetzner_infrastructure[0].connection_info : "VM not created")
  description = "SSH connection command"
}
```

### Phase 2: Enhanced Environment Configuration

#### 2.1 Add Infrastructure Provider Settings

**Enhanced `local.env`**:

```bash
# Infrastructure Provider Configuration
ENVIRONMENT=local
INFRASTRUCTURE_PROVIDER=local

# Provider-specific settings
PROVIDER_LOCAL_LIBVIRT_URI=qemu:///system
PROVIDER_LOCAL_POOL=user-default
PROVIDER_LOCAL_NETWORK=default

# VM Configuration (provider-agnostic)
VM_NAME=torrust-tracker-demo
VM_MEMORY=2048
VM_VCPUS=2
VM_DISK_SIZE=20

# Existing application configuration...
MYSQL_ROOT_PASSWORD=root_secret_local
MYSQL_DATABASE=torrust_tracker
MYSQL_USER=torrust
MYSQL_PASSWORD=tracker_secret_local
TRACKER_ADMIN_TOKEN=MyAccessToken
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=admin_secret_local
USER_ID=1000
```

#### 2.2 Create Hetzner Environment Template

**New `hetzner.env.tpl`**:

```bash
# Hetzner Cloud Environment Configuration Template
# Copy this file to hetzner.env and replace placeholder values

ENVIRONMENT=production
INFRASTRUCTURE_PROVIDER=hetzner

# Hetzner-specific settings
PROVIDER_HETZNER_TOKEN=REPLACE_WITH_HETZNER_API_TOKEN
PROVIDER_HETZNER_SERVER_TYPE=cx31
PROVIDER_HETZNER_LOCATION=nbg1
PROVIDER_HETZNER_IMAGE=ubuntu-24.04
PROVIDER_HETZNER_SSH_KEY_NAME=torrust-demo-key

# VM Configuration (provider-agnostic)
VM_NAME=torrust-tracker-prod
VM_MEMORY=8192  # Larger for production
VM_VCPUS=4
VM_DISK_SIZE=40

# Application configuration (same structure as other environments)
MYSQL_ROOT_PASSWORD=REPLACE_WITH_SECURE_ROOT_PASSWORD
MYSQL_DATABASE=torrust_tracker
MYSQL_USER=torrust
MYSQL_PASSWORD=REPLACE_WITH_SECURE_PASSWORD
TRACKER_ADMIN_TOKEN=REPLACE_WITH_SECURE_ADMIN_TOKEN
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=REPLACE_WITH_SECURE_GRAFANA_PASSWORD
USER_ID=1000
```

### Phase 3: Enhanced Scripts with Provider Logic

#### 3.1 Provider-Aware Infrastructure Provisioning

**Enhanced `provision-infrastructure.sh`**:

```bash
# Extract infrastructure provider from environment
get_infrastructure_provider() {
    if [[ -f "${CONFIG_DIR}/environments/${ENVIRONMENT}.env" ]]; then
        INFRASTRUCTURE_PROVIDER=$(grep "INFRASTRUCTURE_PROVIDER=" \
            "${CONFIG_DIR}/environments/${ENVIRONMENT}.env" | cut -d'=' -f2)
    fi

    if [[ -z "${INFRASTRUCTURE_PROVIDER}" ]]; then
        log_error "INFRASTRUCTURE_PROVIDER not specified in environment: ${ENVIRONMENT}"
        exit 1
    fi

    log_info "Infrastructure provider: ${INFRASTRUCTURE_PROVIDER}"
}

# Provider-specific validation
validate_provider_prerequisites() {
    case "${INFRASTRUCTURE_PROVIDER}" in
        "local")
            validate_libvirt_prerequisites
            ;;
        "hetzner")
            validate_hetzner_prerequisites
            ;;
        *)
            log_error "Unknown infrastructure provider: ${INFRASTRUCTURE_PROVIDER}"
            log_error "Supported providers: local, hetzner"
            exit 1
            ;;
    esac
}

validate_libvirt_prerequisites() {
    log_info "Validating libvirt prerequisites"

    if ! command -v virsh >/dev/null 2>&1; then
        log_error "virsh not found. Please install libvirt-clients."
        exit 1
    fi

    if ! virsh list >/dev/null 2>&1; then
        log_error "No libvirt access. Please add user to libvirt group and restart session."
        exit 1
    fi

    log_success "Libvirt prerequisites validated"
}

validate_hetzner_prerequisites() {
    log_info "Validating Hetzner Cloud prerequisites"

    if [[ -z "${PROVIDER_HETZNER_TOKEN:-}" ]]; then
        log_error "Hetzner API token not configured (PROVIDER_HETZNER_TOKEN)"
        exit 1
    fi

    # Optionally check hcloud CLI
    if command -v hcloud >/dev/null 2>&1; then
        log_info "Hetzner CLI (hcloud) found - validating token"
        if ! hcloud server list >/dev/null 2>&1; then
            log_warning "Hetzner API token validation failed"
        fi
    fi

    log_success "Hetzner Cloud prerequisites validated"
}

# Provider-specific Terraform variable file generation
generate_terraform_vars() {
    local vars_file="${TERRAFORM_DIR}/${INFRASTRUCTURE_PROVIDER}.auto.tfvars"

    log_info "Generating Terraform variables for provider: ${INFRASTRUCTURE_PROVIDER}"

    case "${INFRASTRUCTURE_PROVIDER}" in
        "local")
            generate_local_terraform_vars "${vars_file}"
            ;;
        "hetzner")
            generate_hetzner_terraform_vars "${vars_file}"
            ;;
    esac

    TERRAFORM_VARS_FILE="${vars_file}"
    log_success "Terraform variables generated: ${TERRAFORM_VARS_FILE}"
}

generate_local_terraform_vars() {
    local vars_file="$1"

    cat > "${vars_file}" <<EOF
# Generated local provider variables
infrastructure_provider = "local"

# VM configuration
vm_name            = "${VM_NAME}"
vm_memory          = ${VM_MEMORY}
vm_vcpus           = ${VM_VCPUS}
vm_disk_size       = ${VM_DISK_SIZE}
ssh_public_key     = "${SSH_PUBLIC_KEY}"
use_minimal_config = false

# Local provider settings
libvirt_uri     = "${PROVIDER_LOCAL_LIBVIRT_URI}"
libvirt_pool    = "${PROVIDER_LOCAL_POOL}"
libvirt_network = "${PROVIDER_LOCAL_NETWORK}"
EOF
}

generate_hetzner_terraform_vars() {
    local vars_file="$1"

    cat > "${vars_file}" <<EOF
# Generated Hetzner provider variables
infrastructure_provider = "hetzner"

# VM configuration
vm_name        = "${VM_NAME}"
vm_memory      = ${VM_MEMORY}
vm_vcpus       = ${VM_VCPUS}
vm_disk_size   = ${VM_DISK_SIZE}
ssh_public_key = "${SSH_PUBLIC_KEY}"

# Hetzner provider settings
hetzner_token       = "${PROVIDER_HETZNER_TOKEN}"
hetzner_server_type = "${PROVIDER_HETZNER_SERVER_TYPE}"
hetzner_location    = "${PROVIDER_HETZNER_LOCATION}"
hetzner_image       = "${PROVIDER_HETZNER_IMAGE}"
EOF
}
```

#### 3.2 Enhanced Configuration Processing

**Enhanced `configure-env.sh`**:

```bash
# Enhanced environment loading with provider extraction
load_environment() {
    local env_file="${CONFIG_DIR}/environments/${ENVIRONMENT}.env"

    # Handle template-based environments (production, hetzner)
    case "${ENVIRONMENT}" in
        "production")
            setup_production_environment
            ;;
        "hetzner")
            setup_hetzner_environment
            ;;
        "local")
            setup_local_environment
            ;;
        *)
            log_warning "Unknown environment: ${ENVIRONMENT}, treating as custom"
            ;;
    esac

    if [[ ! -f "${env_file}" ]]; then
        log_error "Environment file not found: ${env_file}"
        exit 1
    fi

    log_info "Loading environment: ${ENVIRONMENT}"

    # Export variables for template processing
    set -a
    source "${env_file}"
    set +a

    # Validate infrastructure provider
    if [[ -z "${INFRASTRUCTURE_PROVIDER:-}" ]]; then
        log_error "INFRASTRUCTURE_PROVIDER not specified in ${env_file}"
        exit 1
    fi

    log_info "Infrastructure provider: ${INFRASTRUCTURE_PROVIDER}"
}

setup_hetzner_environment() {
    local env_file="${CONFIG_DIR}/environments/hetzner.env"
    local template_file="${CONFIG_DIR}/environments/hetzner.env.tpl"

    if [[ ! -f "${env_file}" ]]; then
        if [[ ! -f "${template_file}" ]]; then
            log_error "Hetzner template not found: ${template_file}"
            exit 1
        fi

        log_info "Creating hetzner.env from template..."
        cp "${template_file}" "${env_file}"
        log_warning "Hetzner environment file created from template: ${env_file}"
        log_warning "IMPORTANT: You must edit this file and replace placeholder values!"
        log_error "Aborting: Please configure Hetzner settings first"
        exit 1
    fi

    # Validate Hetzner-specific placeholders
    if grep -q "REPLACE_WITH_HETZNER" "${env_file}"; then
        log_error "Hetzner environment contains placeholder values!"
        log_error "Please edit ${env_file} and replace all placeholder values"
        exit 1
    fi
}

# Provider-specific template processing
process_provider_templates() {
    local provider_template_dir="${CONFIG_DIR}/templates/terraform"
    local provider_template="${provider_template_dir}/${INFRASTRUCTURE_PROVIDER}.tf.tpl"

    if [[ -f "${provider_template}" ]]; then
        log_info "Processing provider-specific Terraform template"
        local output_file="${PROJECT_ROOT}/infrastructure/terraform/generated-${INFRASTRUCTURE_PROVIDER}.tf"
        envsubst < "${provider_template}" > "${output_file}"
        log_success "Generated provider configuration: ${output_file}"
    fi
}
```

### Phase 4: Hetzner Provider Implementation

#### 4.1 Hetzner Provider Module

**`providers/hetzner/main.tf`**:

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
  token = var.hetzner_token
}

# SSH Key resource
resource "hcloud_ssh_key" "torrust_key" {
  name       = "${var.vm_name}-key"
  public_key = var.ssh_public_key
}

# Server instance
resource "hcloud_server" "vm" {
  name        = var.vm_name
  server_type = var.hetzner_server_type
  location    = var.hetzner_location
  image       = var.hetzner_image

  ssh_keys = [hcloud_ssh_key.torrust_key.id]

  user_data = templatefile(
    "${path.module}/../../cloud-init/${var.use_minimal_config ? 
    "user-data-minimal.yaml.tpl" : "user-data.yaml.tpl"}", {
    ssh_public_key = var.ssh_public_key
  })

  # Basic firewall rules
  firewall_ids = [hcloud_firewall.torrust_firewall.id]
}

# Firewall configuration
resource "hcloud_firewall" "torrust_firewall" {
  name = "${var.vm_name}-firewall"

  rule {
    direction = "in"
    port      = "22"
    protocol  = "tcp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    port      = "80"
    protocol  = "tcp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    port      = "443"
    protocol  = "tcp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # Torrust Tracker UDP ports
  rule {
    direction = "in"
    port      = "6868"
    protocol  = "udp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    port      = "6969"
    protocol  = "udp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}
```

**`providers/hetzner/variables.tf`**:

```hcl
# Standardized variables (common across all providers)
variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
}

variable "vm_memory" {
  description = "Memory allocation for VM in MB"
  type        = number
}

variable "vm_vcpus" {
  description = "Number of vCPUs for the VM"
  type        = number
}

variable "vm_disk_size" {
  description = "Disk size in GB"
  type        = number
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "use_minimal_config" {
  description = "Use minimal cloud-init configuration for debugging"
  type        = bool
  default     = false
}

# Hetzner-specific variables
variable "hetzner_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "hetzner_server_type" {
  description = "Hetzner server type (e.g., cx31, cx41)"
  type        = string
  default     = "cx31"
}

variable "hetzner_location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "nbg1"
}

variable "hetzner_image" {
  description = "Hetzner server image"
  type        = string
  default     = "ubuntu-24.04"
}
```

**`providers/hetzner/outputs.tf`**:

```hcl
# Standardized outputs (must match local provider interface)
output "vm_ip" {
  value       = hcloud_server.vm.ipv4_address
  description = "IP address of the created VM"
}

output "vm_name" {
  value       = hcloud_server.vm.name
  description = "Name of the created VM"
}

output "connection_info" {
  value       = "SSH to VM: ssh torrust@${hcloud_server.vm.ipv4_address}"
  description = "SSH connection command"
}

# Provider-specific outputs
output "hetzner_server_id" {
  value       = hcloud_server.vm.id
  description = "Hetzner server ID"
}

output "hetzner_datacenter" {
  value       = hcloud_server.vm.datacenter
  description = "Hetzner datacenter information"
}
```

### Phase 5: Enhanced Makefile Commands

#### 5.1 New Provider-Aware Commands

```makefile
# Enhanced commands that work with any provider
infra-apply: ## Provision infrastructure (works with any provider)
    @echo "Provisioning infrastructure for $(ENVIRONMENT)..."
    @echo "⚠️  This command may prompt for your password for provider-specific operations"
    $(SCRIPTS_DIR)/provision-infrastructure.sh $(ENVIRONMENT) apply

# Provider-specific configuration commands
infra-config-hetzner: ## Generate Hetzner environment configuration
    @echo "Configuring Hetzner environment..."
    $(SCRIPTS_DIR)/configure-env.sh hetzner

# Provider validation
infra-test-prereq: ## Test system prerequisites for environment
    @echo "Testing prerequisites for $(ENVIRONMENT)..."
    $(INFRA_TESTS_DIR)/test-unit-infrastructure.sh prerequisites $(ENVIRONMENT)

# Provider-specific help
infra-providers: ## Show supported infrastructure providers
    @echo "Supported Infrastructure Providers:"
    @echo "  local    - KVM/libvirt for local testing"
    @echo "  hetzner  - Hetzner Cloud for production"
    @echo ""
    @echo "Usage:"
    @echo "  make infra-apply ENVIRONMENT=local    # Local testing"
    @echo "  make infra-apply ENVIRONMENT=hetzner  # Hetzner production"
```

## 🚀 Benefits After Implementation

### For Developers

1. **🔧 Easy Provider Addition**: New providers require only:

   - Adding a provider module in `providers/[name]/`
   - Creating environment template `[name].env.tpl`
   - Adding validation logic to scripts

2. **🏗️ Twelve-Factor Compliance**:

   - Configuration externalized via environment variables
   - Infrastructure and application concerns clearly separated
   - Provider selection via environment configuration

3. **🔄 Backward Compatibility**:
   - Existing `make infra-apply ENVIRONMENT=local` commands unchanged
   - Local testing workflow unaffected
   - Gradual migration path for users

### For Operations

1. **📋 Standardized Interface**: Same commands work across all providers
2. **🎯 Provider Isolation**: Provider failures don't affect other providers
3. **⚡ Flexible Configuration**: Easy switching between providers
4. **🔍 Clear Validation**: Provider-specific prerequisite checking

### Example Usage After Implementation

```bash
# Local development (unchanged)
make infra-apply ENVIRONMENT=local

# Hetzner production (new)
make infra-config-hetzner  # Generate hetzner.env from template
# Edit hetzner.env with actual secrets
make infra-apply ENVIRONMENT=hetzner

# Future AWS support (potential)
make infra-config-aws
make infra-apply ENVIRONMENT=aws
```

## 📅 Implementation Timeline

### Week 1: Foundation

- [ ] Create provider module directory structure
- [ ] Move local provider logic to module
- [ ] Create provider-agnostic orchestration layer
- [ ] Test backward compatibility with local environment

### Week 2: Configuration Enhancement

- [ ] Enhance environment files with provider settings
- [ ] Create Hetzner environment template
- [ ] Update configuration processing scripts
- [ ] Test configuration generation

### Week 3: Script Enhancement

- [ ] Add provider-aware validation logic
- [ ] Implement Terraform variable generation
- [ ] Update infrastructure provisioning script
- [ ] Test provider switching

### Week 4: Hetzner Implementation

- [ ] Implement Hetzner provider module
- [ ] Add Hetzner-specific validation
- [ ] Test Hetzner deployment workflow
- [ ] Validate provider abstraction

### Week 5: Testing & Documentation

- [ ] Comprehensive testing of both providers
- [ ] Update documentation and guides
- [ ] Create migration guide for existing users
- [ ] Performance and security validation

## 🔒 Security Considerations

### Secret Management

1. **Provider Tokens**: API tokens stored in environment files (gitignored)
2. **SSH Keys**: Managed per provider (local files vs cloud key management)
3. **Terraform State**: Provider-specific state isolation
4. **Access Control**: Provider-specific access validation

### Network Security

1. **Firewall Rules**: Provider-specific firewall configuration
2. **Network Isolation**: Provider-specific network setup
3. **Access Patterns**: Provider-appropriate security groups/rules

## 🧪 Testing Strategy

### Unit Testing

- [ ] Provider module validation
- [ ] Configuration template processing
- [ ] Script provider detection logic

### Integration Testing

- [ ] Local provider deployment (existing)
- [ ] Hetzner provider deployment (new)
- [ ] Provider switching workflow
- [ ] Cross-provider compatibility

### End-to-End Testing

- [ ] Complete deployment workflow per provider
- [ ] Application deployment on each provider
- [ ] Health validation across providers

## 📚 Related Documentation

- [Twelve-Factor App Refactoring](../twelve-factor-refactor/README.md)
- [Hetzner Migration Plan](../../../docs/plans/hetzner-migration-plan.md)
- [Infrastructure Overview](../infrastructure-overview.md)
- [Local Testing Setup](../local-testing-setup.md)

## 🎯 Success Criteria

- [ ] Multiple providers supported with same command interface
- [ ] Existing local workflow unchanged and unaffected
- [ ] Hetzner provider fully functional with production deployment
- [ ] Provider abstraction allows easy addition of future providers
- [ ] Twelve-factor methodology compliance maintained
- [ ] Comprehensive documentation and testing coverage
- [ ] Migration path clearly documented for existing users

---

**Status**: 📋 **Planning Phase** - Ready for implementation when development capacity available

**Priority**: 🚀 **High** - Critical for Hetzner migration and future cloud provider support

**Effort**: 📊 **Medium** - ~3-4 weeks development + 1 week testing

**Dependencies**: Twelve-factor refactoring completion (✅ Complete)
