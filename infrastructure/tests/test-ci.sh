#!/bin/bash
# Infrastructure-only CI tests - Run infrastructure-specific tests that work in GitHub runners
# Focus: Infrastructure configuration validation, Terraform syntax, cloud-init templates
# Scope: No virtualization, no global repo concerns (like linting), infrastructure layer only

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST_LOG_FILE="/tmp/torrust-infrastructure-ci-test.log"

# Source shared shell utilities
# shellcheck source=../../scripts/shell-utils.sh
source "${PROJECT_ROOT}/scripts/shell-utils.sh"

# Set log file for tee output
export SHELL_UTILS_LOG_FILE="${TEST_LOG_FILE}"

# Initialize test log
init_test_log() {
    init_log_file "${TEST_LOG_FILE}" "Infrastructure-only CI Tests"
    log_info "Environment: CI (no virtualization)"
    log_info "Scope: Infrastructure layer only"
}

# Test execution summary
show_test_summary() {
    local start_time=$1
    local end_time
    local duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    log_section "INFRASTRUCTURE CI TEST SUMMARY"
    log_info "Infrastructure CI tests completed in ${duration} seconds"
    log_success "All infrastructure-specific tests passed!"
    log ""
    log_info "Note: This only validates infrastructure layer concerns."
    log_info "Run 'make test-ci' for complete project validation."
    log ""
    log_info "Test log saved to: ${TEST_LOG_FILE}"
}

# Main test execution
main() {
    local test_start_time
    test_start_time=$(date +%s)

    init_test_log

    log_section "INFRASTRUCTURE-ONLY CI TESTS"
    log_info "Running infrastructure-specific tests for GitHub runners"

    cd "${PROJECT_ROOT}"

    # Test 1: Infrastructure configuration validation
    log_section "TEST 1: INFRASTRUCTURE CONFIGURATION"
    log_info "Running infrastructure configuration validation..."
    if ! "${SCRIPT_DIR}/test-unit-config.sh"; then
        log_error "Infrastructure configuration validation failed"
        exit 1
    fi
    log_success "Infrastructure configuration validation passed"

    # Test 2: Infrastructure script unit tests
    log_section "TEST 2: INFRASTRUCTURE SCRIPTS"
    log_info "Running infrastructure script validation..."
    if ! "${SCRIPT_DIR}/test-unit-scripts.sh"; then
        log_error "Infrastructure script validation failed"
        exit 1
    fi
    log_success "Infrastructure script validation passed"

    show_test_summary "${test_start_time}"
}

# Run main function
main "$@"
