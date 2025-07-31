#!/bin/bash
# SSL Certificate Renewal Activation Script for Torrust Tracker Demo
#
# This script activates automatic SSL certificate renewal by installing
# the SSL renewal cron job. It should only be run AFTER SSL certificates
# have been successfully generated and nginx is configured for HTTPS.
#
# Usage: ./ssl-activate-renewal.sh [options]
#
# Options:
#   --force     Force installation even if certificates don't exist
#   --remove    Remove SSL renewal cron job
#   --status    Show current renewal status
#   --help      Show this help message

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Source utilities
# shellcheck source=../../../scripts/shell-utils.sh
source "${PROJECT_ROOT}/scripts/shell-utils.sh"

# Default values
FORCE=false
REMOVE=false
STATUS=false
HELP=false

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE=true
                shift
                ;;
            --remove)
                REMOVE=true
                shift
                ;;
            --status)
                STATUS=true
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
SSL Certificate Renewal Activation Script

This script manages automatic SSL certificate renewal for the Torrust Tracker Demo.
It installs or manages cron jobs for automatic certificate renewal.

USAGE:
    $0 [options]

OPTIONS:
    --force     Force installation even if certificates don't exist (not recommended)
    --remove    Remove SSL renewal cron job
    --status    Show current renewal status
    --help      Show this help message

EXAMPLES:
    # Activate SSL renewal (recommended after successful SSL setup)
    $0

    # Check current renewal status
    $0 --status

    # Remove SSL renewal
    $0 --remove

PREREQUISITES:
    1. SSL certificates must be generated and working
    2. Nginx must be configured for HTTPS
    3. Docker Compose services must be running

SAFETY:
    This script validates that SSL certificates exist before activating renewal.
    Use --force to bypass this check (not recommended).

EOF
}

# Check if SSL certificates exist and are valid
check_ssl_certificates() {
    log_info "Checking SSL certificate status..."
    
    local cert_found=false
    local cert_dirs
    
    # Look for any SSL certificates in the expected location
    if docker compose exec proxy find /etc/letsencrypt/live -name "fullchain.pem" -type f 2>/dev/null | grep -q "fullchain.pem"; then
        cert_found=true
        cert_dirs=$(docker compose exec proxy find /etc/letsencrypt/live -name "fullchain.pem" -type f 2>/dev/null | sed 's|/fullchain.pem||' | sed 's|.*/||')
        
        log_info "Found SSL certificates for:"
        while IFS= read -r domain; do
            if [[ -n "${domain}" ]]; then
                log_info "  - ${domain}"
                
                # Check certificate expiration
                local expiry
                expiry=$(docker compose exec proxy openssl x509 -in "/etc/letsencrypt/live/${domain}/cert.pem" -noout -enddate 2>/dev/null | cut -d= -f2 || echo "Unable to determine")
                log_info "    Expires: ${expiry}"
            fi
        done <<< "${cert_dirs}"
    fi
    
    if [[ "${cert_found}" == "false" ]]; then
        if [[ "${FORCE}" == "true" ]]; then
            log_warning "No SSL certificates found, but --force specified"
            log_warning "Proceeding with renewal activation (may fail during renewal)"
            return 0
        else
            log_error "No SSL certificates found"
            log_error "Please generate SSL certificates first before activating renewal"
            log_error "Use ./ssl-generate.sh to create certificates"
            log_error "Or use --force to bypass this check (not recommended)"
            exit 1
        fi
    fi
    
    log_success "SSL certificates validation passed"
    return 0
}

# Check if renewal cron job is already installed
check_renewal_status() {
    log_info "Checking SSL renewal status..."
    
    if crontab -l 2>/dev/null | grep -q "ssl_renew.sh"; then
        log_info "SSL renewal cron job is ACTIVE"
        
        # Show the actual cron job
        local cron_line
        cron_line=$(crontab -l 2>/dev/null | grep "ssl_renew.sh" || echo "")
        if [[ -n "${cron_line}" ]]; then
            log_info "Current cron job: ${cron_line}"
        fi
        
        return 0
    else
        log_info "SSL renewal cron job is NOT ACTIVE"
        return 1
    fi
}

# Install SSL renewal cron job
install_renewal_cronjob() {
    log_info "Installing SSL renewal cron job..."
    
    local ssl_renew_script="${SCRIPT_DIR}/ssl_renew.sh"
    local log_file="/var/log/ssl-renewal.log"
    
    # Check if ssl_renew.sh exists
    if [[ ! -f "${ssl_renew_script}" ]]; then
        log_error "SSL renewal script not found: ${ssl_renew_script}"
        exit 1
    fi
    
    # Create the cron job entry
    # Run daily at 2:00 AM with full logging
    local cron_entry="0 2 * * * ${ssl_renew_script} >> ${log_file} 2>&1"
    
    # Get current crontab (ignore errors if no crontab exists)
    local temp_cron
    temp_cron=$(mktemp)
    crontab -l 2>/dev/null > "${temp_cron}" || true
    
    # Check if SSL renewal job already exists
    if grep -q "ssl_renew.sh" "${temp_cron}" 2>/dev/null; then
        log_info "SSL renewal cron job already exists"
        log_info "Current entry:"
        grep "ssl_renew.sh" "${temp_cron}"
        rm -f "${temp_cron}"
        return 0
    fi
    
    # Add the SSL renewal cron job
    echo "${cron_entry}" >> "${temp_cron}"
    
    # Install the new crontab
    if crontab "${temp_cron}"; then
        log_success "SSL renewal cron job installed successfully"
        log_info "Renewal schedule: Daily at 2:00 AM"
        log_info "Log file: ${log_file}"
    else
        log_error "Failed to install SSL renewal cron job"
        rm -f "${temp_cron}"
        exit 1
    fi
    
    rm -f "${temp_cron}"
}

