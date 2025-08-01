#!/bin/bash
# LibVirt provider implementation
# Provides local KVM/libvirt virtualization for development and testing

set -euo pipefail

# Load shell utilities if not already loaded
if ! declare -F log_info >/dev/null 2>&1; then
    # shellcheck source=../../../../scripts/shell-utils.sh
    source "${PROJECT_ROOT:-$(dirname "$0")/../../../..}/scripts/shell-utils.sh"
fi

# Validate LibVirt prerequisites
provider_validate_prerequisites() {
    log_info "Validating LibVirt prerequisites"

    # Check if virsh is available
    if ! command -v virsh >/dev/null 2>&1; then
        log_error "virsh not found. Please install libvirt-clients."
        log_info "Install with: sudo apt install libvirt-clients"
        exit 1
    fi

    # Check if user has libvirt access
    if ! virsh list >/dev/null 2>&1; then
        log_error "No libvirt access. Please add user to libvirt group."
        log_info "Fix with: sudo usermod -aG libvirt \$USER && newgrp libvirt"
        exit 1
    fi

    # Check if default network is active
    if ! virsh net-list --name | grep -q "^default$" || ! virsh net-list | grep -q "default.*active"; then
        log_warning "Default libvirt network is not active"
        log_info "Starting default network..."
        if virsh net-start default 2>/dev/null; then
            virsh net-autostart default
            log_success "Default network started and set to autostart"
        else
            log_warning "Could not start default network (may already be active)"
        fi
    fi

    # Check if KVM is available
    if ! lsmod | grep -q kvm; then
        log_warning "KVM module not loaded. Performance may be degraded."
    fi

    log_success "LibVirt prerequisites validated"
}

# Validate and auto-detect SSH key configuration
provider_validate_ssh_key() {
    log_info "Validating SSH key configuration"

    # If SSH_PUBLIC_KEY is already set and not empty, use it
    if [[ -n "${SSH_PUBLIC_KEY:-}" ]]; then
        log_success "SSH public key provided in configuration"
        return 0
    fi

    # Try to auto-detect SSH key from common locations
    local ssh_key_paths=(
        "$HOME/.ssh/torrust_rsa.pub"
        "$HOME/.ssh/id_rsa.pub"
        "$HOME/.ssh/id_ed25519.pub"
        "$HOME/.ssh/id_ecdsa.pub"
    )

    for key_path in "${ssh_key_paths[@]}"; do
        if [[ -f "$key_path" ]]; then
            log_info "Found SSH public key: $key_path"
            SSH_PUBLIC_KEY=$(cat "$key_path")
            log_success "SSH public key auto-detected from: $key_path"
            return 0
        fi
    done

    # No SSH key found - provide clear error and instructions
    log_error "No SSH public key found for VM access"
    log_error ""
    log_error "SSH Key Configuration Required:"
    log_error "VM deployment requires an SSH public key for secure access."
    log_error ""
    log_error "Option 1: Use default SSH key location"
    log_error "  Create an SSH key at: $HOME/.ssh/torrust_rsa.pub"
    log_error "  Generate with: ssh-keygen -t rsa -b 4096 -f ~/.ssh/torrust_rsa -C \"your-email@example.com\""
    log_error ""
    log_error "Option 2: Configure SSH key in environment"
    log_error "  Edit: infrastructure/config/environments/development.env"
    log_error "  Set: SSH_PUBLIC_KEY=\"your-ssh-public-key-content\""
    log_error ""
    log_error "Option 3: Use existing SSH key"
    log_error "  Copy your existing public key to: $HOME/.ssh/torrust_rsa.pub"
    log_error "  Example: cp ~/.ssh/id_rsa.pub ~/.ssh/torrust_rsa.pub"
    log_error ""
    log_error "The system checked these locations:"
    for key_path in "${ssh_key_paths[@]}"; do
        log_error "  - $key_path (not found)"
    done
    log_error ""
    exit 1
}

