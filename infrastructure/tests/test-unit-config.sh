#!/bin/bash
# Unit tests for infrastructure provisioning validation
# Focus: Validate infrastructure configuration files, templates, and syntax
# Scope: No infrastructure deployment, only static validation of infrastructure components

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRASTRUCTURE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST_LOG_FILE="/tmp/torrust-unit-infrastructure-test.log"

# Source shared shell utilities
# shellcheck source=../../scripts/shell-utils.sh
source "${PROJECT_ROOT}/scripts/shell-utils.sh"

# Set log file for tee output
export SHELL_UTILS_LOG_FILE="${TEST_LOG_FILE}"

# Initialize test log
init_test_log() {
    init_log_file "${TEST_LOG_FILE}" "Unit Tests - Infrastructure Provisioning Validation"
    log_info "Infrastructure Root: ${INFRASTRUCTURE_ROOT}"
}

# Test Terraform/OpenTofu syntax validation
test_terraform_syntax() {
    log_info "Testing Terraform/OpenTofu syntax validation..."

    local terraform_dir="${INFRASTRUCTURE_ROOT}/terraform"
    local failed=0

    if [[ ! -d "${terraform_dir}" ]]; then
        log_warning "Terraform directory not found: ${terraform_dir}"
        return 0
    fi

    cd "${terraform_dir}"

    # Test Terraform syntax
    if command -v tofu >/dev/null 2>&1; then
        # Initialize if not already done (required for validation)
        if [[ ! -d ".terraform" ]]; then
            log_info "Initializing OpenTofu (required for validation)..."
            if ! tofu init >/dev/null 2>&1; then
                log_error "OpenTofu initialization failed"
                return 1
            fi
        fi

        if ! tofu validate >/dev/null 2>&1; then
            log_error "OpenTofu validation failed"
            failed=1
        else
            log_success "OpenTofu configuration is valid"
        fi
    elif command -v terraform >/dev/null 2>&1; then
        # Initialize if not already done (required for validation)
        if [[ ! -d ".terraform" ]]; then
            log_info "Initializing Terraform (required for validation)..."
            if ! terraform init >/dev/null 2>&1; then
                log_error "Terraform initialization failed"
                return 1
            fi
        fi

        if ! terraform validate >/dev/null 2>&1; then
            log_error "Terraform validation failed"
            failed=1
        else
            log_success "Terraform configuration is valid"
        fi
    else
        log_warning "Neither OpenTofu nor Terraform found - skipping validation"
    fi

    return ${failed}
}

# Test configuration template processing
test_config_templates() {
    log_info "Testing infrastructure configuration template processing..."

    local failed=0
    local template_dir="${INFRASTRUCTURE_ROOT}/config/templates"

    if [[ ! -d "${template_dir}" ]]; then
        log_warning "Infrastructure templates directory not found: ${template_dir}"
        return 0
    fi

    # Test that configuration generation script exists and is executable
    local config_script="${INFRASTRUCTURE_ROOT}/scripts/configure-env.sh"

    if [[ ! -f "${config_script}" ]]; then
        log_error "Configuration script not found: ${config_script}"
        return 1
    fi

    if [[ ! -x "${config_script}" ]]; then
        log_error "Configuration script is not executable: ${config_script}"
        return 1
    fi

    # Test configuration generation (dry-run mode if available)
    cd "${INFRASTRUCTURE_ROOT}"

    # Note: We can't actually run the configuration generation here because
    # it might modify files. This is a limitation of unit testing.
    # In a real scenario, you'd want to test this in a isolated environment.

    log_success "Infrastructure configuration template system is available"
    return ${failed}
}

# Test infrastructure directory structure
test_infrastructure_structure() {
    log_info "Testing infrastructure directory structure..."

    local failed=0
    local required_paths=(
        "terraform"
        "scripts"
        "cloud-init"
        "tests"
        "docs"
    )

    cd "${INFRASTRUCTURE_ROOT}"

    for path in "${required_paths[@]}"; do
        if [[ ! -e "${path}" ]]; then
            log_error "Required infrastructure path missing: ${path}"
            failed=1
        fi
    done

    if [[ ${failed} -eq 0 ]]; then
        log_success "Infrastructure directory structure is valid"
    fi

    return ${failed}
}

