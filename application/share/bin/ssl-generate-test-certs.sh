#!/bin/bash
# SSL Test Certificate Generation Script
# Usage: ./ssl-generate-test-certs.sh <domain>
# 
# This script generates self-signed certificates for local SSL testing.
# These certificates are suitable for testing nginx HTTPS configuration
# without requiring external certificate authorities or DNS setup.

set -euo pipefail

# Source shell utilities for logging (optional for standalone operation)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# Try to source shell-utils.sh, fallback to simple logging if not available
if [[ -f "${PROJECT_ROOT}/scripts/shell-utils.sh" ]]; then
    # shellcheck source=../../../../scripts/shell-utils.sh
    source "${PROJECT_ROOT}/scripts/shell-utils.sh"
else
    # Fallback logging functions
    log_info() { echo "[INFO] $*"; }
    log_success() { echo "[SUCCESS] $*"; }
    log_error() { echo "[ERROR] $*"; }
fi

# Configuration
DOMAIN="${1:-test.local}"

# Certificate parameters
CERT_DAYS=365
KEY_SIZE=2048
COUNTRY="US"
STATE="Test State"
CITY="Test City"
ORG="Torrust Test"
OU="Testing Department"

main() {
    log_info "🔐 Generating self-signed SSL certificates for: ${DOMAIN}"
    
    validate_domain
    
    # Generate certificates for each subdomain (like Let's Encrypt does)
    local subdomains=("tracker.${DOMAIN}" "grafana.${DOMAIN}")
    
    for subdomain in "${subdomains[@]}"; do
        log_info "Generating certificate for ${subdomain}..."
        
        create_certificate_directory "${subdomain}"
        generate_private_key "${subdomain}"
        generate_certificate "${subdomain}"
        create_certificate_chain "${subdomain}"
        set_permissions "${subdomain}"
        validate_certificates "${subdomain}"
        
        log_success "✅ Certificate generated for ${subdomain}"
    done
    
    log_success "✅ All test SSL certificates generated successfully!"
    print_usage_instructions
}

validate_domain() {
    if [[ -z "${DOMAIN}" ]]; then
        log_error "Domain name is required"
        echo "Usage: $0 <domain>"
        echo "Example: $0 test.local"
        exit 1
    fi
    
    log_info "Domain: ${DOMAIN}"
    log_info "Will generate certificates for:"
    log_info "  - tracker.${DOMAIN}"
    log_info "  - grafana.${DOMAIN}"
}

create_certificate_directory() {
    local subdomain="$1"
    local cert_dir="/var/lib/torrust/certbot/etc/live/${subdomain}"
    
    log_info "Creating certificate directory for ${subdomain}..."
    
    # Create the directory structure (same as Let's Encrypt)
    sudo mkdir -p "${cert_dir}"
    
    # Ensure proper ownership (torrust user should own the files)
    sudo chown -R torrust:torrust "$(dirname "${cert_dir}")"
    
    log_success "Certificate directory created: ${cert_dir}"
}

generate_private_key() {
    local subdomain="$1"
    local cert_dir="/var/lib/torrust/certbot/etc/live/${subdomain}"
    local private_key="${cert_dir}/privkey.pem"
    
    log_info "Generating private key for ${subdomain} (${KEY_SIZE} bits)..."
    
    openssl genrsa -out "${private_key}" "${KEY_SIZE}"
    
    log_success "Private key generated: ${private_key}"
}

generate_certificate() {
    local subdomain="$1"
    local cert_dir="/var/lib/torrust/certbot/etc/live/${subdomain}"
    local private_key="${cert_dir}/privkey.pem"
    local cert_only="${cert_dir}/cert.pem"
    
    log_info "Generating self-signed certificate for ${subdomain}..."
    
    # Create certificate with Subject Alternative Names for subdomains
    openssl req -new -x509 -key "${private_key}" \
        -out "${cert_only}" \
        -days "${CERT_DAYS}" \
        -config <(
cat <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C=${COUNTRY}
ST=${STATE}
L=${CITY}
O=${ORG}
OU=${OU}
CN=${subdomain}

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${subdomain}
DNS.2 = ${DOMAIN}
DNS.3 = *.${DOMAIN}
EOF
        )
    
    log_success "Certificate generated: ${cert_only}"
}

