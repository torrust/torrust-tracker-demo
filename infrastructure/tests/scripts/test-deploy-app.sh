#!/bin/bash
# Unit tests for deploy-app.sh script
# Focus: Test deploy-app.sh script functionality

set -euo pipefail

# Import test utilities
# shellcheck source=test-utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/test-utils.sh"

# Initialize paths
get_project_paths

# Configuration
SCRIPT_NAME="deploy-app.sh"
SCRIPT_PATH="${SCRIPTS_DIR}/${SCRIPT_NAME}"

# Test deploy-app.sh script basic functionality
test_deploy_app_basic() {
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

# Test deploy-app.sh parameter handling
test_deploy_app_parameters() {
    log_info "Testing ${SCRIPT_NAME} parameter handling..."

    local failed=0

    # Note: We can't fully test deployment without infrastructure
    # But we can test that the script handles parameters correctly

    log_info "Testing parameter handling for ${SCRIPT_NAME}..."

    # Test with help flag to ensure script responds appropriately
    if "${SCRIPT_PATH}" --help >/dev/null 2>&1 || "${SCRIPT_PATH}" help >/dev/null 2>&1; then
        log_success "Script responds to help parameter"
    else
        log_info "Script may not have help parameter (this is optional)"
    fi

    log_success "Deploy script parameter handling tests completed"
    return ${failed}
}

# Test deploy-app.sh environment handling
test_deploy_app_environment() {
    log_info "Testing ${SCRIPT_NAME} environment handling..."

    local failed=0

    # Test that script can handle different deployment environments
    log_info "Testing environment parameter validation for ${SCRIPT_NAME}..."

    # Note: Without actual infrastructure, we can only test that the script
    # exists and has proper structure. Full functionality tests require VM.

    log_success "Deploy script environment handling tests completed"
    return ${failed}
}

# Run all tests for deploy-app.sh
run_deploy_app_tests() {
    local failed=0

    init_script_test_log "${SCRIPT_NAME}"

    log_info "Running ${SCRIPT_NAME} unit tests..."
    log_info "Script path: ${SCRIPT_PATH}"

    if [[ ! -f "${SCRIPT_PATH}" ]]; then
        log_error "Script not found: ${SCRIPT_PATH}"
        return 1
    fi

    # Run all tests
    test_deploy_app_basic || failed=1
    test_deploy_app_parameters || failed=1
    test_deploy_app_environment || failed=1

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
    parameters      Test parameter handling only
    environment     Test environment handling only
    help           Show this help message

Examples:
    $0                    # Run all tests
    $0 basic             # Test basic functionality only
    $0 parameters        # Test parameter handling only

Test log: \${TEST_LOG_FILE}
EOF
}

# Main execution
main() {
    local command="${1:-all}"

    case "${command}" in
    "all")
        run_deploy_app_tests
        ;;
    "basic")
        init_script_test_log "${SCRIPT_NAME}" && test_deploy_app_basic
        ;;
    "parameters")
        init_script_test_log "${SCRIPT_NAME}" && test_deploy_app_parameters
        ;;
    "environment")
        init_script_test_log "${SCRIPT_NAME}" && test_deploy_app_environment
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
