#!/bin/bash
# End-to-End Twelve-Factor Deployment Test
# Automated version of docs/guides/integration-testing-guide.md
#
# This test follows the exact workflow described in the integration testing guide:
# 1. Prerequisites validation
# 2. Infrastructure provisioning (make infra-apply)
# 3. Application deployment (make app-deploy)
# 4. Health validation (make health-check)
# 5. Cleanup (make infra-destroy)

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENVIRONMENT="${1:-local}"
SKIP_CLEANUP="${SKIP_CLEANUP:-false}"
TEST_LOG_FILE="/tmp/torrust-e2e-test.log"

# Source shared shell utilities
# shellcheck source=../scripts/shell-utils.sh
source "${PROJECT_ROOT}/scripts/shell-utils.sh"

# Set log file for tee output
export SHELL_UTILS_LOG_FILE="${TEST_LOG_FILE}"

log_section() {
    log ""
    log "${BLUE}===============================================${NC}"
    log "${BLUE}$1${NC}"
    log "${BLUE}===============================================${NC}"
}

# Track test start time
TEST_START_TIME=$(date +%s)

# Initialize test log
init_test_log() {
    init_log_file "${TEST_LOG_FILE}" "Torrust Tracker Demo - End-to-End Twelve-Factor Test"
    log_info "Environment: ${ENVIRONMENT}"
}

# Check and prepare sudo cache for infrastructure operations
prepare_sudo_for_infrastructure() {
    log_section "SUDO PREPARATION"

    log_warning "Infrastructure provisioning requires administrator privileges"
    log_info "This is needed for:"
    log_info "  • Setting libvirt volume permissions during VM creation"
    log_info "  • Configuring KVM/libvirt resources"

    if ! ensure_sudo_cached "manage libvirt infrastructure"; then
        log_error "Cannot proceed without administrator privileges"
        log_error "Infrastructure provisioning requires sudo access for libvirt operations"
        return 1
    fi

    log_success "Administrator privileges confirmed and cached"
    log_info "Sudo cache will remain valid for ~15 minutes"
    return 0
}

# Step 1: Prerequisites Validation (Following Integration Testing Guide)
test_prerequisites() {
    log_section "STEP 1: Prerequisites Validation"

    log_info "Validating syntax and configuration..."

    cd "${PROJECT_ROOT}"

    if ! make test-syntax; then
        log_error "Prerequisites validation failed"
        return 1
    fi

    log_success "Prerequisites validation passed"
    return 0
}

# Step 2: Infrastructure Provisioning (Following Integration Testing Guide)
test_infrastructure_provisioning() {
    log_section "STEP 2: Infrastructure Provisioning"

    cd "${PROJECT_ROOT}"

    # Clean up any existing infrastructure first (optional step from guide)
    log_info "Cleaning up any existing infrastructure..."
    if ! make infra-destroy ENVIRONMENT="${ENVIRONMENT}" 2>/dev/null; then
        log_info "No existing infrastructure to clean up"
    fi

    # Initialize infrastructure (Step 2.1 from guide)
    log_info "Initializing infrastructure..."
    if ! make infra-init ENVIRONMENT="${ENVIRONMENT}"; then
        log_error "Infrastructure initialization failed"
        return 1
    fi

    # Plan infrastructure changes (Step 2.2 from guide)
    log_info "Planning infrastructure changes..."
    if ! make infra-plan ENVIRONMENT="${ENVIRONMENT}"; then
        log_error "Infrastructure planning failed"
        return 1
    fi

    # Provision infrastructure (Step 2.3 from guide)
    log_info "Provisioning infrastructure..."
    local start_time
    start_time=$(date +%s)

    if ! make infra-apply ENVIRONMENT="${ENVIRONMENT}"; then
        log_error "Infrastructure provisioning failed"
        return 1
    fi

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_success "Infrastructure provisioned successfully in ${duration} seconds"

    # Verify infrastructure (Step 2.4 from guide)
    log_info "Verifying infrastructure status..."
    if ! make infra-status ENVIRONMENT="${ENVIRONMENT}"; then
        log_error "Infrastructure status check failed"
        return 1
    fi

    # Wait for VM to get IP address before proceeding to application deployment
    if ! wait_for_vm_ip; then
        log_error "VM IP address not available - cannot proceed with application deployment"
        return 1
    fi

    # Wait for VM to be fully ready (cloud-init completion and Docker availability)
    if ! wait_for_cloud_init_to_finish; then
        log_error "VM not ready for application deployment - cloud-init failed or timed out"
        return 1
    fi

    return 0
}