# Remove SSL renewal cron job
remove_renewal_cronjob() {
    log_info "Removing SSL renewal cron job..."
    
    # Get current crontab
    local temp_cron
    temp_cron=$(mktemp)
    
    if crontab -l 2>/dev/null > "${temp_cron}"; then
        # Remove SSL renewal entries
        if grep -v "ssl_renew.sh" "${temp_cron}" > "${temp_cron}.new"; then
            mv "${temp_cron}.new" "${temp_cron}"
            
            # Install the modified crontab
            if crontab "${temp_cron}"; then
                log_success "SSL renewal cron job removed successfully"
            else
                log_error "Failed to update crontab"
                rm -f "${temp_cron}" "${temp_cron}.new"
                exit 1
            fi
        else
            log_info "No SSL renewal cron job found to remove"
        fi
    else
        log_info "No crontab found, nothing to remove"
    fi
    
    rm -f "${temp_cron}" "${temp_cron}.new"
}

# Test SSL renewal (dry run)
test_ssl_renewal() {
    log_info "Testing SSL certificate renewal (dry run)..."
    
    if docker compose run --rm certbot renew --dry-run; then
        log_success "SSL renewal test passed"
        log_info "Automatic renewal should work correctly"
    else
        log_error "SSL renewal test failed"
        log_error "Please check SSL certificate configuration and try again"
        return 1
    fi
}

# Show renewal status and information
show_renewal_info() {
    log_info ""
    log_info "SSL Certificate Renewal Information:"
    log_info ""
    
    # Check renewal status
    if check_renewal_status; then
        log_info "Status: ✅ ACTIVE"
    else
        log_info "Status: ❌ NOT ACTIVE"
    fi
    
    # Show renewal script location
    local ssl_renew_script="${SCRIPT_DIR}/ssl_renew.sh"
    if [[ -f "${ssl_renew_script}" ]]; then
        log_info "Renewal script: ${ssl_renew_script}"
    else
        log_warning "Renewal script: NOT FOUND (${ssl_renew_script})"
    fi
    
    # Show log file location
    log_info "Log file: /var/log/ssl-renewal.log"
    
    # Show certificate information
    check_ssl_certificates 2>/dev/null || log_info "Certificates: No certificates found"
    
    log_info ""
    log_info "To check renewal logs:"
    log_info "  tail -f /var/log/ssl-renewal.log"
    log_info ""
    log_info "To test renewal manually:"
    log_info "  docker compose run --rm certbot renew --dry-run"
}

# Main function
main() {
    parse_arguments "$@"
    
    if [[ "${HELP}" == "true" ]]; then
        show_usage
        exit 0
    fi
    
    if [[ "${STATUS}" == "true" ]]; then
        show_renewal_info
        exit 0
    fi
    
    if [[ "${REMOVE}" == "true" ]]; then
        remove_renewal_cronjob
        log_info ""
        log_info "SSL automatic renewal has been deactivated"
        exit 0
    fi
    
    # Default action: install/activate renewal
    log_info "Activating SSL certificate automatic renewal..."
    
    # Check if we're in the application directory
    if [[ ! -f "compose.yaml" ]]; then
        log_error "This script must be run from the application directory"
        log_error "Expected to find compose.yaml in current directory"
        exit 1
    fi
    
    # Check if Docker services are running
    if ! docker compose ps | grep -q "Up"; then
        log_error "Docker Compose services are not running"
        log_error "Please start services first: docker compose up -d"
        exit 1
    fi
    
    # Check SSL certificates (unless --force)
    if [[ "${FORCE}" == "false" ]]; then
        check_ssl_certificates
    fi
    
    # Test renewal before installing cron job
    if ! test_ssl_renewal; then
        log_error "SSL renewal test failed"
        log_error "Please fix SSL configuration before activating automatic renewal"
        exit 1
    fi
    
    # Install renewal cron job
    install_renewal_cronjob
    
    log_info ""
    log_success "✅ SSL certificate automatic renewal activated successfully!"
    log_info ""
    log_info "Renewal schedule: Daily at 2:00 AM"
    log_info "Log file: /var/log/ssl-renewal.log"
    log_info ""
    log_info "Certificates will be automatically renewed 30 days before expiration"
    log_info "Nginx will be automatically restarted after successful renewal"
    log_info ""
    log_info "To check renewal status:"
    log_info "  $0 --status"
    log_info ""
    log_info "To monitor renewal logs:"
    log_info "  tail -f /var/log/ssl-renewal.log"
}

# Run main function
main "$@"
