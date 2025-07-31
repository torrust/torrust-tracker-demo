#!/bin/bash
# DNS Validation Script for SSL Certificate Setup
#
# This script validates that DNS A records are properly configured
# for SSL certificate generation. It checks that both tracker.DOMAIN
# and grafana.DOMAIN resolve to the current server's IP address.
#
# Usage: ./ssl-validate-dns.sh DOMAIN
#
# Example: ./ssl-validate-dns.sh example.com
#   Will check: tracker.example.com and grafana.example.com

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Source utilities
# shellcheck source=../../../scripts/shell-utils.sh
source "${PROJECT_ROOT}/scripts/shell-utils.sh"

# Validate arguments
if [[ $# -ne 1 ]]; then
    log_error "Usage: $0 DOMAIN"
    log_error "Example: $0 example.com"
    exit 1
fi

DOMAIN="$1"

# Get server's public IP address
get_server_ip() {
    local server_ip=""
    
    # Try multiple methods to get public IP
    if command -v curl >/dev/null 2>&1; then
        server_ip=$(curl -s -4 ifconfig.me 2>/dev/null || true)
    fi
    
    if [[ -z "${server_ip}" ]] && command -v wget >/dev/null 2>&1; then
        server_ip=$(wget -qO- -4 ifconfig.me 2>/dev/null || true)
    fi
    
    if [[ -z "${server_ip}" ]] && command -v dig >/dev/null 2>&1; then
        server_ip=$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null || true)
    fi
    
    if [[ -z "${server_ip}" ]]; then
        log_error "Could not determine server's public IP address"
        log_error "Please ensure curl, wget, or dig is available"
        return 1
    fi
    
    echo "${server_ip}"
}

# Resolve domain to IP address
resolve_domain() {
    local domain="$1"
    local resolved_ip=""
    
    if command -v dig >/dev/null 2>&1; then
        resolved_ip=$(dig +short "${domain}" A 2>/dev/null | head -n1 || true)
    elif command -v nslookup >/dev/null 2>&1; then
        resolved_ip=$(nslookup "${domain}" 2>/dev/null | awk '/^Address: / { print $2 }' | head -n1 || true)
    elif command -v host >/dev/null 2>&1; then
        resolved_ip=$(host "${domain}" 2>/dev/null | awk '/has address/ { print $4 }' | head -n1 || true)
    else
        log_error "No DNS resolution tools available (dig, nslookup, or host required)"
        return 1
    fi
    
    echo "${resolved_ip}"
}

# Validate DNS configuration for a subdomain
validate_subdomain_dns() {
    local subdomain="$1"
    local server_ip="$2"
    
    log_info "Checking DNS for ${subdomain}..."
    
    local resolved_ip
    resolved_ip=$(resolve_domain "${subdomain}")
    
    if [[ -z "${resolved_ip}" ]]; then
        log_error "❌ ${subdomain}: No A record found"
        log_error "   Please add DNS A record: ${subdomain} -> ${server_ip}"
        return 1
    fi
    
    if [[ "${resolved_ip}" != "${server_ip}" ]]; then
        log_error "❌ ${subdomain}: DNS points to ${resolved_ip}, expected ${server_ip}"
        log_error "   Please update DNS A record: ${subdomain} -> ${server_ip}"
        return 1
    fi
    
    log_success "✅ ${subdomain}: DNS correctly points to ${server_ip}"
    return 0
}

# Test HTTP connectivity to verify server is reachable
test_http_connectivity() {
    local subdomain="$1"
    
    log_info "Testing HTTP connectivity for ${subdomain}..."
    
    # Test with curl (with timeout and proper error handling)
    if command -v curl >/dev/null 2>&1; then
        local http_protocol="http"
        if curl -s --connect-timeout 10 --max-time 15 "${http_protocol}://${subdomain}/" >/dev/null 2>&1; then
            log_success "✅ ${subdomain}: HTTP connectivity test passed"
            return 0
        else
            log_warning "⚠️  ${subdomain}: HTTP connectivity test failed"
            log_warning "   This may be normal if the service is not yet configured"
            log_warning "   DNS resolution is correct, proceeding with SSL setup"
            return 0
        fi
    else
        log_info "curl not available, skipping HTTP connectivity test"
        return 0
    fi
}

# Wait for DNS propagation if needed
wait_for_dns_propagation() {
    local domain="$1"
    local server_ip="$2"
    local max_wait=300  # 5 minutes maximum
    local wait_interval=30  # Check every 30 seconds
    local elapsed=0
    
    log_info "Waiting for DNS propagation (max ${max_wait}s)..."
    
    while [[ ${elapsed} -lt ${max_wait} ]]; do
        local resolved_ip
        resolved_ip=$(resolve_domain "${domain}")
        
        if [[ "${resolved_ip}" == "${server_ip}" ]]; then
            log_success "DNS propagation completed for ${domain}"
            return 0
        fi
        
        log_info "DNS not yet propagated for ${domain} (${resolved_ip} != ${server_ip}), waiting..."
        sleep ${wait_interval}
        elapsed=$((elapsed + wait_interval))
    done
    
    log_error "DNS propagation timeout for ${domain}"
    return 1
}

# Main validation function
main() {
    log_info "Starting DNS validation for domain: ${DOMAIN}"
    
    # Get server's public IP
    local server_ip
    server_ip=$(get_server_ip)
    log_info "Server IP: ${server_ip}"
    
    # Define required subdomains
    local subdomains=("tracker.${DOMAIN}" "grafana.${DOMAIN}")
    local validation_failed=false
    
    # Check each subdomain
    for subdomain in "${subdomains[@]}"; do
        if ! validate_subdomain_dns "${subdomain}" "${server_ip}"; then
            validation_failed=true
        fi
    done
    
    # If validation failed, offer to wait for DNS propagation
    if [[ "${validation_failed}" == "true" ]]; then
        log_error ""
        log_error "DNS validation failed for one or more subdomains"
        log_error ""
        log_error "Required DNS configuration:"
        for subdomain in "${subdomains[@]}"; do
            log_error "  ${subdomain} -> ${server_ip}"
        done
        log_error ""
        log_error "Please configure these DNS A records and wait for propagation"
        log_error "DNS propagation can take up to 24 hours but is usually faster"
        log_error ""
        
        # Offer to wait for DNS propagation
        read -p "Wait for DNS propagation? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for subdomain in "${subdomains[@]}"; do
                if ! wait_for_dns_propagation "${subdomain}" "${server_ip}"; then
                    log_error "DNS propagation failed for ${subdomain}"
                    exit 1
                fi
            done
        else
            log_error "DNS validation failed. Please fix DNS configuration and try again."
            exit 1
        fi
    fi
    
    # Test HTTP connectivity (informational)
    log_info ""
    log_info "Testing HTTP connectivity..."
    for subdomain in "${subdomains[@]}"; do
        test_http_connectivity "${subdomain}"
    done
    
    log_info ""
    log_success "✅ DNS validation completed successfully!"
    log_info "All required DNS records are properly configured"
    log_info "SSL certificate generation can proceed"
}

# Run main function
main "$@"
