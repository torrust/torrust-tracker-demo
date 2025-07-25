#!/bin/bash
# Unit tests for project-wide validation
# Focus: Validate project-wide configuration, Makefile, tools, and overall structure
# Scope: Tests that span both infrastructure and application layers

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_LOG_FILE="/tmp/torrust-unit-project-test.log"

# Source shared shell utilities
# shellcheck source=../scripts/shell-utils.sh
source "${PROJECT_ROOT}/scripts/shell-utils.sh"

# Set log file for tee output
export SHELL_UTILS_LOG_FILE="${TEST_LOG_FILE}"

# Initialize test log
init_test_log() {
    init_log_file "${TEST_LOG_FILE}" "Unit Tests - Project-wide Validation"
    log_info "Project Root: ${PROJECT_ROOT}"
}

# Test Makefile syntax
test_makefile_syntax() {
    log_info "Testing Makefile syntax..."

    local makefile="${PROJECT_ROOT}/Makefile"
    local failed=0

    if [[ ! -f "${makefile}" ]]; then
        log_error "Makefile not found: ${makefile}"
        return 1
    fi

    cd "${PROJECT_ROOT}"

    # Test that make can parse the Makefile
    if ! make -n help >/dev/null 2>&1; then
        log_error "Makefile syntax error"
        failed=1
    else
        log_success "Makefile syntax is valid"
    fi

    return ${failed}
}

# Test that required tools are available
test_required_tools() {
    log_info "Testing required tools availability..."

    local failed=0
    local required_tools=("git" "make" "ssh" "scp")
    local optional_tools=("tofu" "terraform" "docker" "yamllint" "shellcheck")

    # Test required tools
    for tool in "${required_tools[@]}"; do
        if ! command -v "${tool}" >/dev/null 2>&1; then
            log_error "Required tool not found: ${tool}"
            failed=1
        fi
    done

    # Test optional tools (warn but don't fail)
    for tool in "${optional_tools[@]}"; do
        if ! command -v "${tool}" >/dev/null 2>&1; then
            # Special handling for terraform/tofu - only warn if neither is available
            if [[ "${tool}" == "terraform" ]]; then
                if ! command -v "tofu" >/dev/null 2>&1; then
                    log_warning "Neither OpenTofu nor Terraform found (continuing without validation)"
                fi
            elif [[ "${tool}" != "tofu" ]]; then
                log_warning "Optional tool not found: ${tool}"
            fi
        fi
    done

    if [[ ${failed} -eq 0 ]]; then
        log_success "All required tools are available"
    fi

    return ${failed}
}

# Test project structure
test_project_structure() {
    log_info "Testing project structure..."

    local failed=0
    local required_paths=(
        "Makefile"
        "infrastructure/terraform"
        "infrastructure/scripts"
        "infrastructure/cloud-init"
        "infrastructure/tests"
        "application/compose.yaml"
        "application/tests"
        "docs/guides"
        "tests"
    )

    cd "${PROJECT_ROOT}"

    for path in "${required_paths[@]}"; do
        if [[ ! -e "${path}" ]]; then
            log_error "Required path missing: ${path}"
            failed=1
        fi
    done

    if [[ ${failed} -eq 0 ]]; then
        log_success "Project structure is valid"
    fi

    return ${failed}
}

# Test project documentation structure
test_documentation_structure() {
    log_info "Testing documentation structure..."

    local failed=0
    local required_docs=(
        "README.md"
        "docs/README.md"
        "infrastructure/README.md"
        "application/README.md"
        "tests/README.md"
    )

    cd "${PROJECT_ROOT}"

    for doc in "${required_docs[@]}"; do
        if [[ ! -f "${doc}" ]]; then
            log_error "Required documentation missing: ${doc}"
            failed=1
        fi
    done

    if [[ ${failed} -eq 0 ]]; then
        log_success "Documentation structure is valid"
    fi

    return ${failed}
}

# Test that test organization is correct
test_test_organization() {
    log_info "Testing test organization..."

    local failed=0

    # Check that each layer has its own test directory
    local test_dirs=(
        "infrastructure/tests"
        "application/tests"
        "tests"
    )

    cd "${PROJECT_ROOT}"

    for test_dir in "${test_dirs[@]}"; do
        if [[ ! -d "${test_dir}" ]]; then
            log_error "Missing test directory: ${test_dir}"
            failed=1
        else
            # Check that the test directory has executable test scripts
            if find "${test_dir}" -name "test-*.sh" -executable | grep -q .; then
                log_info "Found test scripts in: ${test_dir}"
            else
                log_warning "No executable test scripts found in: ${test_dir}"
            fi
        fi
    done

    if [[ ${failed} -eq 0 ]]; then
        log_success "Test organization is valid"
    fi

    return ${failed}
}

# Run all project-wide unit tests
run_project_tests() {
    local failed=0

    init_test_log

    log_info "Running project-wide unit tests..."
    log_info "Project directory: ${PROJECT_ROOT}"

    # Run all project-wide tests
    test_required_tools || failed=1
    test_project_structure || failed=1
    test_documentation_structure || failed=1
    test_test_organization || failed=1
    test_makefile_syntax || failed=1

    # Final result
    if [[ ${failed} -eq 0 ]]; then
        log_success "All project-wide unit tests passed!"
        log_info "Test log: ${TEST_LOG_FILE}"
        return 0
    else
        log_error "Some project-wide unit tests failed!"
        log_error "Check test log for details: ${TEST_LOG_FILE}"
        return 1
    fi
}

# Help function
show_help() {
    cat <<EOF
Unit Tests - Project-wide Validation

Tests project-wide configuration, Makefile, tools, and overall structure.
Validates components that span both infrastructure and application layers.

Usage: $0 [COMMAND]

Commands:
    full-test       Run all project-wide tests (default)
    makefile        Test Makefile syntax only
    tools           Test required tools availability only
    structure       Test project structure only
    docs            Test documentation structure only
    tests           Test test organization only
    help           Show this help message

Examples:
    $0                    # Run all project-wide tests
    $0 makefile          # Test Makefile only
    $0 tools             # Test required tools only

Project Root: ${PROJECT_ROOT}
Test log: ${TEST_LOG_FILE}
EOF
}

# Main execution
main() {
    local command="${1:-full-test}"

    case "${command}" in
    "full-test")
        run_project_tests
        ;;
    "makefile")
        init_test_log && test_makefile_syntax
        ;;
    "tools")
        init_test_log && test_required_tools
        ;;
    "structure")
        init_test_log && test_project_structure
        ;;
    "docs")
        init_test_log && test_documentation_structure
        ;;
    "tests")
        init_test_log && test_test_organization
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
