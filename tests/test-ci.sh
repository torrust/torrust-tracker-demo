#!/bin/bash
# Project-wide CI tests - Run global tests that work in GitHub runners
# Focus: Global syntax validation, Makefile validation, project structure
# Scope: No virtualization, cross-cutting concerns that span all layers

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_LOG_FILE="/tmp/torrust-project-ci-test.log"

# Source shared shell utilities
# shellcheck source=../scripts/shell-utils.sh
source "${PROJECT_ROOT}/scripts/shell-utils.sh"

# Set log file for tee output
export SHELL_UTILS_LOG_FILE="${TEST_LOG_FILE}"

# Initialize test log
init_test_log() {
    init_log_file "${TEST_LOG_FILE}" "Project-wide CI Tests"
    log_info "Environment: CI (no deployment)"
    log_info "Scope: Global/cross-cutting concerns"
    log_info "Project Root: ${PROJECT_ROOT}"
}

# Test execution summary
show_test_summary() {
    local start_time=$1
    local end_time
    local duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    log_section "PROJECT CI TEST SUMMARY"
    log_info "Project-wide CI tests completed in ${duration} seconds"
    log_success "All project-wide tests passed!"
    log ""
    log_info "Test log saved to: ${TEST_LOG_FILE}"
}

# Main test execution
main() {
    local test_start_time
    test_start_time=$(date +%s)

    init_test_log

    log_section "PROJECT-WIDE CI TESTS"
    log_info "Running global/cross-cutting tests for GitHub runners"

    cd "${PROJECT_ROOT}"

    # Test 1: Global syntax validation
    log_section "TEST 1: GLOBAL SYNTAX VALIDATION"
    log_info "Running global syntax validation (all file types)..."
    if ! ./scripts/lint.sh; then
        log_error "Global syntax validation failed"
        exit 1
    fi
    log_success "Global syntax validation passed"

    # Test 2: Project-wide unit tests
    log_section "TEST 2: PROJECT STRUCTURE & MAKEFILE"
    log_info "Running project-wide validation..."
    if ! "${SCRIPT_DIR}/test-unit-project.sh"; then
        log_error "Project-wide validation failed"
        exit 1
    fi
    log_success "Project-wide validation passed"

    show_test_summary "${test_start_time}"
}

# Run main function
main "$@"
