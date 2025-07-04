#!/bin/bash
# Alternative libvirt setup that avoids permission issues
# This script configures libvirt to work with root permissions temporarily

set -euo pipefail

echo "🔧 Setting up alternative libvirt configuration..."

# 1. Create alternative storage pool in user directory
STORAGE_DIR="/home/$USER/libvirt/images"
echo "1. Creating alternative storage directory: $STORAGE_DIR"
mkdir -p "$STORAGE_DIR"
chmod 755 "$STORAGE_DIR"

# 2. Define alternative storage pool
echo "2. Setting up alternative storage pool..."
if ! virsh pool-list --all | grep -q "user-default"; then
    cat >/tmp/user-pool.xml <<EOF
<pool type='dir'>
  <name>user-default</name>
  <target>
    <path>$STORAGE_DIR</path>
    <permissions>
      <mode>755</mode>
      <owner>$(id -u)</owner>
      <group>$(id -g)</group>
    </permissions>
  </target>
</pool>
EOF

    virsh pool-define /tmp/user-pool.xml
    virsh pool-autostart user-default
    virsh pool-start user-default
    rm /tmp/user-pool.xml
    echo "  ✓ User storage pool created"
else
    echo "  ✓ User storage pool already exists"
fi

# 3. Update libvirt to run as current user for local testing
echo "3. Updating libvirt configuration for local testing..."
sudo sed -i "s/^user = \"libvirt-qemu\"/user = \"$USER\"/" /etc/libvirt/qemu.conf || true
sudo sed -i "s/^group = \"kvm\"/group = \"$(id -gn)\"/" /etc/libvirt/qemu.conf || true

# 4. Restart libvirt
echo "4. Restarting libvirt..."
sudo systemctl restart libvirtd

echo "✅ Alternative libvirt configuration complete!"
echo "Storage pool 'user-default' is available at: $STORAGE_DIR"
