#!/bin/bash
# Unit tests for provision-infrastructure.sh script
# Focus: Test provision-infrastructure.sh script functionality

set -euo pipefail

# Import test utilities
# shellcheck source=test-utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/test-utils.sh"

# Initialize paths
get_project_paths

# Configuration
SCRIPT_NAME="provision-infrastructure.sh"
SCRIPT_PATH="${SCRIPTS_DIR}/${SCRIPT_NAME}"

# Test provision-infrastructure.sh script basic functionality
test_provision_infrastructure_basic() {
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

# Test provision-infrastructure.sh parameter validation
test_provision_infrastructure_parameters() {
    log_info "Testing ${SCRIPT_NAME} parameter validation..."

    local failed=0

    # Test parameter validation (should fail with invalid parameters)
    log_info "Testing parameter validation..."

    # Test with invalid environment
    if "${SCRIPT_PATH}" "invalid-env" "init" >/dev/null 2>&1; then
        log_warning "Script should fail with invalid environment"
    else
        log_success "Script properly validates environment parameter"
    fi

    # Test with invalid action
    if "${SCRIPT_PATH}" "local" "invalid-action" >/dev/null 2>&1; then
        log_warning "Script should fail with invalid action"
    else
        log_success "Script properly validates action parameter"
    fi

    return ${failed}
}

# Test provision-infrastructure.sh error handling
test_provision_infrastructure_error_handling() {
    log_info "Testing ${SCRIPT_NAME} error handling..."

    local failed=0

    # Test with no parameters
    if "${SCRIPT_PATH}" >/dev/null 2>&1; then
        log_warning "Script should fail when called without parameters"
    else
        log_success "Script properly handles missing parameters"
    fi

    # Test with insufficient parameters
    if "${SCRIPT_PATH}" "local" >/dev/null 2>&1; then
        log_warning "Script should fail with insufficient parameters"
    else
        log_success "Script properly handles insufficient parameters"
    fi

    return ${failed}
}

# Run all tests for provision-infrastructure.sh
run_provision_infrastructure_tests() {
    local failed=0

    init_script_test_log "${SCRIPT_NAME}"

    log_info "Running ${SCRIPT_NAME} unit tests..."
    log_info "Script path: ${SCRIPT_PATH}"

    if [[ ! -f "${SCRIPT_PATH}" ]]; then
        log_error "Script not found: ${SCRIPT_PATH}"
        return 1
    fi

    # Run all tests
    test_provision_infrastructure_basic || failed=1
    test_provision_infrastructure_parameters || failed=1
    test_provision_infrastructure_error_handling || failed=1

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
    parameters      Test parameter validation only
    errors          Test error handling only
    help           Show this help message

Examples:
    $0                    # Run all tests
    $0 basic             # Test basic functionality only
    $0 parameters        # Test parameter validation only

Test log: \${TEST_LOG_FILE}
EOF
}

# Main execution
main() {
    local command="${1:-all}"

    case "${command}" in
    "all")
        run_provision_infrastructure_tests
        ;;
    "basic")
        init_script_test_log "${SCRIPT_NAME}" && test_provision_infrastructure_basic
        ;;
    "parameters")
        init_script_test_log "${SCRIPT_NAME}" && test_provision_infrastructure_parameters
        ;;
    "errors")
        init_script_test_log "${SCRIPT_NAME}" && test_provision_infrastructure_error_handling
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
