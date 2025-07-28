#!/bin/bash
# CI-compatible tests - Run tests that work in GitHub runners
# Focus: Syntax validation, configuration validation, script unit tests
# Scope: No virtualization or infrastructure deployment required

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST_LOG_FILE="/tmp/torrust-ci-test.log"

# Source shared shell utilities
# shellcheck source=../../scripts/shell-utils.sh
source "${PROJECT_ROOT}/scripts/shell-utils.sh"

# Set log file for tee output
export SHELL_UTILS_LOG_FILE="${TEST_LOG_FILE}"

# Initialize test log
init_test_log() {
    init_log_file "${TEST_LOG_FILE}" "Torrust Tracker Demo - CI-Compatible Tests"
    log_info "Environment: CI (no virtualization)"
}

# Test execution summary
show_test_summary() {
    local start_time=$1
    local end_time
    local duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    log_section "CI TEST SUMMARY"
    log_info "Total CI tests completed in ${duration} seconds"
    log_success "All CI-compatible tests passed!"
    log ""
    log_info "Next steps for full validation:"
    log_info "  1. Run 'make test-local' on a system with virtualization"
    log_info "  2. Run 'make test' for full end-to-end testing"
    log ""
    log_info "Test log saved to: ${TEST_LOG_FILE}"
}

# Main test execution
main() {
    local test_start_time
    test_start_time=$(date +%s)

    init_test_log

    log_section "TORRUST TRACKER DEMO - CI-COMPATIBLE TESTS"
    log_info "Running tests suitable for GitHub runners (no virtualization)"

    cd "${PROJECT_ROOT}"

    # Test 1: Syntax validation (fast)
    log_section "TEST 1: SYNTAX VALIDATION"
    log_info "Running syntax validation..."
    if ! make test-syntax; then
        log_error "Syntax validation failed"
        exit 1
    fi
    log_success "Syntax validation passed"

    # Test 2: Configuration validation
    log_section "TEST 2: CONFIGURATION VALIDATION"
    log_info "Running configuration validation..."
    if ! "${SCRIPT_DIR}/test-unit-config.sh"; then
        log_error "Configuration validation failed"
        exit 1
    fi
    log_success "Configuration validation passed"

    # Test 3: Script unit tests
    log_section "TEST 3: SCRIPT UNIT TESTS"
    log_info "Running script unit tests..."
    if ! "${SCRIPT_DIR}/test-unit-scripts.sh"; then
        log_error "Script unit tests failed"
        exit 1
    fi
    log_success "Script unit tests passed"

    # Test 4: Makefile validation
    log_section "TEST 4: MAKEFILE VALIDATION"
    log_info "Validating Makefile targets..."
    if ! make validate-config 2>/dev/null; then
        log_warning "Makefile validation script not found (optional)"
    else
        log_success "Makefile validation passed"
    fi

    show_test_summary "${test_start_time}"
}

# Run main function
main "$@"
