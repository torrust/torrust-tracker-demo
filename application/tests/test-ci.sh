#!/bin/bash
# Application-only CI tests - Run application-specific tests that work in GitHub runners
# Focus: Docker Compose validation, application configuration, deployment scripts
# Scope: No virtualization, no global repo concerns, application layer only

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLICATION_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST_LOG_FILE="/tmp/torrust-application-ci-test.log"

# Source shared shell utilities
# shellcheck source=../../scripts/shell-utils.sh
source "${PROJECT_ROOT}/scripts/shell-utils.sh"

# Set log file for tee output
export SHELL_UTILS_LOG_FILE="${TEST_LOG_FILE}"

# Initialize test log
init_test_log() {
    init_log_file "${TEST_LOG_FILE}" "Application-only CI Tests"
    log_info "Environment: CI (no deployment)"
    log_info "Scope: Application layer only"
    log_info "Application Root: ${APPLICATION_ROOT}"
}

# Test execution summary
show_test_summary() {
    local start_time=$1
    local end_time
    local duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    log_section "APPLICATION CI TEST SUMMARY"
    log_info "Application CI tests completed in ${duration} seconds"
    log_success "All application-specific tests passed!"
    log ""
    log_info "Note: This only validates application layer concerns."
    log_info "Run 'make test-ci' for complete project validation."
    log ""
    log_info "Test log saved to: ${TEST_LOG_FILE}"
}

# Main test execution
main() {
    local test_start_time
    test_start_time=$(date +%s)

    init_test_log

    log_section "APPLICATION-ONLY CI TESTS"
    log_info "Running application-specific tests for GitHub runners"

    cd "${PROJECT_ROOT}"

    # Test 1: Application unit tests
    log_section "TEST 1: APPLICATION CONFIGURATION & CONTAINERS"
    log_info "Running application unit tests..."
    if ! "${APPLICATION_ROOT}/tests/test-unit-application.sh"; then
        log_error "Application unit tests failed"
        exit 1
    fi
    log_success "Application unit tests passed"

    show_test_summary "${test_start_time}"
}

# Run main function
main "$@"
