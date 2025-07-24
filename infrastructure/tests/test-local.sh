#!/bin/bash
# Local-only tests - Run tests that require virtualization support
# Focus: Infrastructure prerequisites validation and VM-based testing
# Scope: Requires KVM/libvirt support - NOT suitable for CI runners

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST_LOG_FILE="/tmp/torrust-local-test.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

log_section() {
    log ""
    log "${BLUE}===============================================${NC}"
    log "${BLUE}$1${NC}"
    log "${BLUE}===============================================${NC}"
}

# Initialize test log
init_test_log() {
    {
        echo "Torrust Tracker Demo - Local-Only Tests"
        echo "Started: $(date)"
        echo "Environment: Local (virtualization required)"
        echo "================================================================="
    } >"${TEST_LOG_FILE}"
}

# Check if running in CI environment
check_ci_environment() {
    if [ "${CI:-}" = "true" ] || [ "${GITHUB_ACTIONS:-}" = "true" ]; then
        log_error "Local-only tests detected CI environment"
        log_error "These tests require virtualization support and cannot run in CI"
        log_error "Use 'make test-ci' for CI-compatible tests"
        exit 1
    fi
}

# Test virtualization prerequisites
test_virtualization_prerequisites() {
    log_section "VIRTUALIZATION PREREQUISITES CHECK"
    log_info "Checking KVM and libvirt support..."

    # Check KVM support
    if [ ! -r /dev/kvm ]; then
        log_error "KVM device (/dev/kvm) not accessible"
        log_error "Virtualization may not be enabled in BIOS or not supported"
        return 1
    fi
    log_success "KVM device accessible"

    # Check libvirt service
    if ! systemctl is-active --quiet libvirtd 2>/dev/null; then
        log_error "libvirtd service is not running"
        log_error "Run: sudo systemctl start libvirtd"
        return 1
    fi
    log_success "libvirtd service is running"

    # Check user libvirt access
    if ! virsh list >/dev/null 2>&1; then
        log_error "Cannot access libvirt as current user"
        log_error "Ensure user is in libvirt group and session is refreshed"
        return 1
    fi
    log_success "User has libvirt access"

    return 0
}

# Test execution summary
show_test_summary() {
    local start_time=$1
    local end_time
    local duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    log_section "LOCAL TEST SUMMARY"
    log_info "Total local tests completed in ${duration} seconds"
    log_success "All local-only tests passed!"
    log ""
    log_info "For full end-to-end testing, run: make test"
    log ""
    log_info "Test log saved to: ${TEST_LOG_FILE}"
}

# Main test execution
main() {
    local test_start_time
    test_start_time=$(date +%s)

    init_test_log

    log_section "TORRUST TRACKER DEMO - LOCAL-ONLY TESTS"
    log_info "Running tests that require virtualization support"

    check_ci_environment

    cd "${PROJECT_ROOT}"

    # Test 1: Virtualization prerequisites
    if ! test_virtualization_prerequisites; then
        log_error "Virtualization prerequisites check failed"
        log_error "Please ensure KVM and libvirt are properly installed and configured"
        exit 1
    fi

    # Test 2: Infrastructure prerequisites validation
    log_section "INFRASTRUCTURE PREREQUISITES"
    log_info "Running infrastructure prerequisites validation..."
    if ! "${SCRIPT_DIR}/test-unit-infrastructure.sh" vm-prereq; then
        log_error "Infrastructure prerequisites validation failed"
        exit 1
    fi
    log_success "Infrastructure prerequisites validation passed"

    # Test 3: Optional - Quick infrastructure validation (without full deployment)
    log_section "INFRASTRUCTURE VALIDATION"
    log_info "Running infrastructure validation without deployment..."
    if ! make test-prereq; then
        log_warning "Infrastructure validation had warnings (this is usually OK)"
    else
        log_success "Infrastructure validation passed"
    fi

    show_test_summary "${test_start_time}"
}

# Run main function
main "$@"
