#!/bin/bash
# Application deployment script for Torrust Tracker Demo
# Deploys application to provisioned infrastructure
# Twelve-Factor App compliant: Release + Run stages

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/infrastructure/terraform"

# Default values
ENVIRONMENT="${1:-local}"
VM_IP="${2:-}"
SKIP_HEALTH_CHECK="${SKIP_HEALTH_CHECK:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
        log_error "Ensure infrastructure is provisioned: make infra-apply ENVIRONMENT=${ENVIRONMENT}"
        log_info "You can also provide IP manually: make app-deploy ENVIRONMENT=${ENVIRONMENT} VM_IP=<ip>"
        exit 1
    fi

    echo "${vm_ip}"
}

# Test SSH connectivity
test_ssh_connection() {
    local vm_ip="$1"
    local max_attempts=5
    local attempt=1

    log_info "Testing SSH connectivity to ${vm_ip}"

    while [[ ${attempt} -le ${max_attempts} ]]; do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes torrust@"${vm_ip}" exit 2>/dev/null; then
            log_success "SSH connection established"
            return 0
        fi

        log_warning "SSH attempt ${attempt}/${max_attempts} failed, retrying in 5 seconds..."
        sleep 5
        ((attempt++))
    done

    log_error "Failed to establish SSH connection after ${max_attempts} attempts"
    log_error "Please check:"
    log_error "  1. VM is running: virsh list"
    log_error "  2. SSH service is ready (may take 2-3 minutes after VM start)"
    log_error "  3. SSH key is correct"
    exit 1
}

# Execute command on VM via SSH
vm_exec() {
    local vm_ip="$1"
    local command="$2"
    local description="${3:-}"

    if [[ -n "${description}" ]]; then
        log_info "${description}"
    fi

    if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30 torrust@"${vm_ip}" "${command}"; then
        log_error "Failed to execute command on VM: ${command}"
        exit 1
    fi
}

# RELEASE STAGE: Deploy application code and configuration
release_stage() {
    local vm_ip="$1"

    log_info "=== TWELVE-FACTOR RELEASE STAGE ==="
    log_info "Deploying application with environment: ${ENVIRONMENT}"

    # Deploy local repository using git archive (testing local changes)
    log_info "Creating git archive of local repository..."
    local temp_archive
    temp_archive="/tmp/torrust-tracker-demo-$(date +%s).tar.gz"

    cd "${PROJECT_ROOT}"
    if ! git archive --format=tar.gz --output="${temp_archive}" HEAD; then
        log_error "Failed to create git archive"
        exit 1
    fi

    log_info "Copying local repository to VM..."
    
    # Create target directory structure
    vm_exec "${vm_ip}" "mkdir -p /home/torrust/github/torrust" "Creating directory structure"

    # Remove existing directory if it exists
    vm_exec "${vm_ip}" "test -d /home/torrust/github/torrust/torrust-tracker-demo && rm -rf /home/torrust/github/torrust/torrust-tracker-demo || true" "Removing existing repository"

    # Copy archive to VM
    if ! scp -o StrictHostKeyChecking=no "${temp_archive}" "torrust@${vm_ip}:/tmp/"; then
        log_error "Failed to copy git archive to VM"
        rm -f "${temp_archive}"
        exit 1
    fi

    # Extract archive on VM
    vm_exec "${vm_ip}" "cd /home/torrust/github/torrust && mkdir -p torrust-tracker-demo" "Creating repository directory"
    vm_exec "${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo && tar -xzf /tmp/$(basename "${temp_archive}")" "Extracting repository"
    vm_exec "${vm_ip}" "rm -f /tmp/$(basename "${temp_archive}")" "Cleaning up temp files"

    # Clean up local temp file
    rm -f "${temp_archive}"

    # Verify deployment
    vm_exec "${vm_ip}" "test -f /home/torrust/github/torrust/torrust-tracker-demo/Makefile" "Verifying repository deployment"
    
    log_success "Local repository deployed successfully"

    # Process configuration (Release stage - combining code with config)
    vm_exec "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo
        
        if [ -f infrastructure/scripts/configure-env.sh ]; then
            ./infrastructure/scripts/configure-env.sh ${ENVIRONMENT}
        else
            echo 'Configuration script not found, using defaults'
        fi
    " "Processing configuration for environment: ${ENVIRONMENT}"

    # Ensure proper permissions
    vm_exec "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo
        
        # Fix any permission issues
        if [ -f infrastructure/scripts/fix-volume-permissions.sh ]; then
            sudo ./infrastructure/scripts/fix-volume-permissions.sh
        fi
        
        # Ensure storage directories exist
        mkdir -p application/storage/{tracker/lib/database,prometheus/data}
    " "Setting up application storage"

    log_success "Release stage completed"
}