# Generate LibVirt-specific Terraform variables
provider_generate_terraform_vars() {
    local vars_file="$1"

    log_info "Generating LibVirt Terraform variables: ${vars_file}"

    # Validate required environment variables
    if [[ -z "${VM_NAME:-}" ]]; then
        log_error "VM_NAME not set in environment configuration"
        exit 1
    fi

    # Validate and auto-detect SSH key
    provider_validate_ssh_key

    cat > "${vars_file}" <<EOF
# Generated LibVirt provider variables
# Generated at: $(date -Iseconds)

# Provider identification
infrastructure_provider = "libvirt"

# Standard VM configuration
vm_name            = "${VM_NAME}"
vm_memory          = ${VM_MEMORY:-2048}
vm_vcpus           = ${VM_VCPUS:-2}
vm_disk_size       = ${VM_DISK_SIZE:-20}
persistent_data_size = ${PERSISTENT_DATA_SIZE:-20}
use_minimal_config = ${USE_MINIMAL_CONFIG:-false}

# SSH configuration
ssh_public_key     = "${SSH_PUBLIC_KEY}"

# LibVirt-specific settings
base_image_url     = "${PROVIDER_LIBVIRT_BASE_IMAGE_URL:-https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img}"
EOF

    log_success "LibVirt Terraform variables generated: ${vars_file}"
}

# Get LibVirt provider information
provider_get_info() {
    echo "Provider: libvirt"
    echo "Description: Local KVM/libvirt virtualization for development and testing"
    echo "Use case: Local development, CI/CD testing, infrastructure development"
    echo ""
    echo "Required tools:"
    echo "  - virsh (libvirt-clients package)"
    echo "  - KVM virtualization support"
    echo "  - qemu-kvm"
    echo ""
    echo "Required variables:"
    echo "  - VM_NAME (virtual machine name)"
    echo ""
    echo "Optional variables:"
    echo "  - VM_MEMORY (default: 2048 MB)"
    echo "  - VM_VCPUS (default: 2)"
    echo "  - VM_DISK_SIZE (default: 20 GB)"
    echo "  - PERSISTENT_DATA_SIZE (default: 20 GB)"
    echo "  - SSH_PUBLIC_KEY (for VM access)"
    echo "  - USE_MINIMAL_CONFIG (default: false)"
    echo "  - PROVIDER_LIBVIRT_BASE_IMAGE_URL (Ubuntu cloud image URL)"
    echo ""
    echo "Network requirements:"
    echo "  - libvirt default network (NAT)"
    echo "  - Automatic IP assignment via DHCP"
    echo ""
    echo "Storage:"
    echo "  - Uses libvirt 'user-default' storage pool"
    echo "  - COW (copy-on-write) volumes for efficiency"
    echo "  - Separate persistent data volume"
}

# LibVirt provider cleanup (optional implementation)
provider_cleanup() {
    log_info "LibVirt provider cleanup (no specific cleanup required)"
    return 0
}

# Provider status check
provider_status() {
    echo "LibVirt Provider Status:"
    echo "======================="
    
    echo "LibVirt daemon:"
    if systemctl is-active --quiet libvirtd; then
        echo "  ✅ libvirtd is running"
    else
        echo "  ❌ libvirtd is not running"
    fi
    
    echo "User access:"
    if virsh list >/dev/null 2>&1; then
        echo "  ✅ User has libvirt access"
    else
        echo "  ❌ User does not have libvirt access"
    fi
    
    echo "Default network:"
    if virsh net-list | grep -q "default.*active"; then
        echo "  ✅ Default network is active"
    else
        echo "  ❌ Default network is not active"
    fi
    
    echo "KVM support:"
    if lsmod | grep -q kvm; then
        echo "  ✅ KVM module loaded"
    else
        echo "  ⚠️  KVM module not loaded"
    fi
    
    echo "Active VMs:"
    local vm_count
    vm_count=$(virsh list --name | wc -l)
    echo "  Running VMs: ${vm_count}"
}
