#!/bin/bash
# Integration test script for Torrust Tracker deployment
# Tests the complete deployment workflow in the VM
#
# IMPORTANT: This script copies the current local repository to the VM
# to test exactly the changes being developed. This ensures we test our
# modifications rather than the published main branch.
#
# For testing against the published repository (e.g., for E2E tests of
# released versions), consider creating a separate script that clones
# from GitHub instead of copying local files.

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

# Setup local Torrust Tracker Demo repository following 12-factor principles
# This function:
# 1. Creates a git archive of the current repository (only tracked files)
# 2. Copies it to the VM to test the exact version being developed
# 3. Runs the infrastructure configuration system to generate config files
# 4. Executes the official installation script
# 5. Copies the configured storage folder to the VM
setup_torrust_tracker() {
    log_info "Setting up Torrust Tracker Demo (using 12-factor configuration approach)..."

    local vm_ip
    vm_ip=$(get_vm_ip)

    # Step 1: Create git archive of tracked files only
    log_info "Creating git archive of tracked files..."
    local temp_archive
    temp_archive="/tmp/torrust-tracker-demo-$(date +%s).tar.gz"

    cd "${PROJECT_ROOT}"
    if ! git archive --format=tar.gz --output="${temp_archive}" HEAD; then
        log_error "Failed to create git archive"
        return 1
    fi

    log_success "Git archive created: ${temp_archive}"

    # Step 2: Copy git archive to VM and extract
    log_info "Copying and extracting repository to VM..."

    # Create target directory structure
    vm_exec "${vm_ip}" "mkdir -p /home/torrust/github/torrust" "Creating directory structure"

    # Remove existing directory if it exists
    if vm_exec "${vm_ip}" "test -d /home/torrust/github/torrust/torrust-tracker-demo" ""; then
        log_info "Removing existing repository directory..."
        vm_exec "${vm_ip}" "rm -rf /home/torrust/github/torrust/torrust-tracker-demo" "Removing old directory"
    fi

    # Copy archive to VM
    if ! scp -o StrictHostKeyChecking=no "${temp_archive}" "torrust@${vm_ip}:/tmp/"; then
        log_error "Failed to copy git archive to VM"
        rm -f "${temp_archive}"
        return 1
    fi

    # Extract archive on VM (git archive doesn't create parent directory)
    vm_exec "${vm_ip}" "cd /home/torrust/github/torrust && mkdir -p torrust-tracker-demo && cd torrust-tracker-demo && tar -xzf /tmp/$(basename "${temp_archive}")" "Extracting archive"
    vm_exec "${vm_ip}" "rm -f /tmp/$(basename "${temp_archive}")" "Cleaning up archive"

    # Clean up local temp file
    rm -f "${temp_archive}"

    # Verify extraction was successful
    if vm_exec "${vm_ip}" "test -f /home/torrust/github/torrust/torrust-tracker-demo/Makefile" "Verifying repository extraction"; then
        log_success "Repository extracted successfully"
    else
        log_error "Failed to extract repository"
        return 1
    fi

    # Step 3: Generate configuration files locally using infrastructure system
    log_info "Generating configuration files locally..."

    cd "${PROJECT_ROOT}"

    # Generate local configuration (this creates .env and processes templates)
    if ! make configure-local; then
        log_error "Failed to generate local configuration"
        return 1
    fi

    log_success "Configuration files generated locally"

    # Step 4: Run the official installation script locally to create directories
    log_info "Running installation script locally to create directories..."

    cd "${PROJECT_ROOT}/application"

    # Ensure .env file exists (should have been created by configure-local)
    if [[ ! -f ".env" ]]; then
        log_error "Missing .env file after configuration generation"
        return 1
    fi

    # Run the installation script
    if ! ./share/bin/install.sh; then
        log_error "Installation script failed"
        return 1
    fi

    log_success "Installation script completed successfully"

    # Step 5: Copy the configured storage folder and .env file to the VM
    log_info "Copying configured storage folder to VM..."

    # Ensure storage directory exists and has proper structure
    if [[ ! -d "${PROJECT_ROOT}/application/storage" ]]; then
        log_error "Storage directory not found after installation"
        return 1
    fi

    # Copy storage folder to VM
    if ! rsync -av --progress \
        -e "ssh -o StrictHostKeyChecking=no" \
        "${PROJECT_ROOT}/application/storage/" \
        "torrust@${vm_ip}:/home/torrust/github/torrust/torrust-tracker-demo/application/storage/"; then
        log_error "Failed to copy storage folder to VM"
        return 1
    fi

    # Copy .env file to VM
    log_info "Copying .env file to VM..."
    if ! scp -o StrictHostKeyChecking=no \
        "${PROJECT_ROOT}/application/.env" \
        "torrust@${vm_ip}:/home/torrust/github/torrust/torrust-tracker-demo/application/.env"; then
        log_error "Failed to copy .env file to VM"
        return 1
    fi

    # Verify critical configuration files exist on VM
    log_info "Verifying configuration files on VM..."

    local critical_files=(
        "/home/torrust/github/torrust/torrust-tracker-demo/application/.env"
        "/home/torrust/github/torrust/torrust-tracker-demo/application/storage/tracker/etc/tracker.toml"
        "/home/torrust/github/torrust/torrust-tracker-demo/application/storage/prometheus/etc/prometheus.yml"
    )

    for file in "${critical_files[@]}"; do
        if ! vm_exec "${vm_ip}" "test -f ${file}" "Checking ${file}"; then
            log_error "Critical configuration file missing: ${file}"
            return 1
        fi
    done

    log_success "Torrust Tracker Demo setup completed using 12-factor configuration approach"
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
    vm_exec "${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo/application && ${compose_cmd} pull" "Pulling Docker images"

    # Start services
    vm_exec "${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo/application && ${compose_cmd} up -d" "Starting services"

    # Wait for services to be ready
    log_info "Waiting for services to be ready..."
    sleep 30

    # Check service status
    if vm_exec "${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo/application && ${compose_cmd} ps" "Checking service status"; then
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

    # Test HTTP API endpoint through nginx proxy using Host header
    log_info "Testing HTTP API endpoint..."
    if vm_exec "${vm_ip}" "curl -f -s -H 'Host: tracker.torrust-demo.com' http://localhost:80/api/health_check" "Checking HTTP API"; then
        log_success "HTTP API is responding"
    else
        log_error "HTTP API is not responding"
        return 1
    fi

    # Test tracker statistics API
    log_info "Testing tracker statistics API..."
    if vm_exec "${vm_ip}" "curl -f -s -H 'Host: tracker.torrust-demo.com' 'http://localhost:80/api/v1/stats?token=local-dev-admin-token-12345'" "Checking statistics API"; then
        log_success "Statistics API is responding"
    else
        log_error "Statistics API is not responding"
        return 1
    fi

    # Test if UDP ports are listening (these are directly exposed)
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

    # Test Grafana through nginx proxy using Host header
    log_info "Testing Grafana..."
    if vm_exec "${vm_ip}" "curl -f -s -H 'Host: grafana.torrust-demo.com' http://localhost:80/api/health" "Checking Grafana health"; then
        log_success "Grafana is healthy"
    else
        log_error "Grafana is not healthy"
        return 1
    fi

    # Test Prometheus directly (no proxy configuration for Prometheus in current setup)
    log_info "Testing Prometheus..."
    if vm_exec "${vm_ip}" "docker exec prometheus wget -qO- http://localhost:9090/-/healthy" "Checking Prometheus health"; then
        log_success "Prometheus is healthy"
    else
        log_error "Prometheus is not healthy"
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
    vm_exec "${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo/application && docker compose logs --tail=50" "Collecting Docker logs"

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
        vm_exec "${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo/application && ${compose_cmd} down" "Stopping services"
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
