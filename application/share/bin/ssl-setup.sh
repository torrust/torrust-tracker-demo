#!/bin/bash
# SSL Certificate Setup Script for Torrust Tracker Demo
#
# This script provides a complete SSL setup workflow for enabling HTTPS
# on the Torrust Tracker Demo application. It should be run AFTER the
# standard deployment is complete and running with HTTP-only configuration.
#
# Usage: ./ssl-setup.sh [options]
#
# Options:
#   --domain DOMAIN     Domain name for SSL certificates (required)
#   --email EMAIL       Email for Let's Encrypt registration (required)
#   --staging           Use Let's Encrypt staging environment (default)
#   --production        Use Let's Encrypt production environment
#   --pebble            Use Pebble for local testing
#   --skip-dns          Skip DNS validation (for testing)
#   --help              Show this help message
#
# Examples:
#   ./ssl-setup.sh --domain example.com --email admin@example.com --staging
#   ./ssl-setup.sh --domain example.com --email admin@example.com --production
#   ./ssl-setup.sh --domain test.local --pebble (for local testing)

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECT_ROOT="$(cd "${APP_DIR}/.." && pwd)"

# Source utilities
# shellcheck source=../../../scripts/shell-utils.sh
source "${PROJECT_ROOT}/scripts/shell-utils.sh"

# Default values
DOMAIN=""
EMAIL=""
MODE="staging"
SKIP_DNS_VALIDATION=false
HELP=false

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --domain)
                DOMAIN="$2"
                shift 2
                ;;
            --email)
                EMAIL="$2"
                shift 2
                ;;
            --staging)
                MODE="staging"
                shift
                ;;
            --production)
                MODE="production"
                shift
                ;;
            --pebble)
                MODE="pebble"
                shift
                ;;
            --skip-dns)
                SKIP_DNS_VALIDATION=true
                shift
                ;;
            --help)
                HELP=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Show usage information
show_usage() {
    cat << EOF
SSL Certificate Setup Script for Torrust Tracker Demo

This script enables HTTPS for the Torrust Tracker Demo application by:
1. Validating DNS configuration (unless --skip-dns is used)
2. Generating SSL certificates using Let's Encrypt or Pebble
3. Configuring nginx for HTTPS
4. Activating automatic certificate renewal

USAGE:
    $0 --domain DOMAIN --email EMAIL [options]

REQUIRED ARGUMENTS:
    --domain DOMAIN     Domain name for SSL certificates
    --email EMAIL       Email address for Let's Encrypt registration

OPTIONS:
    --staging           Use Let's Encrypt staging environment (default, recommended for testing)
    --production        Use Let's Encrypt production environment (use only after staging success)
    --pebble            Use Pebble for local testing (no real domain needed)
    --skip-dns          Skip DNS validation (for testing environments)
    --help              Show this help message

EXAMPLES:
    # Test with staging certificates (recommended first step)
    $0 --domain tracker-demo.com --email admin@tracker-demo.com --staging

    # Generate production certificates (after staging success)
    $0 --domain tracker-demo.com --email admin@tracker-demo.com --production

    # Local testing with Pebble
    $0 --domain test.local --email test@test.local --pebble

PREREQUISITES:
    1. Torrust Tracker Demo must be deployed and running (HTTP-only)
    2. Domain DNS A records must point to this server (tracker.DOMAIN, grafana.DOMAIN)
    3. Ports 80 and 443 must be accessible from the internet
    4. Docker and Docker Compose must be installed and running

WORKFLOW:
    1. Run with --staging first to test the complete workflow
    2. If staging succeeds, run with --production for real certificates
    3. HTTPS will be enabled for both tracker.DOMAIN and grafana.DOMAIN

NOTE: This script does not modify the core deployment. It only adds HTTPS
configuration on top of the existing HTTP deployment.

EOF
}

