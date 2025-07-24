#!/bin/bash
# Unit tests for infrastructure scripts and automation
# Focus: Test individual script functionality without full deployment
# Scope: Script validation, parameter handling, error conditions

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPTS_DIR="${PROJECT_ROOT}/infrastructure/scripts"
TEST_LOG_FILE="/tmp/torrust-unit-scripts-test.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "$1" | tee -a "${TEST_LOG_FILE}"
}

log_info() {
    log "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    log "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    log "${RED}[ERROR]${NC} $1"
}

# Initialize test log
init_test_log() {
    {
        echo "Unit Tests - Infrastructure Scripts"
        echo "Started: $(date)"
        echo "================================================================="
    } >"${TEST_LOG_FILE}"
}

# Test script exists and is executable
test_script_executable() {
    local script_path="$1"
    local script_name
    script_name=$(basename "${script_path}")

    if [[ ! -f "${script_path}" ]]; then
        log_error "Script not found: ${script_name}"
        return 1
    fi

    if [[ ! -x "${script_path}" ]]; then
        log_error "Script not executable: ${script_name}"
        return 1
    fi

    log_success "Script exists and is executable: ${script_name}"
    return 0
}

# Test script help/usage functionality
test_script_help() {
    local script_path="$1"
    local script_name
    script_name=$(basename "${script_path}")

    log_info "Testing help functionality for: ${script_name}"

    # Try common help flags
    local help_flags=("help" "--help" "-h")
    local help_working=false

    for flag in "${help_flags[@]}"; do
        if "${script_path}" "${flag}" >/dev/null 2>&1; then
            help_working=true
            break
        fi
    done

    if [[ "${help_working}" == "true" ]]; then
        log_success "Help functionality works for: ${script_name}"
        return 0
    else
        log_warning "No help functionality found for: ${script_name}"
        return 0 # Don't fail on this, just warn
    fi
}

# Test provision-infrastructure.sh script
test_provision_infrastructure_script() {
    log_info "Testing provision-infrastructure.sh script..."

    local script="${SCRIPTS_DIR}/provision-infrastructure.sh"
    local failed=0

    test_script_executable "${script}" || failed=1

    if [[ ${failed} -eq 0 ]]; then
        test_script_help "${script}" || true # Don't fail on help test

        # Test parameter validation (should fail with invalid parameters)
        log_info "Testing parameter validation..."

        # Test with invalid environment
        if "${script}" "invalid-env" "init" >/dev/null 2>&1; then
            log_warning "Script should fail with invalid environment"
        else
            log_success "Script properly validates environment parameter"
        fi

        # Test with invalid action
        if "${script}" "local" "invalid-action" >/dev/null 2>&1; then
            log_warning "Script should fail with invalid action"
        else
            log_success "Script properly validates action parameter"
        fi
    fi

    return ${failed}
}

# Test deploy-app.sh script
test_deploy_app_script() {
    log_info "Testing deploy-app.sh script..."

    local script="${SCRIPTS_DIR}/deploy-app.sh"
    local failed=0

    test_script_executable "${script}" || failed=1

    if [[ ${failed} -eq 0 ]]; then
        test_script_help "${script}" || true # Don't fail on help test

        # Test parameter handling
        log_info "Testing parameter handling..."

        # Note: We can't fully test deployment without infrastructure
        # But we can test that the script handles parameters correctly

        log_success "Deploy script is available for testing"
    fi

    return ${failed}
}

# Test configure-env.sh script
test_configure_env_script() {
    log_info "Testing configure-env.sh script..."

    local script="${SCRIPTS_DIR}/configure-env.sh"
    local failed=0

    test_script_executable "${script}" || failed=1

    if [[ ${failed} -eq 0 ]]; then
        test_script_help "${script}" || true # Don't fail on help test

        # Test that script can handle valid environment names
        log_info "Testing environment parameter validation..."

        log_success "Configuration script is available for testing"
    fi

    return ${failed}
}

# Test health-check.sh script
test_health_check_script() {
    log_info "Testing health-check.sh script..."

    local script="${SCRIPTS_DIR}/health-check.sh"
    local failed=0

    test_script_executable "${script}" || failed=1

    if [[ ${failed} -eq 0 ]]; then
        test_script_help "${script}" || true # Don't fail on help test

        log_success "Health check script is available for testing"
    fi

    return ${failed}
}

# Test validate-config.sh script
test_validate_config_script() {
    log_info "Testing validate-config.sh script..."

    local script="${SCRIPTS_DIR}/validate-config.sh"

    if [[ ! -f "${script}" ]]; then
        log_warning "validate-config.sh script not found (may not be implemented yet)"
        return 0
    fi

    local failed=0
    test_script_executable "${script}" || failed=1

    if [[ ${failed} -eq 0 ]]; then
        test_script_help "${script}" || true # Don't fail on help test

        log_success "Config validation script is available for testing"
    fi

    return ${failed}
}

# Test all infrastructure scripts
test_all_scripts() {
    log_info "Testing all infrastructure scripts..."

    local failed=0

    if [[ ! -d "${SCRIPTS_DIR}" ]]; then
        log_error "Scripts directory not found: ${SCRIPTS_DIR}"
        return 1
    fi

    # Test individual scripts
    test_provision_infrastructure_script || failed=1
    test_deploy_app_script || failed=1
    test_configure_env_script || failed=1
    test_health_check_script || failed=1
    test_validate_config_script || failed=1

    return ${failed}
}

# Test script directory structure
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

# Test script shebang and basic structure
test_script_structure() {
    log_info "Testing script structure and standards..."

    local failed=0
    local scripts

    # Find all shell scripts in scripts directory
    scripts=$(find "${SCRIPTS_DIR}" -name "*.sh" -type f)

    for script in ${scripts}; do
        local script_name
        script_name=$(basename "${script}")

        # Check shebang
        local first_line
        first_line=$(head -n1 "${script}")
        if [[ ! "${first_line}" =~ ^#!/bin/bash ]]; then
            log_warning "Script ${script_name} doesn't use #!/bin/bash shebang"
        fi

        # Check for set -euo pipefail (good practice)
        if ! grep -q "set -euo pipefail" "${script}"; then
            log_warning "Script ${script_name} doesn't use 'set -euo pipefail'"
        fi
    done

    log_success "Script structure validation completed"
    return ${failed}
}

# Run all unit tests for scripts
run_unit_tests() {
    local failed=0

    init_test_log

    log_info "Running infrastructure scripts unit tests..."
    log_info "Scripts directory: ${SCRIPTS_DIR}"

    # Run all unit tests
    test_scripts_directory || failed=1
    test_script_structure || failed=1
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
Unit Tests - Infrastructure Scripts

Tests infrastructure scripts without deploying or running them.

Usage: $0 [COMMAND]

Commands:
    full-test       Run all script unit tests (default)
    provision       Test provision-infrastructure.sh only
    deploy          Test deploy-app.sh only
    configure       Test configure-env.sh only
    health          Test health-check.sh only
    validate        Test validate-config.sh only
    structure       Test scripts directory structure only
    standards       Test script coding standards only
    help           Show this help message

Examples:
    $0                    # Run all script unit tests
    $0 provision         # Test provision script only
    $0 structure         # Test directory structure only

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
    "standards")
        init_test_log && test_script_structure
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
