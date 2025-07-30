#!/bin/bash
# Generate Self-Signed SSL Certificates for Torrust Tracker Demo
#
# This script generates self-signed SSL certificates on the host filesystem
# for local development and testing. These certificates provide HTTPS security 
# but will show browser warnings as they are not issued by a trusted CA.
#
# Usage: ./ssl-generate-test-certs.sh DOMAIN
#
# Arguments:
#   DOMAIN    The domain name for which to generate certificates
#
# Examples:
#   ./ssl-generate-test-certs.sh test.local
#   ./ssl-generate-test-certs.sh example.com

set -euo pipefail

# Source application-specific shell utilities
source "$(dirname "${BASH_SOURCE[0]}")/shell-utils.sh"

# Configuration
DOMAIN=""
CERT_VALIDITY_DAYS=365
KEY_SIZE=2048

# Parse command line arguments
parse_arguments() {
    if [[ $# -ne 1 ]]; then
        log_error "Invalid number of arguments"
        show_usage
        exit 1
    fi

    DOMAIN="$1"
}

# Show usage information
show_usage() {
    cat << 'EOF'
Generate Self-Signed SSL Certificates for Torrust Tracker Demo

This script generates self-signed SSL certificates on the host filesystem
for local development and testing. The certificates are valid for HTTPS but 
will show security warnings in browsers as they are not issued by a trusted 
Certificate Authority.

USAGE:
    $0 DOMAIN

ARGUMENTS:
    DOMAIN              Domain name for SSL certificates (e.g., test.local)

EXAMPLES:
    # Generate certificates for local testing
    $0 test.local

    # Generate certificates for a custom domain
    $0 example.com

GENERATED CERTIFICATES:
    The script generates certificates for:
    - tracker.DOMAIN (Torrust Tracker API and web interface)
    - grafana.DOMAIN (Grafana monitoring dashboard)

CERTIFICATE LOCATIONS:
    Certificates are generated on the host filesystem at:
    - /var/lib/torrust/proxy/certs/tracker.DOMAIN.crt
    - /var/lib/torrust/proxy/private/tracker.DOMAIN.key
    - /var/lib/torrust/proxy/certs/grafana.DOMAIN.crt
    - /var/lib/torrust/proxy/private/grafana.DOMAIN.key

PREREQUISITES:
    1. OpenSSL must be available on the host system
    2. Write access to /var/lib/torrust/proxy/ directory
    3. Running from the application directory (where compose.yaml is located)

SECURITY NOTE:
    Self-signed certificates provide encryption but not identity verification.
    They are suitable for development and testing but should be replaced with
    trusted certificates (Let's Encrypt) for production use.
EOF
}

# Validate arguments
validate_arguments() {
    if [[ -z "${DOMAIN}" ]]; then
        log_error "Domain name is required"
        show_usage
        exit 1
    fi

    # Validate domain format (basic check)
    if [[ ! "${DOMAIN}" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]]; then
        log_error "Invalid domain format: ${DOMAIN}"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if we're in the application directory
    if [[ ! -f "compose.yaml" ]]; then
        log_error "This script must be run from the application directory"
        log_error "Expected to find compose.yaml in current directory"
        exit 1
    fi

    # Check if OpenSSL is available on the host
    if ! command -v openssl >/dev/null 2>&1; then
        log_error "OpenSSL is not available on the system"
        log_error "Please install OpenSSL: sudo apt update && sudo apt install openssl"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Generate self-signed certificate for a subdomain
generate_certificate() {
    local subdomain="$1"
    local cert_path="/var/lib/torrust/proxy/certs/${subdomain}.crt"
    local key_path="/var/lib/torrust/proxy/private/${subdomain}.key"
    local config_path="/tmp/cert_config_${subdomain}.conf"

    log_info "Generating self-signed certificate for ${subdomain}..."

    # Generate private key
    log_info "  - Generating private key..."
    if ! openssl genrsa -out "${key_path}" "${KEY_SIZE}"; then
        log_error "Failed to generate private key for ${subdomain}"
        return 1
    fi

    # Set secure permissions on private key
    chmod 600 "${key_path}"

    # Generate certificate configuration
    log_info "  - Creating certificate configuration..."
    cat > "${config_path}" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C=US
ST=Test
L=Test
O=Torrust Tracker Demo
OU=Testing
CN=${subdomain}

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${subdomain}
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF

    # Generate self-signed certificate
    log_info "  - Generating self-signed certificate..."
    if ! openssl req -new -x509 \
        -key "${key_path}" \
        -out "${cert_path}" \
        -days "${CERT_VALIDITY_DAYS}" \
        -config "${config_path}" \
        -extensions v3_req; then
        log_error "Failed to generate certificate for ${subdomain}"
        rm -f "${config_path}"
        return 1
    fi

    # Clean up temporary config file
    rm -f "${config_path}"

    # Set appropriate permissions on certificate
    chmod 644 "${cert_path}"

    log_success "  ✅ Certificate generated for ${subdomain}"
    log_info "    Private key: ${key_path}"
    log_info "    Certificate: ${cert_path}"
    return 0
}

# Show certificate information
show_certificate_info() {
    local subdomain="$1"
    local cert_path="/var/lib/torrust/proxy/certs/${subdomain}.crt"

    log_info "Certificate information for ${subdomain}:"
    log_info "  Location: ${cert_path}"
    log_info "  Type: Self-signed certificate"
    log_info "  Validity: ${CERT_VALIDITY_DAYS} days"

    # Try to show certificate details
    if [[ -f "${cert_path}" ]]; then
        local subject
        local expiry
        subject=$(openssl x509 -in "${cert_path}" -noout -subject 2>/dev/null | cut -d= -f2- || echo "Unable to determine")
        expiry=$(openssl x509 -in "${cert_path}" -noout -enddate 2>/dev/null | cut -d= -f2 || echo "Unable to determine")
        log_info "  Subject: ${subject}"
        log_info "  Expires: ${expiry}"
    fi
}

# Main certificate generation function
main() {
    log_info "Starting self-signed SSL certificate generation"
    log_info "Domain: ${DOMAIN}"
    log_info "Validity: ${CERT_VALIDITY_DAYS} days"

    check_prerequisites

    # Create SSL certificate directories if they don't exist
    local cert_dir="/var/lib/torrust/proxy/certs"
    local private_dir="/var/lib/torrust/proxy/private"
    if [[ ! -d "${cert_dir}" ]] || [[ ! -d "${private_dir}" ]]; then
        log_info "Creating SSL certificate directories..."
        sudo mkdir -p "${cert_dir}" "${private_dir}"
        sudo chown -R torrust:torrust /var/lib/torrust/proxy/
        sudo chmod 755 "${cert_dir}"
        sudo chmod 700 "${private_dir}"
    fi

    # Generate certificates for required subdomains
    local subdomains=("tracker.${DOMAIN}" "grafana.${DOMAIN}")
    local generation_failed=false

    for subdomain in "${subdomains[@]}"; do
        if ! generate_certificate "${subdomain}"; then
            generation_failed=true
        fi
    done

    # Check if any certificate generation failed
    if [[ "${generation_failed}" == "true" ]]; then
        log_error "Certificate generation failed for one or more subdomains"
        log_error "Please check the error messages above and resolve any issues"
        exit 1
    fi

    # Show certificate information
    log_info ""
    log_info "Certificate generation completed successfully!"
    for subdomain in "${subdomains[@]}"; do
        show_certificate_info "${subdomain}"
    done

    # Show next steps
    log_info ""
    log_info "Next steps:"
    log_info "1. Start Docker services that will use these certificates"
    log_info "2. Test HTTPS endpoints (expect certificate warnings in browsers)"
    log_info "3. To upgrade to trusted certificates later, use Let's Encrypt SSL setup"
    log_info ""
    log_warning "⚠️  Self-signed certificate security notes:"
    log_warning "  - Browsers will show security warnings"
    log_warning "  - These certificates provide encryption but not identity verification"
    log_warning "  - Suitable for development/testing, not production use"
    log_warning "  - For production, use Let's Encrypt certificates instead"

    log_success "✅ Self-signed SSL certificate generation completed successfully!"
}

# Parse arguments and run main function
parse_arguments "$@"
validate_arguments
main
