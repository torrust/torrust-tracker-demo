#!/bin/bash

# SSL Local DNS Setup Script
# Configure local DNS resolution for Pebble testing

set -euo pipefail

# Get script directory for sourcing utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../../scripts/shell-utils.sh" ]; then
    # shellcheck source=../../scripts/shell-utils.sh
    . "$SCRIPT_DIR/../../scripts/shell-utils.sh"
elif [ -f "/home/torrust/github/torrust/torrust-tracker-demo/scripts/shell-utils.sh" ]; then
    # shellcheck source=/home/torrust/github/torrust/torrust-tracker-demo/scripts/shell-utils.sh
    . "/home/torrust/github/torrust/torrust-tracker-demo/scripts/shell-utils.sh"
else
    echo "ERROR: shell-utils.sh not found"
    exit 1
fi

# Configuration
DOMAINS=(
    "torrust.test.local"
    "api.test.local"
    "grafana.test.local"
    "prometheus.test.local"
)

show_help() {
    cat << 'EOF'
SSL Local DNS Setup Script

This script configures local DNS resolution for Pebble SSL testing by adding
entries to /etc/hosts that point test domains to the local VM IP address.

USAGE:
    ssl-setup-local-dns.sh [OPTIONS]

OPTIONS:
    --setup     Add domain entries to /etc/hosts
    --cleanup   Remove domain entries from /etc/hosts  
    --status    Show current domain resolution status
    --help      Show this help message

EXAMPLES:
    # Setup local DNS for Pebble testing
    ./ssl-setup-local-dns.sh --setup
    
    # Check current DNS status
    ./ssl-setup-local-dns.sh --status
    
    # Cleanup when done testing
    ./ssl-setup-local-dns.sh --cleanup

This script is designed for local Pebble SSL testing only.
EOF
}

get_vm_ip() {
    # Get the VM's internal IP address
    local vm_ip
    vm_ip=$(hostname -I | awk '{print $1}')
    echo "$vm_ip"
}

setup_local_dns() {
    local vm_ip
    vm_ip=$(get_vm_ip)
    
    echo "Setting up local DNS for Pebble testing..."
    echo "VM IP: $vm_ip"
    
    # Backup current /etc/hosts
    ensure_sudo_cached
    sudo cp /etc/hosts "/etc/hosts.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Remove any existing entries for our domains
    cleanup_local_dns_silent
    
    # Add entries for each domain
    echo "" | sudo tee -a /etc/hosts > /dev/null
    echo "# Torrust Tracker Demo - Pebble SSL Testing" | sudo tee -a /etc/hosts > /dev/null
    for domain in "${DOMAINS[@]}"; do
        echo "$vm_ip $domain" | sudo tee -a /etc/hosts > /dev/null
        echo "Added: $vm_ip $domain"
    done
    echo "# End Torrust Tracker Demo entries" | sudo tee -a /etc/hosts > /dev/null
    
    echo ""
    echo "✅ Local DNS setup complete!"
    echo ""
    echo "Test domain resolution:"
    for domain in "${DOMAINS[@]}"; do
        if ping -c1 "$domain" >/dev/null 2>&1; then
            echo "  ✅ $domain -> $(dig +short "$domain" 2>/dev/null || echo "$vm_ip")"
        else
            echo "  ❌ $domain (resolution failed)"
        fi
    done
}

cleanup_local_dns() {
    echo "Cleaning up local DNS entries..."
    cleanup_local_dns_silent
    echo "✅ Local DNS cleanup complete!"
}

cleanup_local_dns_silent() {
    # Remove lines between our markers
    ensure_sudo_cached
    sudo sed -i '/# Torrust Tracker Demo - Pebble SSL Testing/,/# End Torrust Tracker Demo entries/d' /etc/hosts
    
    # Also remove any standalone entries for our domains (in case markers are missing)
    for domain in "${DOMAINS[@]}"; do
        sudo sed -i "/$domain/d" /etc/hosts
    done
}

show_status() {
    local vm_ip
    vm_ip=$(get_vm_ip)
    
    echo "Local DNS Status for Pebble Testing"
    echo "=================================="
    echo "VM IP: $vm_ip"
    echo ""
    
    echo "Domain Resolution Status:"
    for domain in "${DOMAINS[@]}"; do
        if resolved_ip=$(dig +short "$domain" 2>/dev/null) && [ -n "$resolved_ip" ]; then
            if [ "$resolved_ip" = "$vm_ip" ]; then
                echo "  ✅ $domain -> $resolved_ip (correct)"
            else
                echo "  ⚠️  $domain -> $resolved_ip (should be $vm_ip)"
            fi
        else
            echo "  ❌ $domain (not resolved)"
        fi
    done
    
    echo ""
    echo "/etc/hosts entries:"
    if grep -q "Torrust Tracker Demo" /etc/hosts 2>/dev/null; then
        grep -A 20 "Torrust Tracker Demo" /etc/hosts | grep -B 20 "End Torrust Tracker Demo"
    else
        echo "  No Torrust Tracker Demo entries found"
    fi
}

main() {
    case "${1:-}" in
        --setup)
            setup_local_dns
            ;;
        --cleanup)
            cleanup_local_dns
            ;;
        --status)
            show_status
            ;;
        --help)
            show_help
            ;;
        *)
            echo "ERROR: Invalid option. Use --help for usage information."
            exit 1
            ;;
    esac
}

main "$@"
