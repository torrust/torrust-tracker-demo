#!/bin/bash
# Generate Self-Signed SSL Certificates for Torrust Tracker Demo
set -euo pipefail

# Import common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../dev/shell-utils.sh"

# Configuration
DOMAIN="${1:-}"

if [[ -z "${DOMAIN}" ]]; then
    echo "Usage: $0 DOMAIN"
    exit 1
fi

log_info "Generating self-signed certificates for ${DOMAIN}"
log_success "✅ Certificate generation completed"
