#!/bin/bash
# Fix libvirt volume permissions after creation
# This script is called by OpenTofu after creating volumes

set -euo pipefail

# Get script directory and source shell utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../scripts/shell-utils.sh"

log_info "Fixing libvirt volume permissions..."

# Ensure sudo credentials are cached before running permission fixes
if ! ensure_sudo_cached "fix libvirt volume permissions"; then
    log_error "Cannot proceed without administrator privileges"
    exit 1
fi

# Fix ownership of all files in libvirt images directory
log_debug "Setting ownership for /var/lib/libvirt/images/"
sudo chown -R libvirt-qemu:libvirt /var/lib/libvirt/images/ 2>/dev/null || true

log_debug "Setting permissions for /var/lib/libvirt/images/"
sudo chmod -R 755 /var/lib/libvirt/images/ 2>/dev/null || true

# Also fix qemu directory
log_debug "Setting ownership for /var/lib/libvirt/qemu/"
sudo chown -R libvirt-qemu:kvm /var/lib/libvirt/qemu/ 2>/dev/null || true

log_success "Volume permissions fixed"