# Test cloud-init templates
test_cloud_init_templates() {
    log_info "Testing cloud-init templates..."

    local failed=0
    local cloud_init_dir="${INFRASTRUCTURE_ROOT}/cloud-init"

    if [[ ! -d "${cloud_init_dir}" ]]; then
        log_error "Cloud-init directory not found: ${cloud_init_dir}"
        return 1
    fi

    # Check for required cloud-init files
    local required_files=(
        "user-data.yaml.tpl"
        "meta-data.yaml"
        "network-config.yaml"
    )

    cd "${cloud_init_dir}"

    for file in "${required_files[@]}"; do
        if [[ ! -f "${file}" ]]; then
            log_error "Required cloud-init file missing: ${file}"
            failed=1
        fi
    done

    if [[ ${failed} -eq 0 ]]; then
        log_success "Cloud-init templates are present"
    fi

    return ${failed}
}

# Test infrastructure scripts
test_infrastructure_scripts() {
    log_info "Testing infrastructure scripts..."

    local failed=0
    local scripts_dir="${INFRASTRUCTURE_ROOT}/scripts"

    if [[ ! -d "${scripts_dir}" ]]; then
        log_error "Infrastructure scripts directory not found: ${scripts_dir}"
        return 1
    fi

    # Check for key infrastructure scripts
    local key_scripts=(
        "provision-infrastructure.sh"
        "deploy-app.sh"
        "health-check.sh"
    )

    for script in "${key_scripts[@]}"; do
        local script_path="${scripts_dir}/${script}"
        if [[ -f "${script_path}" ]]; then
            if [[ -x "${script_path}" ]]; then
                log_info "Found executable infrastructure script: ${script}"
            else
                log_warning "Infrastructure script exists but is not executable: ${script}"
            fi
        else
            log_warning "Infrastructure script not found: ${script}"
        fi
    done

    log_success "Infrastructure scripts validation completed"
    return ${failed}
}

# Run all infrastructure unit tests
run_infrastructure_tests() {
    local failed=0

    init_test_log

    log_info "Running infrastructure provisioning unit tests..."
    log_info "Infrastructure directory: ${INFRASTRUCTURE_ROOT}"

    # Run all infrastructure tests
    test_infrastructure_structure || failed=1
    test_terraform_syntax || failed=1
    test_config_templates || failed=1
    test_cloud_init_templates || failed=1
    test_infrastructure_scripts || failed=1

    # Final result
    if [[ ${failed} -eq 0 ]]; then
        log_success "All infrastructure unit tests passed!"
        log_info "Test log: ${TEST_LOG_FILE}"
        return 0
    else
        log_error "Some infrastructure unit tests failed!"
        log_error "Check test log for details: ${TEST_LOG_FILE}"
        return 1
    fi
}

# Help function
show_help() {
    cat <<EOF
Unit Tests - Infrastructure Provisioning Validation

Tests infrastructure configuration files, templates, and syntax without deploying infrastructure.
Note: YAML and shell script syntax validation is handled by ./scripts/lint.sh

Usage: $0 [COMMAND]

Commands:
    full-test       Run all infrastructure tests (default)
    terraform       Test Terraform/OpenTofu syntax only
    templates       Test configuration templates only
    structure       Test infrastructure directory structure only
    cloud-init      Test cloud-init templates only
    scripts         Test infrastructure scripts only
    help           Show this help message

Examples:
    $0                    # Run all infrastructure tests
    $0 terraform         # Test Terraform configuration only
    $0 templates         # Test configuration templates only

Infrastructure Root: ${INFRASTRUCTURE_ROOT}
Test log: ${TEST_LOG_FILE}
EOF
}

# Main execution
main() {
    local command="${1:-full-test}"

    case "${command}" in
    "full-test")
        run_infrastructure_tests
        ;;
    "terraform")
        init_test_log && test_terraform_syntax
        ;;
    "templates")
        init_test_log && test_config_templates
        ;;
    "structure")
        init_test_log && test_infrastructure_structure
        ;;
    "cloud-init")
        init_test_log && test_cloud_init_templates
        ;;
    "scripts")
        init_test_log && test_infrastructure_scripts
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
