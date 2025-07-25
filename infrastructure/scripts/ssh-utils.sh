#!/bin/bash
# SSH utilities for VM development environments
# Handles common SSH issues like host key verification failures

set -euo pipefail

# Source shell utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=scripts/shell-utils.sh
source "${PROJECT_ROOT}/scripts/shell-utils.sh"

# Clean SSH known_hosts entries for VM IP addresses
clean_vm_known_hosts() {
    local vm_ip="$1"
    local vm_name="${2:-torrust-tracker-demo}"

    if [[ -z "$vm_ip" || "$vm_ip" == "No IP assigned yet" ]]; then
        log_warning "No VM IP provided for known_hosts cleanup"
        return 0
    fi

    log_info "Cleaning SSH known_hosts entries for VM ${vm_name} (${vm_ip})"

    # Remove entries for the IP address
    if [[ -f ~/.ssh/known_hosts ]]; then
        # Use ssh-keygen to remove entries (safe and atomic)
        if ssh-keygen -f ~/.ssh/known_hosts -R "${vm_ip}" >/dev/null 2>&1; then
            log_success "Removed old SSH host key entries for ${vm_ip}"
        else
            log_info "No existing SSH host key entries found for ${vm_ip}"
        fi
    else
        log_info "No ~/.ssh/known_hosts file found"
    fi
}

# Clean SSH known_hosts for all libvirt default network IPs (192.168.122.0/24)
clean_libvirt_known_hosts() {
    log_info "Cleaning SSH known_hosts entries for entire libvirt network range"

    if [[ ! -f ~/.ssh/known_hosts ]]; then
        log_info "No ~/.ssh/known_hosts file found"
        return 0
    fi

    # Remove all entries for 192.168.122.* (libvirt default network)
    local cleaned_count=0
    for ip in $(seq 1 254); do
        if ssh-keygen -f ~/.ssh/known_hosts -R "192.168.122.${ip}" >/dev/null 2>&1; then
            ((cleaned_count++))
        fi
    done

    if [[ $cleaned_count -gt 0 ]]; then
        log_success "Cleaned ${cleaned_count} SSH host key entries for libvirt network"
    else
        log_info "No libvirt network SSH host key entries found"
    fi
}

# Get VM IP address from various sources
get_vm_ip() {
    local vm_name="${1:-torrust-tracker-demo}"
    local vm_ip=""

    # Try terraform output first
    if command -v tofu >/dev/null 2>&1; then
        vm_ip=$(cd "${PROJECT_ROOT}/infrastructure/terraform" && tofu output -raw vm_ip 2>/dev/null || echo "")
        if [[ -n "$vm_ip" && "$vm_ip" != "No IP assigned yet" ]]; then
            echo "$vm_ip"
            return 0
        fi
    fi

    # Try libvirt directly
    vm_ip=$(virsh domifaddr "$vm_name" 2>/dev/null | grep ipv4 | awk '{print $4}' | cut -d'/' -f1 || echo "")
    if [[ -n "$vm_ip" ]]; then
        echo "$vm_ip"
        return 0
    fi

    return 1
}

# Prepare SSH connection to VM (clean known_hosts and test connectivity)
prepare_vm_ssh() {
    local vm_name="${1:-torrust-tracker-demo}"
    local max_attempts="${2:-3}"

    log_info "Preparing SSH connection to VM ${vm_name}"

    # Get VM IP
    local vm_ip
    if ! vm_ip=$(get_vm_ip "$vm_name"); then
        log_error "Could not get IP address for VM ${vm_name}"
        return 1
    fi

    log_info "VM IP: ${vm_ip}"

    # Clean known_hosts entries
    clean_vm_known_hosts "$vm_ip" "$vm_name"

    # Test SSH connectivity
    log_info "Testing SSH connectivity (up to ${max_attempts} attempts)"
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes \
            torrust@"${vm_ip}" "echo 'SSH OK'" >/dev/null 2>&1; then
            log_success "SSH connection established to ${vm_ip}"
            echo "$vm_ip"
            return 0
        fi

        log_warning "SSH attempt ${attempt}/${max_attempts} failed, waiting 5 seconds..."
        sleep 5
        ((attempt++))
    done

    log_error "Failed to establish SSH connection after ${max_attempts} attempts"
    log_error "Common causes:"
    log_error "  1. VM is still booting (cloud-init may take 2-5 minutes)"
    log_error "  2. SSH service is not ready yet"
    log_error "  3. Firewall blocking connections"
    log_error "Try manually: ssh -o StrictHostKeyChecking=no torrust@${vm_ip}"
    return 1
}

# Main function for command-line usage
main() {
    case "${1:-help}" in
    clean)
        local vm_ip="${2:-}"
        if [[ -z "$vm_ip" ]]; then
            if vm_ip=$(get_vm_ip); then
                clean_vm_known_hosts "$vm_ip"
            else
                log_error "Could not determine VM IP. Please provide IP as argument."
                exit 1
            fi
        else
            clean_vm_known_hosts "$vm_ip"
        fi
        ;;
    clean-all)
        clean_libvirt_known_hosts
        ;;
    prepare)
        local vm_name="${2:-torrust-tracker-demo}"
        prepare_vm_ssh "$vm_name"
        ;;
    get-ip)
        local vm_name="${2:-torrust-tracker-demo}"
        get_vm_ip "$vm_name"
        ;;
    help | *)
        cat <<'EOF'
SSH utilities for VM development environments

Usage:
  ssh-utils.sh clean [IP]        - Clean known_hosts for specific IP (or auto-detect)
  ssh-utils.sh clean-all         - Clean known_hosts for entire libvirt network
  ssh-utils.sh prepare [VM_NAME] - Clean known_hosts and test SSH connectivity
  ssh-utils.sh get-ip [VM_NAME]  - Get VM IP address
  ssh-utils.sh help              - Show this help

Examples:
  ./infrastructure/scripts/ssh-utils.sh clean
  ./infrastructure/scripts/ssh-utils.sh clean 192.168.122.25
  ./infrastructure/scripts/ssh-utils.sh prepare torrust-tracker-demo
  ./infrastructure/scripts/ssh-utils.sh clean-all

This script helps resolve SSH host key verification issues that occur when
VMs are recreated with the same IP addresses but different host keys.
EOF
        ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
