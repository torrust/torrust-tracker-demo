#!/bin/bash
# Comprehensive libvirt permission fix script
# This script addresses all common libvirt permission issues

set -euo pipefail

echo "🔧 Comprehensive libvirt permission fix..."

# 1. Ensure correct ownership of libvirt directories
echo "1. Fixing libvirt directory ownership..."
sudo chown -R libvirt-qemu:libvirt /var/lib/libvirt/images/ || true
sudo chmod -R 755 /var/lib/libvirt/images/ || true

# 2. Set proper permissions on qemu directory
echo "2. Fixing qemu configuration directory..."
sudo chown -R libvirt-qemu:kvm /var/lib/libvirt/qemu/ || true
sudo chmod -R 755 /var/lib/libvirt/qemu/ || true

# 3. Create udev rule to automatically fix ownership for new files
echo "3. Creating udev rule for automatic ownership fix..."
sudo tee /etc/udev/rules.d/99-libvirt-qemu.rules >/dev/null <<'EOF'
# Automatically set correct ownership for libvirt files
ACTION=="add", SUBSYSTEM=="block", KERNEL=="loop*", OWNER="libvirt-qemu", GROUP="libvirt"
ACTION=="add", PATH=="/var/lib/libvirt/images/*", OWNER="libvirt-qemu", GROUP="libvirt"
EOF

# 4. Update libvirt configuration to use correct user/group
echo "4. Updating libvirt configuration..."
sudo sed -i 's/^#user = "libvirt-qemu"/user = "libvirt-qemu"/' /etc/libvirt/qemu.conf || true
sudo sed -i 's/^#group = "kvm"/group = "kvm"/' /etc/libvirt/qemu.conf || true

# 5. Update AppArmor profile with proper override (fixes terraform-provider-libvirt issue #1163)
echo "5. Updating AppArmor profile for libvirt..."
# Create AppArmor override directory
sudo mkdir -p /etc/apparmor.d/abstractions/libvirt-qemu.d

# Create override file with proper permissions for storage directories
sudo tee /etc/apparmor.d/abstractions/libvirt-qemu.d/override >/dev/null <<'EOF'
# AppArmor override for libvirt-qemu to access custom storage locations
# This fixes permission denied errors with terraform-provider-libvirt
# See: https://github.com/dmacvicar/terraform-provider-libvirt/issues/1163

# Allow access to default libvirt images directory
/var/lib/libvirt/images/** rwk,

# Allow access to user-specific libvirt storage
/home/*/libvirt/images/** rwk,
EOF

# Ensure parent directories have execute permissions for libvirt-qemu user
chmod o+x /home/*/libvirt 2>/dev/null || true
chmod o+x /home/* 2>/dev/null || true

# 6. Restart services
echo "6. Restarting services..."
sudo systemctl reload udev || true
sudo systemctl restart libvirtd || true
sudo systemctl reload apparmor || true

# 7. Fix any existing files
echo "7. Final ownership fix..."
sudo chown -R libvirt-qemu:libvirt /var/lib/libvirt/images/ || true

echo "✅ Libvirt permission fix complete!"