# Step 3: Application Deployment (Following Integration Testing Guide)
test_application_deployment() {
    log_section "STEP 3: Application Deployment"

    cd "${PROJECT_ROOT}"

    # Deploy application (Step 3.1 from guide)
    log_info "Deploying application using twelve-factor workflow..."
    local start_time
    start_time=$(date +%s)

    if ! make app-deploy ENVIRONMENT="${ENVIRONMENT}"; then
        log_error "Application deployment failed"
        return 1
    fi

    # Note: app-deploy includes health validation via validate_deployment function
    log_info "Application deployment completed with built-in health validation"

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_success "Application deployed successfully in ${duration} seconds"

    return 0
}

# Step 4: Health Validation (Following Integration Testing Guide)
test_health_validation() {
    log_section "STEP 4: Health Validation"

    cd "${PROJECT_ROOT}"

    # Run health check (Step 3.2 from guide)
    log_info "Running comprehensive health check..."

    if ! make health-check ENVIRONMENT="${ENVIRONMENT}"; then
        log_error "Health check failed"
        return 1
    fi

    # Additional application-level health checks
    log_info "Running additional application health checks..."

    # Get VM IP for direct testing
    local vm_ip
    vm_ip=$(virsh domifaddr torrust-tracker-demo 2>/dev/null | grep ipv4 | awk '{print $4}' | cut -d'/' -f1 || echo "")

    if [[ -n "${vm_ip}" ]]; then
        log_info "Testing application endpoints on ${vm_ip}..."

        # Test tracker health endpoint (may take a moment to be ready)
        local max_attempts=12 # 2 minutes
        local attempt=1
        while [[ ${attempt} -le ${max_attempts} ]]; do
            log_info "Testing health endpoint (attempt ${attempt}/${max_attempts})..."
            # shellcheck disable=SC2034,SC2086
            if curl -f -s http://"${vm_ip}"/api/health_check >/dev/null 2>&1; then
                log_success "Health endpoint responding"
                break
            fi
            if [[ ${attempt} -eq ${max_attempts} ]]; then
                log_warning "Health endpoint not responding after ${max_attempts} attempts"
            else
                sleep 10
            fi
            ((attempt++))
        done

        # Test if basic services are running
        log_info "Checking if Docker services are running..."
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no torrust@"${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo/application && docker compose ps --services --filter status=running" 2>/dev/null | grep -q tracker; then
            log_success "Tracker service is running"
        else
            log_warning "Tracker service may not be running yet"
        fi
    else
        log_warning "VM IP not available for direct endpoint testing"
    fi

    log_success "Health validation completed"
    return 0
}

