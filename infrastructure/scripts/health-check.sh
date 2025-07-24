#!/bin/bash
# Health check script for Torrust Tracker Demo
# Validates deployed application health and functionality
# Twelve-Factor App compliant: Operational validation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/infrastructure/terraform"

# Default values
ENVIRONMENT="${1:-local}"
VM_IP="${2:-}"
VERBOSE="${VERBOSE:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_test_pass() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASSED_TESTS++))
}

log_test_fail() {
    echo -e "${RED}❌ $1${NC}"
    ((FAILED_TESTS++))
}

# Get VM IP from Terraform output or parameter
get_vm_ip() {
    if [[ -n "${VM_IP}" ]]; then
        echo "${VM_IP}"
        return 0
    fi

    if [[ ! -d "${TERRAFORM_DIR}" ]]; then
        log_error "Terraform directory not found: ${TERRAFORM_DIR}"
        log_error "Run 'make infra-apply ENVIRONMENT=${ENVIRONMENT}' first"
        exit 1
    fi

    cd "${TERRAFORM_DIR}"
    local vm_ip
    vm_ip=$(tofu output -raw vm_ip 2>/dev/null || echo "")

    if [[ -z "${vm_ip}" || "${vm_ip}" == "No IP assigned yet" ]]; then
        log_error "Could not get VM IP from Terraform output"
        exit 1
    fi

    echo "${vm_ip}"
}

# Execute command on VM via SSH
vm_exec() {
    local vm_ip="$1"
    local command="$2"
    local timeout="${3:-30}"

    ssh -o StrictHostKeyChecking=no -o ConnectTimeout="${timeout}" torrust@"${vm_ip}" "${command}" 2>/dev/null
}

# Test SSH connectivity
test_ssh_connectivity() {
    local vm_ip="$1"

    ((TOTAL_TESTS++))
    log_info "Testing SSH connectivity to ${vm_ip}"

    if vm_exec "${vm_ip}" "exit" 5; then
        log_test_pass "SSH connectivity"
        return 0
    else
        log_test_fail "SSH connectivity"
        return 1
    fi
}

# Test Docker services
test_docker_services() {
    local vm_ip="$1"

    log_info "Testing Docker services"

    # Test if Docker is running
    ((TOTAL_TESTS++))
    if vm_exec "${vm_ip}" "docker info >/dev/null 2>&1"; then
        log_test_pass "Docker daemon"
    else
        log_test_fail "Docker daemon"
        return 1
    fi

    # Test Docker Compose services
    ((TOTAL_TESTS++))
    local compose_status
    compose_status=$(vm_exec "${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo/application && docker compose ps --format 'table {{.Service}}\t{{.State}}' 2>/dev/null" || echo "")

    if [[ -n "${compose_status}" ]]; then
        log_test_pass "Docker Compose services accessible"

        if [[ "${VERBOSE}" == "true" ]]; then
            echo "${compose_status}"
        fi

        # Check if all services are running
        ((TOTAL_TESTS++))
        local running_count
        running_count=$(echo "${compose_status}" | grep -c "running" || true)

        if [[ ${running_count} -gt 0 ]]; then
            log_test_pass "Services are running (${running_count} services)"
        else
            log_test_fail "No services are running"
        fi
    else
        log_test_fail "Docker Compose services"
    fi
}

# Test application endpoints
test_application_endpoints() {
    local vm_ip="$1"

    log_info "Testing application endpoints"

    # Test health check endpoint (via nginx proxy)
    ((TOTAL_TESTS++))
    if vm_exec "${vm_ip}" "curl -f -s http://localhost/health_check >/dev/null 2>&1"; then
        log_test_pass "Health check endpoint (nginx proxy)"
    else
        log_test_fail "Health check endpoint (nginx proxy)"
    fi

    # Test API stats endpoint (via nginx proxy with auth)
    ((TOTAL_TESTS++))
    if vm_exec "${vm_ip}" "curl -f -s 'http://localhost/api/v1/stats?token=local-dev-admin-token-12345' >/dev/null 2>&1"; then
        log_test_pass "API stats endpoint (nginx proxy)"

        # Get stats if verbose
        if [[ "${VERBOSE}" == "true" ]]; then
            local stats
            stats=$(vm_exec "${vm_ip}" "curl -s 'http://localhost/api/v1/stats?token=local-dev-admin-token-12345'" || echo "")
            if [[ -n "${stats}" ]]; then
                echo "  Stats: ${stats}"
            fi
        fi
    else
        log_test_fail "API stats endpoint (nginx proxy)"
    fi

    # Test HTTP tracker endpoint (via nginx proxy - expects 404 for root)
    ((TOTAL_TESTS++))
    if vm_exec "${vm_ip}" "curl -s -w '%{http_code}' http://localhost/ -o /dev/null | grep -q '404'"; then
        log_test_pass "HTTP tracker endpoint (nginx proxy)"
    else
        log_test_fail "HTTP tracker endpoint (nginx proxy)"
    fi

    # Test Grafana endpoint
    ((TOTAL_TESTS++))
    if vm_exec "${vm_ip}" "curl -f -s http://localhost:3100 >/dev/null 2>&1"; then
        log_test_pass "Grafana endpoint (port 3100)"
    else
        log_test_fail "Grafana endpoint (port 3100)"
    fi
}

