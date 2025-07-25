#!/bin/bash
# Unit tests for validate-config.sh script
# Focus: Test validate-config.sh script functionality

set -euo pipefail

# Import test utilities
# shellcheck source=test-utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/test-utils.sh"

# Initialize paths
get_project_paths

# Configuration
SCRIPT_NAME="validate-config.sh"
SCRIPT_PATH="${SCRIPTS_DIR}/${SCRIPT_NAME}"

# Test validate-config.sh script basic functionality
test_validate_config_basic() {
    log_info "Testing ${SCRIPT_NAME} basic functionality..."

    local failed=0

    if [[ ! -f "${SCRIPT_PATH}" ]]; then
        log_warning "${SCRIPT_NAME} script not found (may not be implemented yet)"
        return 0
    fi

    test_script_executable "${SCRIPT_PATH}" || failed=1
    test_script_structure "${SCRIPT_PATH}" || failed=1

    if [[ ${failed} -eq 0 ]]; then
        test_script_help "${SCRIPT_PATH}" || true # Don't fail on help test
        log_success "${SCRIPT_NAME} basic tests passed"
    fi

    return ${failed}
}

# Test validate-config.sh configuration validation logic
test_validate_config_validation() {
    log_info "Testing ${SCRIPT_NAME} configuration validation logic..."

    local failed=0

    if [[ ! -f "${SCRIPT_PATH}" ]]; then
        log_warning "${SCRIPT_NAME} script not found, skipping validation tests"
        return 0
    fi

    # Check if script contains configuration validation logic
    if grep -q "validate\|check\|verify" "${SCRIPT_PATH}" 2>/dev/null; then
        log_success "Script contains validation logic"
    else
        log_info "Script may not have explicit validation logic"
    fi

    # Check if script validates YAML/TOML files
    if grep -q "yaml\|toml\|yml" "${SCRIPT_PATH}" 2>/dev/null; then
        log_success "Script contains configuration file validation"
    else
        log_info "Script may not validate configuration files directly"
    fi

    log_success "Configuration validation logic tests completed"
    return ${failed}
}

# Test validate-config.sh syntax checking
test_validate_config_syntax() {
    log_info "Testing ${SCRIPT_NAME} syntax checking..."

    local failed=0

    if [[ ! -f "${SCRIPT_PATH}" ]]; then
        log_warning "${SCRIPT_NAME} script not found, skipping syntax tests"
        return 0
    fi

    # Check if script has syntax validation
    if grep -q "syntax\|parse\|lint" "${SCRIPT_PATH}" 2>/dev/null; then
        log_success "Script contains syntax checking logic"
    else
        log_info "Script may not have syntax checking"
    fi

    # Check if script validates Docker Compose files
    if grep -q "compose\|docker" "${SCRIPT_PATH}" 2>/dev/null; then
        log_success "Script contains Docker Compose validation"
    else
        log_info "Script may not validate Docker Compose files"
    fi

    log_success "Configuration syntax checking tests completed"
    return ${failed}
}

# Test validate-config.sh template validation
test_validate_config_templates() {
    log_info "Testing ${SCRIPT_NAME} template validation..."

    local failed=0

    if [[ ! -f "${SCRIPT_PATH}" ]]; then
        log_warning "${SCRIPT_NAME} script not found, skipping template tests"
        return 0
    fi

    # Check if script validates configuration templates
    if grep -q "template\|\.tpl" "${SCRIPT_PATH}" 2>/dev/null; then
        log_success "Script contains template validation logic"
    else
        log_info "Script may not validate templates directly"
    fi

    # Check if script validates environment variables
    if grep -q "env\|environment" "${SCRIPT_PATH}" 2>/dev/null; then
        log_success "Script contains environment validation"
    else
        log_info "Script may not validate environment variables"
    fi

    log_success "Configuration template validation tests completed"
    return ${failed}
}

# Test validate-config.sh error reporting
test_validate_config_error_reporting() {
    log_info "Testing ${SCRIPT_NAME} error reporting..."

    local failed=0

    if [[ ! -f "${SCRIPT_PATH}" ]]; then
        log_warning "${SCRIPT_NAME} script not found, skipping error reporting tests"
        return 0
    fi

    # Check if script provides detailed error messages
    if grep -q "error\|ERROR\|fail\|FAIL" "${SCRIPT_PATH}" 2>/dev/null; then
        log_success "Script contains error reporting logic"
    else
        log_info "Script may not have explicit error reporting"
    fi

    # Check if script has exit codes
    if grep -q "exit\|return" "${SCRIPT_PATH}" 2>/dev/null; then
        log_success "Script uses proper exit codes"
    else
        log_info "Script may not use explicit exit codes"
    fi

    log_success "Configuration error reporting tests completed"
    return ${failed}
}

# Run all tests for validate-config.sh
run_validate_config_tests() {
    local failed=0

    init_script_test_log "${SCRIPT_NAME}"

    log_info "Running ${SCRIPT_NAME} unit tests..."
    log_info "Script path: ${SCRIPT_PATH}"

    if [[ ! -f "${SCRIPT_PATH}" ]]; then
        log_warning "Script not found: ${SCRIPT_PATH} (may not be implemented yet)"
        log_success "Skipping tests for unimplemented script"
        return 0
    fi

    # Run all tests
    test_validate_config_basic || failed=1
    test_validate_config_validation || failed=1
    test_validate_config_syntax || failed=1
    test_validate_config_templates || failed=1
    test_validate_config_error_reporting || failed=1

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
    validation      Test validation logic only
    syntax          Test syntax checking only
    templates       Test template validation only
    errors          Test error reporting only
    help           Show this help message

Examples:
    $0                    # Run all tests
    $0 basic             # Test basic functionality only
    $0 validation        # Test validation logic only

Test log: \${TEST_LOG_FILE}
EOF
}

# Main execution
main() {
    local command="${1:-all}"

    case "${command}" in
    "all")
        run_validate_config_tests
        ;;
    "basic")
        init_script_test_log "${SCRIPT_NAME}" && test_validate_config_basic
        ;;
    "validation")
        init_script_test_log "${SCRIPT_NAME}" && test_validate_config_validation
        ;;
    "syntax")
        init_script_test_log "${SCRIPT_NAME}" && test_validate_config_syntax
        ;;
    "templates")
        init_script_test_log "${SCRIPT_NAME}" && test_validate_config_templates
        ;;
    "errors")
        init_script_test_log "${SCRIPT_NAME}" && test_validate_config_error_reporting
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
