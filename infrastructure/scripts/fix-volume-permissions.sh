#!/bin/bash
# Fix libvirt volume permissions after creation
# This script is called by OpenTofu after creating volumes

set -euo pipefail

echo "Fixing libvirt volume permissions..."

# Fix ownership of all files in libvirt images directory
sudo chown -R libvirt-qemu:libvirt /var/lib/libvirt/images/ 2>/dev/null || true
sudo chmod -R 755 /var/lib/libvirt/images/ 2>/dev/null || true

# Also fix qemu directory
sudo chown -R libvirt-qemu:kvm /var/lib/libvirt/qemu/ 2>/dev/null || true

echo "✓ Volume permissions fixed"