# Step 5: Smoke Testing (Basic tracker functionality testing)
test_smoke_testing() {
    log_section "STEP 5: Smoke Testing (Basic Functionality)"

    # Get VM IP for testing
    local vm_ip
    vm_ip=$(virsh domifaddr torrust-tracker-demo 2>/dev/null | grep ipv4 | awk '{print $4}' | cut -d'/' -f1 || echo "")

    if [[ -z "${vm_ip}" ]]; then
        log_error "VM IP not available - cannot run mandatory smoke tests"
        return 1
    fi

    log_info "Running mandatory smoke tests against ${vm_ip}..."
    log_info "These tests validate core tracker functionality and must pass for successful deployment"

    local failed_tests=0

    # Test 1: Health Check API (through nginx proxy on port 80)
    log_info "Testing health check API through nginx proxy..."
    local health_response
    health_response=$(curl -f -s http://"${vm_ip}":80/api/health_check 2>/dev/null || echo "")
    if echo "${health_response}" | grep -q '"status":"Ok"'; then
        log_success "✓ Health check API working"
    else
        log_error "✗ Health check API failed - Response: ${health_response}"
        ((failed_tests++))
    fi

    # Test 2: Statistics API (through nginx proxy on port 80)
    log_info "Testing statistics API through nginx proxy..."
    local stats_response
    stats_response=$(curl -f -s "http://${vm_ip}:80/api/v1/stats?token=local-dev-admin-token-12345" 2>/dev/null || echo "") # DevSkim: ignore DS137138
    if echo "${stats_response}" | grep -q '"torrents"'; then
        log_success "✓ Statistics API working"
    else
        log_error "✗ Statistics API failed - Response: ${stats_response}"
        ((failed_tests++))
    fi

    # Test 3: UDP tracker connectivity (port 6969)
    log_info "Testing UDP tracker connectivity on port 6969..."
    if command -v nc >/dev/null 2>&1; then
        if timeout 5 nc -u -z "${vm_ip}" 6969 2>/dev/null; then
            log_success "✓ UDP tracker port 6969 accessible"
        else
            log_error "✗ UDP tracker port 6969 not accessible"
            ((failed_tests++))
        fi
    else
        log_warning "netcat not available - skipping UDP connectivity test (not counted as failure)"
    fi

    # Test 4: UDP tracker connectivity (port 6868)
    log_info "Testing UDP tracker connectivity on port 6868..."
    if command -v nc >/dev/null 2>&1; then
        if timeout 5 nc -u -z "${vm_ip}" 6868 2>/dev/null; then
            log_success "✓ UDP tracker port 6868 accessible"
        else
            log_error "✗ UDP tracker port 6868 not accessible"
            ((failed_tests++))
        fi
    else
        log_warning "netcat not available - skipping UDP connectivity test (not counted as failure)"
    fi

    # Test 5: HTTP tracker through nginx proxy (health check endpoint)
    log_info "Testing HTTP tracker through nginx proxy..."
    local proxy_response
    proxy_response=$(curl -s -w "%{http_code}" -o /dev/null "http://${vm_ip}:80/health_check" 2>/dev/null || echo "000") # DevSkim: ignore DS137138
    if [[ "${proxy_response}" =~ ^[23][0-9][0-9]$ ]]; then
        log_success "✓ Nginx proxy responding (HTTP ${proxy_response})"
    else
        log_error "✗ Nginx proxy not responding properly (HTTP ${proxy_response})"
        ((failed_tests++))
    fi

    # Test 6: Direct tracker health check (port 1212)
    log_info "Testing direct tracker health check on port 1212..."
    local direct_health
    direct_health=$(curl -f -s http://"${vm_ip}":1212/api/health_check 2>/dev/null || echo "")
    if echo "${direct_health}" | grep -q '"status":"Ok"'; then
        log_success "✓ Direct tracker health check working"
    else
        log_error "✗ Direct tracker health check failed - Response: ${direct_health}"
        ((failed_tests++))
    fi

    # Report results
    if [[ ${failed_tests} -eq 0 ]]; then
        log_success "All mandatory smoke tests passed (${failed_tests} failures)"
        log_info "For comprehensive tracker testing, see: docs/guides/smoke-testing-guide.md"
        return 0
    else
        log_error "Smoke tests failed: ${failed_tests} test(s) failed"
        log_error "Deployment validation unsuccessful - investigate service configuration"
        log_info "Check service status with: ssh torrust@${vm_ip} 'cd /home/torrust/github/torrust/torrust-tracker-demo/application && docker compose ps'"
        log_info "For troubleshooting, see: docs/guides/smoke-testing-guide.md"
        return 1
    fi
}

# Step 6: Cleanup (Following Integration Testing Guide)
test_cleanup() {
    log_section "STEP 6: Cleanup"

    if [[ "${SKIP_CLEANUP}" == "true" ]]; then
        log_warning "Cleanup skipped (SKIP_CLEANUP=true)"
        log_info "Remember to run 'make infra-destroy ENVIRONMENT=${ENVIRONMENT}' manually"
        return 0
    fi

    cd "${PROJECT_ROOT}"

    log_info "Destroying infrastructure..."

    if ! make infra-destroy ENVIRONMENT="${ENVIRONMENT}"; then
        log_error "Infrastructure cleanup failed"
        return 1
    fi

    log_success "Infrastructure cleanup completed"
    return 0
}

# Warning about password prompts
show_password_warning() {
    log_section "⚠️  IMPORTANT PASSWORD PROMPT WARNING"
    log_warning "This test will provision infrastructure using libvirt/KVM which requires:"
    log_warning "• Your user password for sudo operations (administrator privileges)"
    log_warning "• SSH key passphrase (if your SSH key is encrypted)"
    log_warning ""
    log_info "The test will prompt for your password ONCE at the beginning to cache sudo credentials."
    log_info "After that, infrastructure operations will run without interruption."
    log_warning ""
    log_info "Expected test duration: ~8-12 minutes (includes VM setup + Docker installation)"
    log_warning ""

    # Prompt for continuation
    if [[ "${SKIP_CONFIRMATION:-false}" != "true" ]]; then
        echo -e -n "${YELLOW}Do you want to continue with the E2E test? [Y/n]: ${NC}"
        read -r response
        case "${response}" in
        [nN] | [nN][oO])
            log_info "Test cancelled by user"
            exit 0
            ;;
        *)
            log_info "Continuing with E2E test..."
            ;;
        esac
    fi
}