create_certificate_chain() {
    local subdomain="$1"
    local cert_dir="/var/lib/torrust/certbot/etc/live/${subdomain}"
    local cert_only="${cert_dir}/cert.pem"
    local cert_chain="${cert_dir}/chain.pem"
    local cert_file="${cert_dir}/fullchain.pem"
    
    log_info "Creating certificate chain files for ${subdomain}..."
    
    # For self-signed certificates, the chain is just the certificate itself
    cp "${cert_only}" "${cert_chain}"
    cp "${cert_only}" "${cert_file}"
    
    log_success "Certificate chain files created"
}

set_permissions() {
    local subdomain="$1"
    local cert_dir="/var/lib/torrust/certbot/etc/live/${subdomain}"
    local private_key="${cert_dir}/privkey.pem"
    local cert_file="${cert_dir}/fullchain.pem"
    local cert_chain="${cert_dir}/chain.pem"
    local cert_only="${cert_dir}/cert.pem"
    
    log_info "Setting certificate file permissions for ${subdomain}..."
    
    # Set secure permissions
    chmod 600 "${private_key}"
    chmod 644 "${cert_file}" "${cert_chain}" "${cert_only}"
    
    # Ensure torrust user owns all certificate files
    chown torrust:torrust "${private_key}" "${cert_file}" "${cert_chain}" "${cert_only}"
    
    log_success "Permissions set correctly"
}

validate_certificates() {
    local subdomain="$1"
    local cert_dir="/var/lib/torrust/certbot/etc/live/${subdomain}"
    local cert_file="${cert_dir}/fullchain.pem"
    
    log_info "Validating generated certificates for ${subdomain}..."
    
    # Check if files exist
    for file in "${cert_dir}/privkey.pem" "${cert_dir}/fullchain.pem" "${cert_dir}/chain.pem" "${cert_dir}/cert.pem"; do
        if [[ ! -f "${file}" ]]; then
            log_error "Certificate file not found: ${file}"
            exit 1
        fi
    done
    
    # Validate certificate content
    if openssl x509 -in "${cert_file}" -text -noout > /dev/null 2>&1; then
        log_success "Certificate validation passed for ${subdomain}"
    else
        log_error "Certificate validation failed for ${subdomain}"
        exit 1
    fi
    
    # Display certificate information
    log_info "Certificate details for ${subdomain}:"
    openssl x509 -in "${cert_file}" -text -noout | grep -E "(Subject:|DNS:|Not Before|Not After)"
}

print_usage_instructions() {
    echo
    echo "📋 Next Steps:"
    echo "1. Configure nginx for HTTPS:"
    echo "   ./ssl-configure-nginx.sh ${DOMAIN}"
    echo
    echo "2. Restart nginx to load certificates:"
    echo "   docker compose restart proxy"
    echo
    echo "3. Test HTTPS endpoints (expect certificate warnings for self-signed):"
    echo "   curl -k https://tracker.${DOMAIN}/"
    echo "   curl -k https://grafana.${DOMAIN}/"
    echo
    echo "4. View certificate details:"
    echo "   openssl x509 -in /var/lib/torrust/certbot/etc/live/tracker.${DOMAIN}/fullchain.pem -text -noout"
    echo "   openssl x509 -in /var/lib/torrust/certbot/etc/live/grafana.${DOMAIN}/fullchain.pem -text -noout"
    echo
    echo "⚠️  Note: Self-signed certificates will show security warnings in browsers."
    echo "   Use -k flag with curl or add certificate to trusted store for testing."
}

# Run main function
main "$@"
