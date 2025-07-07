#!/bin/bash
# Integration test script for Torrust Tracker deployment
# Tests the complete deployment workflow in the VM

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/infrastructure/terraform"
TEST_LOG_FILE="/tmp/torrust-integration-test.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "$1" | tee -a "${TEST_LOG_FILE}"
}

log_info() {
    log "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    log "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    log "${RED}[ERROR]${NC} $1"
}

# Get VM IP from Terraform output
get_vm_ip() {
    cd "${TERRAFORM_DIR}"
    local vm_ip
    vm_ip=$(tofu output -raw vm_ip 2>/dev/null || echo "")

    if [ -z "${vm_ip}" ]; then
        log_error "Could not get VM IP from OpenTofu output"
        return 1
    fi

    echo "${vm_ip}"
}

# Execute command on VM via SSH
vm_exec() {
    local vm_ip="$1"
    local command="$2"
    local description="${3:-}"

    if [ -n "${description}" ]; then
        log_info "${description}"
    fi

    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30 torrust@"${vm_ip}" "${command}"
}

# Detect which Docker Compose command is available
get_docker_compose_cmd() {
    local vm_ip="$1"

    if vm_exec "${vm_ip}" "docker compose version >/dev/null 2>&1" ""; then
        echo "docker compose"
    elif vm_exec "${vm_ip}" "docker-compose --version >/dev/null 2>&1" ""; then
        echo "docker-compose"
    else
        echo ""
    fi
}

# Test VM is accessible
test_vm_access() {
    log_info "Testing VM access..."

    local vm_ip
    vm_ip=$(get_vm_ip)

    if vm_exec "${vm_ip}" "echo 'VM is accessible'" "Checking SSH connectivity"; then
        log_success "VM is accessible at ${vm_ip}"
        return 0
    else
        log_error "Cannot access VM"
        return 1
    fi
}

# Test Docker is working
test_docker() {
    log_info "Testing Docker installation..."

    local vm_ip
    vm_ip=$(get_vm_ip)

    if vm_exec "${vm_ip}" "docker --version" "Checking Docker version"; then
        log_success "Docker is installed and working"
    else
        log_error "Docker is not working"
        return 1
    fi

    # Check Docker Compose (try V2 plugin first, then fallback to standalone)
    if vm_exec "${vm_ip}" "docker compose version" "Checking Docker Compose V2 plugin"; then
        log_success "Docker Compose V2 plugin is available"
    elif vm_exec "${vm_ip}" "docker-compose --version" "Checking Docker Compose standalone"; then
        log_success "Docker Compose standalone is available"
        log_warning "Using standalone docker-compose. Consider upgrading to Docker Compose V2 plugin for full compatibility."
    else
        log_error "Docker Compose is not working"
        return 1
    fi

    return 0
}

# Clone and setup Torrust Tracker Demo
setup_torrust_tracker() {
    log_info "Setting up Torrust Tracker Demo..."

    local vm_ip
    vm_ip=$(get_vm_ip)

    # Check if already cloned
    if vm_exec "${vm_ip}" "test -d /home/torrust/github/torrust/torrust-tracker-demo" "Checking if repo exists"; then
        log_info "Repository already exists, updating..."
        vm_exec "${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo && git pull" "Updating repository"
    else
        log_info "Cloning repository..."
        vm_exec "${vm_ip}" "mkdir -p /home/torrust/github/torrust" "Creating directory structure"
        vm_exec "${vm_ip}" "cd /home/torrust/github/torrust && git clone https://github.com/torrust/torrust-tracker-demo.git" "Cloning repository"
    fi

    # Setup environment file
    vm_exec "${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo && cp .env.production .env" "Setting up environment file"

    log_success "Torrust Tracker Demo setup completed"
    return 0
}

# Start Torrust Tracker services
start_tracker_services() {
    log_info "Starting Torrust Tracker services..."

    local vm_ip
    vm_ip=$(get_vm_ip)

    # Detect which Docker Compose command to use
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd "${vm_ip}")

    if [ -z "${compose_cmd}" ]; then
        log_error "Docker Compose is not available"
        return 1
    fi

    log_info "Using Docker Compose command: ${compose_cmd}"

    # Pull latest images
    vm_exec "${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo && ${compose_cmd} pull" "Pulling Docker images"

    # Start services
    vm_exec "${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo && ${compose_cmd} up -d" "Starting services"

    # Wait for services to be ready
    log_info "Waiting for services to be ready..."
    sleep 30

    # Check service status
    if vm_exec "${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo && ${compose_cmd} ps" "Checking service status"; then
        log_success "Services started successfully"
    else
        log_error "Services failed to start properly"
        return 1
    fi

    return 0
}

