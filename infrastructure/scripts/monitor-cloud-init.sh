#!/bin/bash
# Monitor cloud-init progress for Torrust Tracker Demo VM

VM_NAME="torrust-tracker-demo"
SSH_KEY_PATH="$HOME/.ssh/torrust_rsa"
echo "🔍 Monitoring cloud-init progress for $VM_NAME"
echo "Press Ctrl+C to stop monitoring"
echo ""

# Function to try SSH connection and get cloud-init status
check_cloud_init() {
    local ip=$1
    timeout 5 ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o BatchMode=yes \
        -i "$SSH_KEY_PATH" torrust@"$ip" \
        "sudo cloud-init status --long" 2>/dev/null
}

# Function to try SSH connection and get cloud-init logs
get_cloud_init_logs() {
    local ip=$1
    timeout 10 ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o BatchMode=yes \
        -i "$SSH_KEY_PATH" torrust@"$ip" \
        "sudo tail -f /var/log/cloud-init-output.log" 2>/dev/null
}

counter=0
while true; do
    counter=$((counter + 1))
    echo "--- Check #$counter at $(date) ---"

    # Check VM state
    vm_state=$(virsh domstate $VM_NAME 2>/dev/null)
    echo "VM State: $vm_state"

    # Try to get IP address
    ip=$(virsh domifaddr $VM_NAME 2>/dev/null | grep -E "192\.168\.122\.[0-9]+" | awk '{print $4}' | cut -d'/' -f1)

    if [ -n "$ip" ]; then
        echo "VM IP: $ip"
        echo "Checking cloud-init status..."

        if cloud_init_status=$(check_cloud_init "$ip"); then
            echo "$cloud_init_status"

            if echo "$cloud_init_status" | grep -q "status: done"; then
                echo "🎉 Cloud-init completed!"
                echo "You can now connect: ssh -i $SSH_KEY_PATH torrust@$ip"
                break
            elif echo "$cloud_init_status" | grep -q "status: running"; then
                echo "📦 Cloud-init is running... Getting live logs:"
                get_cloud_init_logs "$ip"
            fi
        else
            echo "⏳ SSH not ready yet, cloud-init may still be running..."
        fi
    else
        echo "⏳ No IP address yet..."
        # Check DHCP leases
        virsh net-dhcp-leases default 2>/dev/null | grep -v "Expiry Time" | grep -v "^$" | head -5
    fi

    echo ""
    sleep 10
done
