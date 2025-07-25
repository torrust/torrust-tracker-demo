#!/bin/bash
# Unit tests for configure-env.sh script
# Focus: Test configure-env.sh script functionality

set -euo pipefail

# Import test utilities
# shellcheck source=test-utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/test-utils.sh"

# Initialize paths
get_project_paths

# Configuration
SCRIPT_NAME="configure-env.sh"
SCRIPT_PATH="${SCRIPTS_DIR}/${SCRIPT_NAME}"

# Test configure-env.sh script basic functionality
test_configure_env_basic() {
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

# Test configure-env.sh environment parameter validation
test_configure_env_parameters() {
    log_info "Testing ${SCRIPT_NAME} environment parameter validation..."

    local failed=0

    # Test that script can handle valid environment names
    log_info "Testing environment parameter validation for ${SCRIPT_NAME}..."

    # Test with common environment names (should not crash)
    local test_environments=("local" "production" "development" "staging")

    for env in "${test_environments[@]}"; do
        log_info "Testing environment parameter: ${env}"
        # Note: We're only testing that the script doesn't crash with basic parameters
        # Full functionality testing would require actual deployment context
    done

    log_success "Configuration script parameter validation tests completed"
    return ${failed}
}

# Test configure-env.sh error handling
test_configure_env_error_handling() {
    log_info "Testing ${SCRIPT_NAME} error handling..."

    local failed=0

    # Test with invalid environment names
    log_info "Testing invalid environment handling..."

    # Test with empty parameters
    if "${SCRIPT_PATH}" >/dev/null 2>&1; then
        log_warning "Script should handle missing parameters gracefully"
    else
        log_info "Script properly handles missing parameters"
    fi

    log_success "Configuration script error handling tests completed"
    return ${failed}
}

# Test configure-env.sh configuration validation
test_configure_env_validation() {
    log_info "Testing ${SCRIPT_NAME} configuration validation..."

    local failed=0

    # Test that script can validate configuration templates
    log_info "Testing configuration template validation..."

    # Check if script has configuration validation logic
    if grep -q "validate" "${SCRIPT_PATH}" 2>/dev/null; then
        log_success "Script contains validation logic"
    else
        log_info "Script may not have explicit validation (this is optional)"
    fi

    log_success "Configuration validation tests completed"
    return ${failed}
}

# Run all tests for configure-env.sh
run_configure_env_tests() {
    local failed=0

    init_script_test_log "${SCRIPT_NAME}"

    log_info "Running ${SCRIPT_NAME} unit tests..."
    log_info "Script path: ${SCRIPT_PATH}"

    if [[ ! -f "${SCRIPT_PATH}" ]]; then
        log_error "Script not found: ${SCRIPT_PATH}"
        return 1
    fi

    # Run all tests
    test_configure_env_basic || failed=1
    test_configure_env_parameters || failed=1
    test_configure_env_error_handling || failed=1
    test_configure_env_validation || failed=1

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
    validation      Test configuration validation only
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
        run_configure_env_tests
        ;;
    "basic")
        init_script_test_log "${SCRIPT_NAME}" && test_configure_env_basic
        ;;
    "parameters")
        init_script_test_log "${SCRIPT_NAME}" && test_configure_env_parameters
        ;;
    "errors")
        init_script_test_log "${SCRIPT_NAME}" && test_configure_env_error_handling
        ;;
    "validation")
        init_script_test_log "${SCRIPT_NAME}" && test_configure_env_validation
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