# Test Torrust Tracker endpoints
test_tracker_endpoints() {
    log_info "Testing Torrust Tracker endpoints..."

    local vm_ip
    vm_ip=$(get_vm_ip)

    # Test HTTP API endpoint
    log_info "Testing HTTP API endpoint..."
    if vm_exec "${vm_ip}" "curl -f -s http://localhost:7070/api/v1/stats" "Checking HTTP API"; then
        log_success "HTTP API is responding"
    else
        log_error "HTTP API is not responding"
        return 1
    fi

    # Test metrics endpoint
    log_info "Testing metrics endpoint..."
    if vm_exec "${vm_ip}" "curl -f -s http://localhost:1212/metrics" "Checking metrics endpoint"; then
        log_success "Metrics endpoint is responding"
    else
        log_error "Metrics endpoint is not responding"
        return 1
    fi

    # Test if UDP ports are listening
    log_info "Testing UDP tracker ports..."
    if vm_exec "${vm_ip}" "ss -ul | grep -E ':6868|:6969'" "Checking UDP ports"; then
        log_success "UDP tracker ports are listening"
    else
        log_warning "UDP tracker ports might not be listening (this is expected if no peers are connected)"
    fi

    return 0
}

# Test monitoring services
test_monitoring() {
    log_info "Testing monitoring services..."

    local vm_ip
    vm_ip=$(get_vm_ip)

    # Test Prometheus
    log_info "Testing Prometheus..."
    if vm_exec "${vm_ip}" "curl -f -s http://localhost:9090/-/healthy" "Checking Prometheus health"; then
        log_success "Prometheus is healthy"
    else
        log_error "Prometheus is not healthy"
        return 1
    fi

    # Test Grafana
    log_info "Testing Grafana..."
    if vm_exec "${vm_ip}" "curl -f -s http://localhost:3100/api/health" "Checking Grafana health"; then
        log_success "Grafana is healthy"
    else
        log_error "Grafana is not healthy"
        return 1
    fi

    return 0
}

# Collect logs for debugging
collect_logs() {
    log_info "Collecting logs for debugging..."

    local vm_ip
    vm_ip=$(get_vm_ip)

    # Docker logs
    vm_exec "${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo && docker compose logs --tail=50" "Collecting Docker logs"

    # System logs
    vm_exec "${vm_ip}" "sudo journalctl --since='1 hour ago' --no-pager | tail -50" "Collecting system logs"

    return 0
}

# Stop services
stop_services() {
    log_info "Stopping Torrust Tracker services..."

    local vm_ip
    vm_ip=$(get_vm_ip)

    # Detect which Docker Compose command to use
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd "${vm_ip}")

    if [ -n "${compose_cmd}" ]; then
        vm_exec "${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo && ${compose_cmd} down" "Stopping services"
    else
        log_warning "Docker Compose not available, cannot stop services"
    fi

    log_success "Services stopped"
    return 0
}

# Run full integration test
run_integration_test() {
    log_info "Starting Torrust Tracker integration test..."
    echo "Test started at: $(date)" >"${TEST_LOG_FILE}"

    local failed=0

    test_vm_access || failed=1

    if [ ${failed} -eq 0 ]; then
        test_docker || failed=1
        setup_torrust_tracker || failed=1
        start_tracker_services || failed=1
        test_tracker_endpoints || failed=1
        test_monitoring || failed=1
    fi

    # Always collect logs if there were failures
    if [ ${failed} -ne 0 ]; then
        log_warning "Test failed, collecting logs for debugging..."
        collect_logs || true
    fi

    # Always try to stop services
    stop_services || log_warning "Failed to stop services cleanly"

    if [ ${failed} -eq 0 ]; then
        log_success "All integration tests passed!"
        return 0
    else
        log_error "Integration tests failed. Check ${TEST_LOG_FILE} for details."
        return 1
    fi
}

# Help function
show_help() {
    cat <<EOF
Torrust Tracker Integration Test Script

Usage: $0 [COMMAND]

Commands:
    full-test       Run complete integration test (default)
    access          Test VM access only
    docker          Test Docker functionality only
    setup           Setup Torrust Tracker only
    start           Start services only
    endpoints       Test endpoints only
    monitoring      Test monitoring only
    logs            Collect logs only
    stop            Stop services only
    help           Show this help message

Examples:
    $0                    # Run full integration test
    $0 access            # Test if VM is accessible
    $0 start             # Start Torrust Tracker services
    $0 endpoints         # Test if endpoints are responding

Note: This script assumes a VM is already deployed using 'make apply'

Test log is written to: ${TEST_LOG_FILE}
EOF
}

# Main execution
main() {
    local command="${1:-full-test}"

    case "${command}" in
    "full-test")
        run_integration_test
        ;;
    "access")
        test_vm_access
        ;;
    "docker")
        test_docker
        ;;
    "setup")
        setup_torrust_tracker
        ;;
    "start")
        start_tracker_services
        ;;
    "endpoints")
        test_tracker_endpoints
        ;;
    "monitoring")
        test_monitoring
        ;;
    "logs")
        collect_logs
        ;;
    "stop")
        stop_services
        ;;
    "help" | "-h" | "--help")
        show_help
        ;;
    *)
        log_error "Unknown command: ${command}"
        show_help
        exit 1
        ;;
    esac
}

# Run main function with all arguments
main "$@"
