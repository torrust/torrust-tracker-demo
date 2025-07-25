#!/bin/bash
# Unit tests orchestrator for infrastructure scripts
# Focus: Coordinate individual script test files
# Scope: Run all script tests in organized manner

set -euo pipefail

# Import test utilities
# shellcheck source=scripts/test-utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/scripts/test-utils.sh"

# Initialize paths
get_project_paths

# Configuration
TEST_LOG_FILE="/tmp/torrust-unit-scripts-test.log"
INFRASTRUCTURE_TESTS_DIR="${PROJECT_ROOT}/infrastructure/tests"
SCRIPTS_TEST_DIR="${INFRASTRUCTURE_TESTS_DIR}/scripts"

# Individual test files
INDIVIDUAL_TEST_FILES=(
    "test-provision-infrastructure.sh"
    "test-deploy-app.sh"
    "test-configure-env.sh"
    "test-health-check.sh"
    "test-validate-config.sh"
)

# Initialize test log
init_test_log() {
    {
        echo "Unit Tests - Infrastructure Scripts (Orchestrator)"
        echo "Started: $(date)"
        echo "================================================================="
    } >"${TEST_LOG_FILE}"
    export TEST_LOG_FILE
}

# Run individual test file
run_individual_test() {
    local test_file="$1"
    local test_path="${SCRIPTS_TEST_DIR}/${test_file}"

    if [[ ! -f "${test_path}" ]]; then
        log_error "Test file not found: ${test_path}"
        return 1
    fi

    if [[ ! -x "${test_path}" ]]; then
        log_error "Test file not executable: ${test_path}"
        return 1
    fi

    log_info "Running individual test: ${test_file}"

    if "${test_path}" all; then
        log_success "Individual test passed: ${test_file}"
        return 0
    else
        log_error "Individual test failed: ${test_file}"
        return 1
    fi
}

# Test provision-infrastructure.sh script
test_provision_infrastructure_script() {
    log_info "Testing provision-infrastructure.sh script..."
    run_individual_test "test-provision-infrastructure.sh"
}

# Test deploy-app.sh script
test_deploy_app_script() {
    log_info "Testing deploy-app.sh script..."
    run_individual_test "test-deploy-app.sh"
}

# Test configure-env.sh script
test_configure_env_script() {
    log_info "Testing configure-env.sh script..."
    run_individual_test "test-configure-env.sh"
}

# Test health-check.sh script
# Test health-check.sh script
test_health_check_script() {
    log_info "Testing health-check.sh script..."
    run_individual_test "test-health-check.sh"
}

# Test validate-config.sh script
test_validate_config_script() {
    log_info "Testing validate-config.sh script..."
    run_individual_test "test-validate-config.sh"
}

# Test all infrastructure scripts
test_all_scripts() {
    log_info "Testing all infrastructure scripts via individual test files..."

    local failed=0

    if [[ ! -d "${SCRIPTS_DIR}" ]]; then
        log_error "Scripts directory not found: ${SCRIPTS_DIR}"
        return 1
    fi

    if [[ ! -d "${TESTS_DIR}" ]]; then
        log_error "Tests directory not found: ${TESTS_DIR}"
        return 1
    fi

    # Test individual scripts via their dedicated test files
    test_provision_infrastructure_script || failed=1
    test_deploy_app_script || failed=1
    test_configure_env_script || failed=1
    test_health_check_script || failed=1
    test_validate_config_script || failed=1

    return ${failed}
}

# Test scripts directory structure
test_scripts_directory() {
    log_info "Testing scripts directory structure..."

    local failed=0
    local expected_scripts=(
        "provision-infrastructure.sh"
        "deploy-app.sh"
        "configure-env.sh"
        "health-check.sh"
    )

    if [[ ! -d "${SCRIPTS_DIR}" ]]; then
        log_error "Scripts directory not found: ${SCRIPTS_DIR}"
        return 1
    fi

    for script in "${expected_scripts[@]}"; do
        local script_path="${SCRIPTS_DIR}/${script}"
        if [[ ! -f "${script_path}" ]]; then
            log_error "Expected script not found: ${script}"
            failed=1
        fi
    done

    if [[ ${failed} -eq 0 ]]; then
        log_success "Scripts directory structure is valid"
    fi

    return ${failed}
}