# Wait for VM IP assignment after infrastructure provisioning
wait_for_vm_ip() {
    log_info "Waiting for VM IP assignment..."
    local max_attempts=30
    local attempt=1
    local vm_ip=""

    while [[ ${attempt} -le ${max_attempts} ]]; do
        log_info "Checking for VM IP (attempt ${attempt}/${max_attempts})..."

        # Try to get IP from terraform output
        cd "${PROJECT_ROOT}"
        vm_ip=$(make infra-status ENVIRONMENT="${ENVIRONMENT}" 2>/dev/null | grep "vm_ip" | grep -v "No IP assigned yet" | awk -F '"' '{print $2}' || echo "")

        if [[ -n "${vm_ip}" && "${vm_ip}" != "No IP assigned yet" ]]; then
            log_success "VM IP assigned: ${vm_ip}"
            return 0
        fi

        # Also check libvirt directly as fallback
        vm_ip=$(virsh domifaddr torrust-tracker-demo 2>/dev/null | grep ipv4 | awk '{print $4}' | cut -d'/' -f1 || echo "")
        if [[ -n "${vm_ip}" ]]; then
            log_success "VM IP assigned (via libvirt): ${vm_ip}"
            # Refresh terraform state to sync with actual VM state
            log_info "Refreshing terraform state to sync with VM..."
            make infra-refresh-state ENVIRONMENT="${ENVIRONMENT}" || true
            return 0
        fi

        log_info "VM IP not yet assigned, waiting 10 seconds..."
        sleep 10
        ((attempt++))
    done

    log_error "Timeout waiting for VM IP assignment after $((max_attempts * 10)) seconds"
    log_error "VM may still be starting or cloud-init may be running"
    log_error "You can check manually with: virsh domifaddr torrust-tracker-demo"
    return 1
}

# Wait for VM to be fully ready (cloud-init completion and Docker availability)
wait_for_cloud_init_to_finish() {
    log_info "Waiting for cloud-init to finish..."
    local max_attempts=60 # 10 minutes total
    local attempt=1
    local vm_ip=""

    # First get the VM IP
    vm_ip=$(virsh domifaddr torrust-tracker-demo 2>/dev/null | grep ipv4 | awk '{print $4}' | cut -d'/' -f1 || echo "")
    if [[ -z "${vm_ip}" ]]; then
        log_error "VM IP not available - cannot check readiness"
        return 1
    fi

    log_info "VM IP: ${vm_ip} - checking cloud-init readiness..."

    while [[ ${attempt} -le ${max_attempts} ]]; do
        log_info "Checking cloud-init status (attempt ${attempt}/${max_attempts})..."

        # Check if SSH is available
        if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no torrust@"${vm_ip}" "echo 'SSH OK'" >/dev/null 2>&1; then
            log_info "SSH not ready yet, waiting 10 seconds..."
            sleep 10
            ((attempt++))
            continue
        fi

        # Check if cloud-init has finished
        local cloud_init_status
        cloud_init_status=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no torrust@"${vm_ip}" "cloud-init status" 2>/dev/null || echo "unknown")

        if [[ "${cloud_init_status}" == *"done"* ]]; then
            log_success "Cloud-init completed successfully"

            # Check if Docker is available and working
            if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no torrust@"${vm_ip}" "docker --version && docker compose version" >/dev/null 2>&1; then
                log_success "Docker is ready and available"
                log_success "VM is ready for application deployment"
                return 0
            else
                log_info "Docker not ready yet, waiting 10 seconds..."
            fi
        elif [[ "${cloud_init_status}" == *"error"* ]]; then
            log_error "Cloud-init failed with error status"
            return 1
        else
            log_info "Cloud-init status: ${cloud_init_status}, waiting 10 seconds..."
        fi

        sleep 10
        ((attempt++))
    done

    log_error "Timeout waiting for cloud-init to finish after $((max_attempts * 10)) seconds"
    log_error "You can check manually with: ssh torrust@${vm_ip} 'cloud-init status'"
    return 1
}

