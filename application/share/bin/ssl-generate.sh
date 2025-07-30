#!/bin/bash
# SSL Certificate Generation Script for Torrust Tracker Demo
#
# This script generates SSL certificates using Let's Encrypt.
# It supports staging and production modes.
#
# Usage: ./ssl-generate.sh DOMAIN EMAIL MODE
#
# Arguments:
#   DOMAIN  - Domain name for certificates (e.g., example.com)
#   EMAIL   - Email for Let's Encrypt registration
#   MODE    - Certificate mode: --staging or --production
#
# Examples:
#   ./ssl-generate.sh example.com admin@example.com --staging
#   ./ssl-generate.sh example.com admin@example.com --production

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Source utilities
# shellcheck source=../../../scripts/shell-utils.sh
source "${PROJECT_ROOT}/scripts/shell-utils.sh"

# Validate arguments
if [[ $# -ne 3 ]]; then
    log_error "Usage: $0 DOMAIN EMAIL MODE"
    log_error "MODE: --staging or --production"
    log_error "Example: $0 example.com admin@example.com --staging"
    exit 1
fi

DOMAIN="$1"
EMAIL="$2"
MODE="$3"

# Validate mode
case "${MODE}" in
    --staging|--production)
        ;;
    *)
        log_error "Invalid mode: ${MODE}"
        log_error "Supported modes: --staging, --production"
        exit 1
        ;;
esac

# Get mode name without dashes
MODE_NAME="${MODE#--}"

# Check if we're in the application directory
APP_DIR="$(pwd)"
if [[ ! -f "${APP_DIR}/compose.yaml" ]]; then
    log_error "This script must be run from the application directory"
    log_error "Expected to find compose.yaml in current directory"
    exit 1
fi

# Setup certificate generation parameters based on mode
setup_cert_params() {
    case "${MODE_NAME}" in
        staging)
            CERT_ARGS="--test-cert"
            CERTBOT_SERVICE="certbot"
            COMPOSE_FILE="compose.yaml"
            log_info "Using Let's Encrypt staging environment"
            ;;
        production)
            CERT_ARGS=""
            CERTBOT_SERVICE="certbot"
            COMPOSE_FILE="compose.yaml"
            log_info "Using Let's Encrypt production environment"
            ;;
    esac
}

# Check prerequisites for certificate generation
check_prerequisites() {
    log_info "Checking prerequisites for ${MODE_NAME} mode..."
    
    # Check if required compose file exists
    if [[ ! -f "${COMPOSE_FILE}" ]]; then
        log_error "Required compose file not found: ${COMPOSE_FILE}"
        exit 1
    fi
    
    # Check if required services are running
    if ! docker compose ps proxy | grep -q "Up"; then
        log_error "Proxy service is not running"
        log_error "Please start services first: docker compose up -d"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Generate DH parameters if needed
generate_dhparam() {
    log_info "Checking DH parameters..."
    
    # Check if DH parameters already exist
    if docker compose exec proxy test -f "/etc/ssl/certs/dhparam.pem" 2>/dev/null; then
        log_info "DH parameters already exist, skipping generation"
        return 0
    fi
    
    log_info "Generating DH parameters (this may take several minutes)..."
    if docker compose exec proxy openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048; then
        log_success "DH parameters generated successfully"
    else
        log_error "Failed to generate DH parameters"
        exit 1
    fi
}

# Generate certificate for a subdomain
generate_certificate() {
    local subdomain="$1"
    
    log_info "Generating certificate for ${subdomain}..."
    
    # Prepare certbot command
    local certbot_cmd=(
        "docker" "compose" "-f" "${COMPOSE_FILE}" "run" "--rm" "${CERTBOT_SERVICE}"
        "certonly"
        "--webroot"
        "--webroot-path=/var/www/html"
        "--email" "${EMAIL}"
        "--agree-tos"
        "--no-eff-email"
        "-d" "${subdomain}"
    )
    
    # Add mode-specific arguments
    if [[ -n "${CERT_ARGS}" ]]; then
        # Split CERT_ARGS and add each argument safely
        read -ra cert_args_array <<< "${CERT_ARGS}"
        certbot_cmd+=("${cert_args_array[@]}")
    fi
    
    # Execute certbot command
    if "${certbot_cmd[@]}"; then
        log_success "Certificate generated successfully for ${subdomain}"
        return 0
    else
        log_error "Failed to generate certificate for ${subdomain}"
        return 1
    fi
}

# Show production warning and get confirmation
production_warning() {
    if [[ "${MODE_NAME}" != "production" ]]; then
        return 0
    fi
    
    log_warning "⚠️  PRODUCTION CERTIFICATE GENERATION WARNING ⚠️"
    log_warning ""
    log_warning "You are about to generate PRODUCTION SSL certificates."
    log_warning "This will use Let's Encrypt production servers which have rate limits:"
    log_warning ""
    log_warning "  • 50 certificates per registered domain per week"
    log_warning "  • 5 failed validations per hostname per hour"
    log_warning "  • 5 duplicate certificates per week"
    log_warning ""
    log_warning "Domain: ${DOMAIN}"
    log_warning "Email: ${EMAIL}"
    log_warning "Subdomains: tracker.${DOMAIN}, grafana.${DOMAIN}"
    log_warning ""
    log_warning "It is STRONGLY RECOMMENDED to test with --staging first!"
    log_warning ""
    
    read -p "Continue with production certificate generation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Production certificate generation cancelled"
        log_info "Run with --staging first to test the workflow"
        exit 0
    fi
    
    log_info "Proceeding with production certificate generation..."
}

# Show certificate information
show_certificate_info() {
    local subdomain="$1"
    
    log_info "Certificate information for ${subdomain}:"
    log_info "  Location: /var/lib/torrust/certbot/etc/letsencrypt/live/${subdomain}/"
    log_info "  Type: Let's Encrypt ${MODE_NAME} certificate"
    
    # Try to show certificate expiration
    if docker compose exec proxy test -f "/etc/letsencrypt/live/${subdomain}/cert.pem" 2>/dev/null; then
        local expiry
        expiry=$(docker compose exec proxy openssl x509 -in "/etc/letsencrypt/live/${subdomain}/cert.pem" -noout -enddate 2>/dev/null | cut -d= -f2 || echo "Unable to determine")
        log_info "  Expires: ${expiry}"
    fi
}

# Main certificate generation function
main() {
    log_info "Starting SSL certificate generation"
    log_info "Domain: ${DOMAIN}"
    log_info "Email: ${EMAIL}"
    log_info "Mode: ${MODE_NAME}"
    
    setup_cert_params
    production_warning
    check_prerequisites
    generate_dhparam
    
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
    
    # Show next steps based on mode
    log_info ""
    case "${MODE_NAME}" in
        staging)
            log_info "Next steps:"
            log_info "1. Configure nginx for HTTPS: ./ssl-configure-nginx.sh ${DOMAIN}"
            log_info "2. Test HTTPS endpoints (expect certificate warnings)"
            log_info "3. If everything works, generate production certificates:"
            log_info "   ./ssl-generate.sh ${DOMAIN} ${EMAIL} --production"
            ;;
        production)
            log_info "Next steps:"
            log_info "1. Configure nginx for HTTPS: ./ssl-configure-nginx.sh ${DOMAIN}"
            log_info "2. Test HTTPS endpoints - they should work without warnings"
            log_info "3. Activate automatic renewal: ./ssl-activate-renewal.sh"
            ;;
    esac
    
    log_success "✅ SSL certificate generation completed successfully!"
}

# Run main function
main "$@"