# Test individual test files structure
test_individual_test_files() {
    log_info "Testing individual test files structure..."

    local failed=0

    if [[ ! -d "${SCRIPTS_TEST_DIR}" ]]; then
        log_error "Scripts test directory not found: ${SCRIPTS_TEST_DIR}"
        return 1
    fi

    for test_file in "${INDIVIDUAL_TEST_FILES[@]}"; do
        local test_path="${SCRIPTS_TEST_DIR}/${test_file}"

        if [[ ! -f "${test_path}" ]]; then
            log_error "Individual test file not found: ${test_file}"
            failed=1
            continue
        fi

        if [[ ! -x "${test_path}" ]]; then
            log_error "Individual test file not executable: ${test_file}"
            failed=1
            continue
        fi

        log_success "Individual test file exists and is executable: ${test_file}"
    done

    if [[ ${failed} -eq 0 ]]; then
        log_success "Individual test files structure is valid"
    fi

    return ${failed}
}

# Run all unit tests for scripts
run_unit_tests() {
    local failed=0

    init_test_log

    log_info "Running infrastructure scripts unit tests (orchestrator mode)..."
    log_info "Scripts directory: ${SCRIPTS_DIR}"
    log_info "Tests directory: ${TESTS_DIR}"

    # Test directory structures
    test_scripts_directory || failed=1
    test_individual_test_files || failed=1

    # Run all script tests via individual test files
    test_all_scripts || failed=1

    # Final result
    if [[ ${failed} -eq 0 ]]; then
        log_success "All script unit tests passed!"
        log_info "Test log: ${TEST_LOG_FILE}"
        return 0
    else
        log_error "Some script unit tests failed!"
        log_error "Check test log for details: ${TEST_LOG_FILE}"
        return 1
    fi
}

# Help function
show_help() {
    cat <<EOF
Unit Tests - Infrastructure Scripts (Orchestrator)

Coordinates individual script test files for comprehensive testing.

Usage: $0 [COMMAND]

Commands:
    full-test       Run all script unit tests (default)
    provision       Test provision-infrastructure.sh only
    deploy          Test deploy-app.sh only
    configure       Test configure-env.sh only
    health          Test health-check.sh only
    validate        Test validate-config.sh only
    structure       Test scripts directory structure only
    test-files      Test individual test files structure only
    help           Show this help message

Individual Test Files:
    test-provision-infrastructure.sh    Tests provision-infrastructure.sh
    test-deploy-app.sh                  Tests deploy-app.sh
    test-configure-env.sh               Tests configure-env.sh
    test-health-check.sh                Tests health-check.sh
    test-validate-config.sh             Tests validate-config.sh

Examples:
    $0                    # Run all script unit tests
    $0 provision         # Test provision script only
    $0 structure         # Test directory structure only

Note: This orchestrator delegates to individual test files for better
      maintainability and scalability. Each script has its own test file.

Test log: ${TEST_LOG_FILE}
EOF
}

# Main execution
main() {
    local command="${1:-full-test}"

    case "${command}" in
    "full-test")
        run_unit_tests
        ;;
    "provision")
        init_test_log && test_provision_infrastructure_script
        ;;
    "deploy")
        init_test_log && test_deploy_app_script
        ;;
    "configure")
        init_test_log && test_configure_env_script
        ;;
    "health")
        init_test_log && test_health_check_script
        ;;
    "validate")
        init_test_log && test_validate_config_script
        ;;
    "structure")
        init_test_log && test_scripts_directory
        ;;
    "test-files")
        init_test_log && test_individual_test_files
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

# Execute main function
main "$@"