# Main test execution
run_e2e_test() {
    local failed=0

    init_test_log

    # Show password warning and get user confirmation
    show_password_warning

    # Prepare sudo cache for infrastructure operations
    prepare_sudo_for_infrastructure || failed=1

    log_section "TORRUST TRACKER DEMO - END-TO-END TWELVE-FACTOR TEST"
    log_info "Environment: ${ENVIRONMENT}"
    log_info "Following: docs/guides/integration-testing-guide.md"
    log_info "Working directory: ${PROJECT_ROOT}"

    # Execute test steps in sequence (matching integration testing guide)
    if [[ ${failed} -eq 0 ]]; then
        test_prerequisites || failed=1
    fi

    if [[ ${failed} -eq 0 ]]; then
        test_infrastructure_provisioning || failed=1
    fi

    if [[ ${failed} -eq 0 ]]; then
        test_application_deployment || failed=1
    fi

    if [[ ${failed} -eq 0 ]]; then
        test_health_validation || failed=1
    fi

    if [[ ${failed} -eq 0 ]]; then
        test_smoke_testing || failed=1
    fi

    # Always attempt cleanup (unless explicitly skipped)
    test_cleanup || log_warning "Cleanup failed - manual intervention may be required"

    # Calculate total test time
    local test_end_time
    test_end_time=$(date +%s)
    local total_duration=$((test_end_time - TEST_START_TIME))
    local minutes=$((total_duration / 60))
    local seconds=$((total_duration % 60))

    # Final result
    if [[ ${failed} -eq 0 ]]; then
        log_section "TEST RESULT: SUCCESS"
        log_success "End-to-end twelve-factor deployment test passed!"
        log_success "Total test time: ${minutes}m ${seconds}s"
        log_info "Test log: ${TEST_LOG_FILE}"
        return 0
    else
        log_section "TEST RESULT: FAILURE"
        log_error "End-to-end twelve-factor deployment test failed!"
        log_error "Total test time: ${minutes}m ${seconds}s"
        log_error "Check test log for details: ${TEST_LOG_FILE}"
        return 1
    fi
}

# Help function
show_help() {
    cat <<EOF
Torrust Tracker Demo - End-to-End Twelve-Factor Test

This test automates the workflow described in docs/guides/integration-testing-guide.md

Usage: $0 [ENVIRONMENT]

Arguments:
    ENVIRONMENT     Environment to test (default: local)

Environment Variables:
    SKIP_CLEANUP       Skip infrastructure cleanup (default: false)
    SKIP_CONFIRMATION  Skip confirmation prompt (default: false)

Examples:
    $0                                    # Test local environment
    $0 local                              # Test local environment explicitly
    SKIP_CLEANUP=true $0 local           # Test without cleanup
    SKIP_CONFIRMATION=true $0 local      # Test without confirmation prompt

Test Steps (following integration testing guide):
    1. Prerequisites validation (make test-syntax)
    2. Infrastructure provisioning (make infra-apply + VM readiness wait)
    3. Application deployment (make app-deploy)
    4. Health validation (make health-check + endpoint testing)
    5. Smoke testing (mandatory tracker functionality validation)
    6. Cleanup (make infra-destroy)

Expected Duration: ~8-12 minutes (includes VM setup + Docker installation)

Test log: ${TEST_LOG_FILE}
EOF
}

# Main execution
main() {
    case "${1:-}" in
    "help" | "-h" | "--help")
        show_help
        ;;
    *)
        run_e2e_test
        ;;
    esac
}

# Execute main function
main "$@"