# Validate required arguments
validate_arguments() {
    if [[ "${HELP}" == "true" ]]; then
        show_usage
        exit 0
    fi

    if [[ -z "${DOMAIN}" ]]; then
        log_error "Domain name is required. Use --domain DOMAIN"
        show_usage
        exit 1
    fi

    if [[ -z "${EMAIL}" && "${MODE}" != "pebble" ]]; then
        log_error "Email address is required for Let's Encrypt. Use --email EMAIL"
        show_usage
        exit 1
    fi

    # Set default email for Pebble mode
    if [[ "${MODE}" == "pebble" && -z "${EMAIL}" ]]; then
        EMAIL="test@${DOMAIN}"
    fi

    # Validate domain format (basic check)
    if [[ ! "${DOMAIN}" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]]; then
        log_error "Invalid domain format: ${DOMAIN}"
        exit 1
    fi

    # Validate email format (basic check)
    if [[ ! "${EMAIL}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "Invalid email format: ${EMAIL}"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if we're in the application directory
    if [[ ! -f "${APP_DIR}/compose.yaml" ]]; then
        log_error "This script must be run from the application directory"
        log_error "Expected to find compose.yaml at: ${APP_DIR}/compose.yaml"
        exit 1
    fi

    # Check if Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi

    # Check if Docker Compose is available
    if ! docker compose version >/dev/null 2>&1; then
        log_error "Docker Compose is not available"
        exit 1
    fi

    # Check if main services are running (for production/staging)
    if [[ "${MODE}" != "pebble" ]]; then
        if ! docker compose ps | grep -q "Up"; then
            log_error "Docker Compose services are not running"
            log_error "Please run 'docker compose up -d' first"
            exit 1
        fi
    fi

    log_success "Prerequisites check passed"
}

# Main SSL setup workflow
main() {
    parse_arguments "$@"
    validate_arguments
    
    log_info "Starting SSL setup for domain: ${DOMAIN}"
    log_info "Mode: ${MODE}"
    log_info "Email: ${EMAIL}"
    
    check_prerequisites

    cd "${APP_DIR}"

    # Step 1: DNS validation (unless skipped or using Pebble)
    if [[ "${SKIP_DNS_VALIDATION}" == "false" && "${MODE}" != "pebble" ]]; then
        log_info "Step 1: Validating DNS configuration..."
        "${SCRIPT_DIR}/ssl-validate-dns.sh" "${DOMAIN}"
    else
        log_info "Step 1: Skipping DNS validation (${MODE} mode or --skip-dns)"
    fi

    # Step 2: Generate SSL certificates
    log_info "Step 2: Generating SSL certificates..."
    "${SCRIPT_DIR}/ssl-generate.sh" "${DOMAIN}" "${EMAIL}" "--${MODE}"

    # Step 3: Configure nginx for HTTPS
    log_info "Step 3: Configuring nginx for HTTPS..."
    "${SCRIPT_DIR}/ssl-configure-nginx.sh" "${DOMAIN}"

    # Step 4: Activate automatic renewal (only for production/staging)
    if [[ "${MODE}" != "pebble" ]]; then
        log_info "Step 4: Activating automatic certificate renewal..."
        "${SCRIPT_DIR}/ssl-activate-renewal.sh"
    else
        log_info "Step 4: Skipping renewal activation (Pebble mode)"
    fi

    # Step 5: Final validation
    log_info "Step 5: Validating HTTPS configuration..."
    sleep 5  # Give nginx time to reload

    if [[ "${MODE}" == "pebble" ]]; then
        log_success "✅ SSL setup completed successfully (Pebble mode)!"
        log_info ""
        log_info "HTTPS endpoints are now available:"
        log_info "  - https://tracker.${DOMAIN} (use Pebble CA for verification)"
        log_info "  - https://grafana.${DOMAIN} (use Pebble CA for verification)"
        log_info ""
        log_info "To test with curl:"
        log_info "  curl --cacert /tmp/pebble.minica.pem https://tracker.${DOMAIN}/api/health_check"
        log_info ""
        log_info "To clean up Pebble test environment:"
        log_info "  docker compose -f compose.test.yaml down -v"
    elif [[ "${MODE}" == "staging" ]]; then
        log_success "✅ SSL setup completed successfully (Staging mode)!"
        log_info ""
        log_info "HTTPS endpoints are now available:"
        log_info "  - https://tracker.${DOMAIN}"
        log_info "  - https://grafana.${DOMAIN}"
        log_info ""
        log_warning "NOTE: These are STAGING certificates and will show security warnings"
        log_info "This is expected and normal for testing purposes"
        log_info ""
        log_info "If everything works correctly, run with --production to get real certificates:"
        log_info "  $0 --domain ${DOMAIN} --email ${EMAIL} --production"
    else
        log_success "✅ SSL setup completed successfully (Production mode)!"
        log_info ""
        log_info "HTTPS endpoints are now available:"
        log_info "  - https://tracker.${DOMAIN}"
        log_info "  - https://grafana.${DOMAIN}"
        log_info ""
        log_info "Automatic certificate renewal is active"
        log_info "Certificates will be renewed automatically 30 days before expiration"
    fi

    log_info ""
    log_info "HTTP endpoints remain available for certificate renewal:"
    # Note: HTTP URLs are intentionally used here for Let's Encrypt ACME challenge
    local http_protocol="http"
    log_info "  - ${http_protocol}://tracker.${DOMAIN} (required for certificate renewal)"
    log_info "  - ${http_protocol}://grafana.${DOMAIN} (required for certificate renewal)"
}

# Run main function
main "$@"
