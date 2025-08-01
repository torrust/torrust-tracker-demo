#!/bin/bash
# Hetzner Cloud provider implementation
# Implements the standard provider interface for Hetzner Cloud

# Source shell utilities
PROVIDER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${PROVIDER_DIR}/../../../.." && pwd)"
source "${PROJECT_ROOT}/scripts/shell-utils.sh"

# Provider-specific validation
provider_validate_prerequisites() {
    log_info "Validating Hetzner Cloud prerequisites"

    # Check if hcloud CLI is available (optional but helpful)
    if command -v hcloud >/dev/null 2>&1; then
        log_info "Hetzner CLI detected"
    else
        log_warning "Hetzner CLI not found. Install with: go install github.com/hetznercloud/cli/cmd/hcloud@latest"
        log_info "Note: CLI is optional, Terraform provider will work without it"
    fi

    # Validate required environment variables
    if [[ -z "${HETZNER_TOKEN:-}" ]]; then
        log_error "HETZNER_TOKEN environment variable is required"
        log_error "Get your token from: https://console.hetzner.cloud/"
        log_error "Set it with: export HETZNER_TOKEN=your_token_here"
        exit 1
    fi

    # Validate token format (should be 64 characters)
    if [[ ${#HETZNER_TOKEN} -ne 64 ]]; then
        log_warning "HETZNER_TOKEN appears to be malformed (expected 64 characters, got ${#HETZNER_TOKEN})"
        log_warning "Proceeding anyway - Terraform will validate the token"
    fi

    log_success "Hetzner Cloud prerequisites validated"
}

# SSH key validation with auto-detection
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

# Generate Hetzner-specific Terraform variables
provider_generate_terraform_vars() {
    local vars_file="$1"

    # Validate SSH key before generating vars
    provider_validate_ssh_key

    # Map VM memory to appropriate Hetzner server type if not explicitly set
    local server_type="${HETZNER_SERVER_TYPE:-}"
    if [[ -z "${server_type}" ]]; then
        case "${VM_MEMORY:-4096}" in
            1024) server_type="cx11" ;;   # 1 vCPU, 4GB RAM
            2048) server_type="cx21" ;;   # 2 vCPU, 8GB RAM  
            4096) server_type="cx31" ;;   # 2 vCPU, 8GB RAM
            8192) server_type="cx41" ;;   # 4 vCPU, 16GB RAM
            16384) server_type="cx51" ;;  # 8 vCPU, 32GB RAM
            *) server_type="cx31" ;;      # Default
        esac
        log_info "Auto-selected server type: ${server_type} (based on ${VM_MEMORY:-4096}MB memory)"
    fi

    cat > "${vars_file}" <<EOF
# Generated Hetzner Cloud provider variables
infrastructure_provider = "hetzner"

# Standard VM configuration
environment        = "${ENVIRONMENT:-development}"
vm_name           = "${VM_NAME:-torrust-tracker-demo}"
vm_memory         = ${VM_MEMORY:-4096}
vm_vcpus          = ${VM_VCPUS:-2}
vm_disk_size      = ${VM_DISK_SIZE:-40}
ssh_public_key    = "${SSH_PUBLIC_KEY}"
use_minimal_config = ${USE_MINIMAL_CONFIG:-false}

# Hetzner-specific settings
hetzner_token       = "${HETZNER_TOKEN}"
hetzner_server_type = "${server_type}"
hetzner_location    = "${HETZNER_LOCATION:-nbg1}"
hetzner_image       = "${HETZNER_IMAGE:-ubuntu-24.04}"
EOF

    log_success "Hetzner Terraform variables generated: ${vars_file}"
}

# Get provider information
provider_get_info() {
    echo "Provider: hetzner"
    echo "Description: Hetzner Cloud VPS hosting for production deployments"
    echo "Use case: Production deployment, staging environments, cloud hosting"
    echo ""
    echo "Required tools:"
    echo "  - Terraform/OpenTofu with hetznercloud/hcloud provider"
    echo "  - Hetzner Cloud account and API token"
    echo ""
    echo "Required variables:"
    echo "  - HETZNER_TOKEN (Hetzner Cloud API token)"
    echo ""
    echo "Optional variables:"
    echo "  - HETZNER_SERVER_TYPE (default: cx31 - 2 vCPU, 8GB RAM, 80GB SSD)"
    echo "  - HETZNER_LOCATION (default: nbg1 - Nuremberg, Germany)"
    echo "  - HETZNER_IMAGE (default: ubuntu-24.04)"
    echo "  - SSH_PUBLIC_KEY (auto-detected from ~/.ssh/)"
    echo ""
    echo "Server types available:"
    echo "  - cx11:  1 vCPU,  4GB RAM,  25GB SSD (~€3.29/month)"
    echo "  - cx21:  2 vCPU,  8GB RAM,  40GB SSD (~€5.83/month)" 
    echo "  - cx31:  2 vCPU,  8GB RAM,  80GB SSD (~€8.21/month)"
    echo "  - cx41:  4 vCPU, 16GB RAM, 160GB SSD (~€15.99/month)"
    echo "  - cx51:  8 vCPU, 32GB RAM, 320GB SSD (~€31.67/month)"
    echo ""
    echo "Locations available:"
    echo "  - nbg1: Nuremberg, Germany"
    echo "  - fsn1: Falkenstein, Germany" 
    echo "  - hel1: Helsinki, Finland"
    echo "  - ash:  Ashburn, VA, USA"
    echo "  - hil:  Hillsboro, OR, USA"
    echo ""
    echo "Setup instructions:"
    echo "  1. Create Hetzner Cloud account: https://console.hetzner.cloud/"
    echo "  2. Generate API token: Project → Security → API Tokens"
    echo "  3. Export token: export HETZNER_TOKEN=your_token_here"
    echo "  4. Deploy: make infra-apply ENVIRONMENT=production PROVIDER=hetzner"
}

# Provider cleanup (optional)
provider_cleanup() {
    log_info "Hetzner provider cleanup completed"
    # No specific cleanup needed for Hetzner provider
}
