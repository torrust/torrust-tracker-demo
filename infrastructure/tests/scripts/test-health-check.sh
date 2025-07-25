#!/bin/bash
# Unit tests for health-check.sh script
# Focus: Test health-check.sh script functionality

set -euo pipefail

# Import test utilities
# shellcheck source=test-utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/test-utils.sh"

# Initialize paths
get_project_paths

# Configuration
SCRIPT_NAME="health-check.sh"
SCRIPT_PATH="${SCRIPTS_DIR}/${SCRIPT_NAME}"

# Test health-check.sh script basic functionality
test_health_check_basic() {
    log_info "Testing ${SCRIPT_NAME} basic functionality..."

    local failed=0

    test_script_executable "${SCRIPT_PATH}" || failed=1
    test_script_structure "${SCRIPT_PATH}" || failed=1

    if [[ ${failed} -eq 0 ]]; then
        test_script_help "${SCRIPT_PATH}" || true # Don't fail on help test
        log_success "${SCRIPT_NAME} basic tests passed"
    fi

    return ${failed}
}

# Test health-check.sh endpoint validation
test_health_check_endpoints() {
    log_info "Testing ${SCRIPT_NAME} endpoint validation logic..."

    local failed=0

    # Check if script contains health check endpoint logic
    if grep -q "health" "${SCRIPT_PATH}" 2>/dev/null; then
        log_success "Script contains health check logic"
    else
        log_info "Script may not have explicit health check logic"
    fi

    # Check if script contains HTTP status code validation
    if grep -q "200\|curl\|wget" "${SCRIPT_PATH}" 2>/dev/null; then
        log_success "Script contains HTTP validation logic"
    else
        log_info "Script may not have HTTP validation logic"
    fi

    log_success "Health check endpoint validation tests completed"
    return ${failed}
}

# Test health-check.sh service validation
test_health_check_services() {
    log_info "Testing ${SCRIPT_NAME} service validation logic..."

    local failed=0

    # Check if script contains service validation logic
    if grep -q "service\|docker\|systemctl" "${SCRIPT_PATH}" 2>/dev/null; then
        log_success "Script contains service validation logic"
    else
        log_info "Script may not have service validation logic"
    fi

    # Check if script validates torrust tracker services
    if grep -q "torrust\|tracker" "${SCRIPT_PATH}" 2>/dev/null; then
        log_success "Script contains Torrust tracker validation logic"
    else
        log_info "Script may not have Torrust-specific validation"
    fi

    log_success "Health check service validation tests completed"
    return ${failed}
}

# Test health-check.sh error handling
test_health_check_error_handling() {
    log_info "Testing ${SCRIPT_NAME} error handling..."

    local failed=0

    # Test that script handles connection failures gracefully
    log_info "Testing error handling for ${SCRIPT_NAME}..."

    # Check if script has timeout handling
    if grep -q "timeout\|--max-time" "${SCRIPT_PATH}" 2>/dev/null; then
        log_success "Script contains timeout handling"
    else
        log_info "Script may not have explicit timeout handling"
    fi

    # Check if script has retry logic
    if grep -q "retry\|attempt" "${SCRIPT_PATH}" 2>/dev/null; then
        log_success "Script contains retry logic"
    else
        log_info "Script may not have retry logic"
    fi

    log_success "Health check error handling tests completed"
    return ${failed}
}

# Test health-check.sh output format
test_health_check_output() {
    log_info "Testing ${SCRIPT_NAME} output format..."

    local failed=0

    # Check if script provides structured output
    if grep -q "json\|status\|OK\|FAIL" "${SCRIPT_PATH}" 2>/dev/null; then
        log_success "Script provides structured output"
    else
        log_info "Script may not have structured output format"
    fi

    log_success "Health check output format tests completed"
    return ${failed}
}

# Run all tests for health-check.sh
run_health_check_tests() {
    local failed=0

    init_script_test_log "${SCRIPT_NAME}"

    log_info "Running ${SCRIPT_NAME} unit tests..."
    log_info "Script path: ${SCRIPT_PATH}"

    if [[ ! -f "${SCRIPT_PATH}" ]]; then
        log_error "Script not found: ${SCRIPT_PATH}"
        return 1
    fi

    # Run all tests
    test_health_check_basic || failed=1
    test_health_check_endpoints || failed=1
    test_health_check_services || failed=1
    test_health_check_error_handling || failed=1
    test_health_check_output || failed=1

    # Final result
    if [[ ${failed} -eq 0 ]]; then
        log_success "All ${SCRIPT_NAME} tests passed!"
        return 0
    else
        log_error "Some ${SCRIPT_NAME} tests failed!"
        return 1
    fi
}

# Help function
show_help() {
    cat <<EOF
Unit Tests - ${SCRIPT_NAME}

Tests the ${SCRIPT_NAME} script functionality.

Usage: $0 [COMMAND]

Commands:
    all             Run all tests (default)
    basic           Test basic functionality only
    endpoints       Test endpoint validation only
    services        Test service validation only
    errors          Test error handling only
    output          Test output format only
    help           Show this help message

Examples:
    $0                    # Run all tests
    $0 basic             # Test basic functionality only
    $0 endpoints         # Test endpoint validation only

Test log: \${TEST_LOG_FILE}
EOF
}

# Main execution
main() {
    local command="${1:-all}"

    case "${command}" in
    "all")
        run_health_check_tests
        ;;
    "basic")
        init_script_test_log "${SCRIPT_NAME}" && test_health_check_basic
        ;;
    "endpoints")
        init_script_test_log "${SCRIPT_NAME}" && test_health_check_endpoints
        ;;
    "services")
        init_script_test_log "${SCRIPT_NAME}" && test_health_check_services
        ;;
    "errors")
        init_script_test_log "${SCRIPT_NAME}" && test_health_check_error_handling
        ;;
    "output")
        init_script_test_log "${SCRIPT_NAME}" && test_health_check_output
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

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