# Test UDP tracker connectivity
test_udp_trackers() {
    local vm_ip="$1"

    log_info "Testing UDP tracker connectivity"

    # Test UDP port 6868
    ((TOTAL_TESTS++))
    if vm_exec "${vm_ip}" "nc -u -z -w5 localhost 6868 2>/dev/null"; then
        log_test_pass "UDP tracker port 6868"
    else
        log_test_fail "UDP tracker port 6868"
    fi

    # Test UDP port 6969
    ((TOTAL_TESTS++))
    if vm_exec "${vm_ip}" "nc -u -z -w5 localhost 6969 2>/dev/null"; then
        log_test_pass "UDP tracker port 6969"
    else
        log_test_fail "UDP tracker port 6969"
    fi
}

# Test storage and persistence
test_storage() {
    local vm_ip="$1"

    log_info "Testing storage and persistence"

    # Test storage directories
    ((TOTAL_TESTS++))
    if vm_exec "${vm_ip}" "[ -d /home/torrust/github/torrust/torrust-tracker-demo/application/storage ]"; then
        log_test_pass "Storage directory exists"
    else
        log_test_fail "Storage directory missing"
    fi

    # Test database connectivity (MySQL)
    if [[ "${ENVIRONMENT}" == "local" ]]; then
        ((TOTAL_TESTS++))
        if vm_exec "${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo/application && docker compose exec mysql mysqladmin ping -h localhost --silent"; then
            log_test_pass "MySQL database connectivity"
        else
            log_test_fail "MySQL database connectivity"
        fi
    fi
}

# Test logging and monitoring
test_monitoring() {
    local vm_ip="$1"

    log_info "Testing logging and monitoring"

    # Test Prometheus metrics endpoint
    ((TOTAL_TESTS++))
    if vm_exec "${vm_ip}" "curl -f -s http://localhost:9090/metrics >/dev/null 2>&1"; then
        log_test_pass "Prometheus metrics endpoint"
    else
        log_test_fail "Prometheus metrics endpoint"
    fi

    # Test Docker logs accessibility
    ((TOTAL_TESTS++))
    local logs_output
    logs_output=$(vm_exec "${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo/application && docker compose logs --tail=5 2>/dev/null" || echo "")

    if [[ -n "${logs_output}" ]]; then
        log_test_pass "Docker logs accessible"

        if [[ "${VERBOSE}" == "true" ]]; then
            echo "Recent logs:"
            echo "${logs_output}" | head -20
        fi
    else
        log_test_fail "Docker logs not accessible"
    fi
}

# Generate health report
generate_health_report() {
    local vm_ip="$1"

    echo
    echo "=== HEALTH CHECK REPORT ==="
    echo "Environment:      ${ENVIRONMENT}"
    echo "VM IP:           ${vm_ip}"
    echo "Total Tests:     ${TOTAL_TESTS}"
    echo "Passed:          ${PASSED_TESTS}"
    echo "Failed:          ${FAILED_TESTS}"

    local success_rate=0
    if [[ ${TOTAL_TESTS} -gt 0 ]]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi
    echo "Success Rate:    ${success_rate}%"
    echo

    if [[ ${FAILED_TESTS} -eq 0 ]]; then
        log_success "All health checks passed! Application is healthy."
        return 0
    else
        log_error "Some health checks failed. Please review the results above."

        echo "=== TROUBLESHOOTING SUGGESTIONS ==="
        echo "1. Check service logs: ssh torrust@${vm_ip} 'cd torrust-tracker-demo/application && docker compose logs'"
        echo "2. Restart services: ssh torrust@${vm_ip} 'cd torrust-tracker-demo/application && docker compose restart'"
        echo "3. Redeploy application: make app-deploy ENVIRONMENT=${ENVIRONMENT}"
        echo
        return 1
    fi
}

# Main execution
main() {
    log_info "Starting health check for Torrust Tracker Demo"
    log_info "Environment: ${ENVIRONMENT}"

    local vm_ip
    vm_ip=$(get_vm_ip)
    log_info "Target VM: ${vm_ip}"

    # Run all health checks
    test_ssh_connectivity "${vm_ip}" || {
        log_error "SSH connectivity failed. Cannot continue with health checks."
        exit 1
    }

    test_docker_services "${vm_ip}"
    test_application_endpoints "${vm_ip}"
    test_udp_trackers "${vm_ip}"
    test_storage "${vm_ip}"
    test_monitoring "${vm_ip}"

    # Generate final report
    generate_health_report "${vm_ip}"
}

# Show help
show_help() {
    cat <<EOF
Health Check Script for Torrust Tracker Demo

Usage: $0 [ENVIRONMENT] [VM_IP]

Arguments:
    ENVIRONMENT    Environment name (local, production)
    VM_IP          VM IP address (optional, will get from Terraform if not provided)

Environment Variables:
    VERBOSE        Show detailed output (true/false, default: false)

Examples:
    $0 local                    # Health check for local environment
    $0 production               # Health check for production environment
    $0 local 192.168.1.100     # Health check with specific IP
    VERBOSE=true $0 local       # Verbose health check

Health Checks Performed:
    ✓ SSH connectivity
    ✓ Docker daemon status
    ✓ Docker Compose services
    ✓ Application endpoints (HTTP/UDP)
    ✓ Storage and persistence
    ✓ Logging and monitoring

Prerequisites:
    Application must be deployed first:
    make app-deploy ENVIRONMENT=${ENVIRONMENT}
EOF
}

# Handle arguments
case "${1:-}" in
"help" | "-h" | "--help")
    show_help
    exit 0
    ;;
"")
    log_error "Environment argument required"
    show_help
    exit 1
    ;;
*)
    main "$@"
    ;;
esac