# RUN STAGE: Start application processes
run_stage() {
    local vm_ip="$1"

    log_info "=== TWELVE-FACTOR RUN STAGE ==="
    log_info "Starting application services"

    # Stop any existing services
    vm_exec "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo/application
        
        if [ -f compose.yaml ]; then
            docker compose down --remove-orphans || true
        fi
    " "Stopping existing services"

    # Pull latest images and start services
    vm_exec "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo/application
        
        # Pull latest images
        docker compose pull
        
        # Start services
        docker compose up -d
    " "Starting application services"

    # Wait for services to initialize
    log_info "Waiting for services to initialize (30 seconds)..."
    sleep 30

    log_success "Run stage completed"
}

# Validate deployment (Health checks)
validate_deployment() {
    local vm_ip="$1"

    log_info "=== DEPLOYMENT VALIDATION ==="

    # Check service status
    vm_exec "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo/application
        echo '=== Docker Compose Services ==='
        docker compose ps
        
        echo '=== Service Logs (last 10 lines) ==='
        docker compose logs --tail=10
    " "Checking service status"

    # Test application endpoints
    vm_exec "${vm_ip}" "
        echo '=== Testing Application Endpoints ==='
        
        # Test health check endpoint (through nginx proxy)
        if curl -f -s http://localhost/health_check >/dev/null 2>&1; then
            echo '✅ Health check endpoint: OK'
        else
            echo '❌ Health check endpoint: FAILED'
            exit 1
        fi
        
        # Test API stats endpoint (through nginx proxy, requires auth)
        if curl -f -s "http://localhost/api/v1/stats?token=local-dev-admin-token-12345" >/dev/null 2>&1; then
            echo '✅ API stats endpoint: OK'
        else
            echo '❌ API stats endpoint: FAILED'
            exit 1
        fi
        
        # Test HTTP tracker endpoint (through nginx proxy - expects 404 for root)
        if curl -s -w '%{http_code}' http://localhost/ -o /dev/null | grep -q '404'; then
            echo '✅ HTTP tracker endpoint: OK (nginx proxy responding, tracker ready for BitTorrent clients)'
        else
            echo '❌ HTTP tracker endpoint: FAILED'
            exit 1
        fi
        
        echo '✅ All endpoints are responding'
    " "Testing application endpoints"

    log_success "Deployment validation passed"
}

# Display connection information
show_connection_info() {
    local vm_ip="$1"

    log_success "Application deployment completed successfully!"
    echo
    echo "=== CONNECTION INFORMATION ==="
    echo "VM IP:           ${vm_ip}"
    echo "SSH Access:      ssh torrust@${vm_ip}"
    echo
    echo "=== APPLICATION ENDPOINTS ==="
    echo "Health Check:    http://${vm_ip}/health_check"
    echo "API Stats:       http://${vm_ip}/api/v1/stats?token=local-dev-admin-token-12345"
    echo "HTTP Tracker:    http://${vm_ip}/ (for BitTorrent clients)"
    echo "UDP Tracker:     udp://${vm_ip}:6868, udp://${vm_ip}:6969"
    echo "Grafana:         http://${vm_ip}:3100 (admin/admin)"
    echo
    echo "=== NEXT STEPS ==="
    echo "Health Check:    make health-check ENVIRONMENT=${ENVIRONMENT}"
    echo "View Logs:       ssh torrust@${vm_ip} 'cd torrust-tracker-demo/application && docker compose logs'"
    echo "Stop Services:   ssh torrust@${vm_ip} 'cd torrust-tracker-demo/application && docker compose down'"
    echo
}

# Main execution
main() {
    log_info "Starting application deployment (Twelve-Factor Release + Run Stages)"
    log_info "Environment: ${ENVIRONMENT}"

    local vm_ip
    vm_ip=$(get_vm_ip)

    test_ssh_connection "${vm_ip}"
    release_stage "${vm_ip}"
    run_stage "${vm_ip}"

    if [[ "${SKIP_HEALTH_CHECK}" != "true" ]]; then
        validate_deployment "${vm_ip}"
    fi

    show_connection_info "${vm_ip}"
}

# Show help
show_help() {
    cat <<EOF
Application Deployment Script (Twelve-Factor Release + Run Stages)

Usage: $0 [ENVIRONMENT] [VM_IP]

Arguments:
    ENVIRONMENT    Environment name (local, production)
    VM_IP          VM IP address (optional, will get from Terraform if not provided)

Environment Variables:
    SKIP_HEALTH_CHECK    Skip health check validation (true/false, default: false)

Examples:
    $0 local                    # Deploy to local environment (get IP from Terraform)
    $0 production               # Deploy to production (get IP from Terraform)
    $0 local 192.168.1.100     # Deploy to local with specific IP

Twelve-Factor Compliance:
    This script implements RELEASE + RUN stages:
    
    RELEASE: Combines application code with environment-specific configuration
    RUN:     Starts application processes and validates deployment
    
Prerequisites:
    Infrastructure must be provisioned first:
    make infra-apply ENVIRONMENT=${ENVIRONMENT}
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
