#!/bin/bash
# Unit tests for configuration and syntax validation
# Focus: Validate configuration files, templates, and syntax
# Scope: No infrastructure deployment, only static validation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST_LOG_FILE="/tmp/torrust-unit-config-test.log"

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
        echo "Unit Tests - Configuration and Syntax Validation"
        echo "Started: $(date)"
        echo "================================================================="
    } >"${TEST_LOG_FILE}"
}

# Test Terraform/OpenTofu syntax validation
test_terraform_syntax() {
    log_info "Testing Terraform/OpenTofu syntax validation..."

    local terraform_dir="${PROJECT_ROOT}/infrastructure/terraform"
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

# Test Docker Compose syntax validation
test_docker_compose_syntax() {
    log_info "Testing Docker Compose syntax validation..."

    local compose_file="${PROJECT_ROOT}/application/compose.yaml"
    local failed=0

    if [[ ! -f "${compose_file}" ]]; then
        log_warning "Docker Compose file not found: ${compose_file}"
        return 0
    fi

    cd "$(dirname "${compose_file}")"

    # Test Docker Compose syntax
    if command -v docker >/dev/null 2>&1; then
        if docker compose config >/dev/null 2>&1; then
            log_success "Docker Compose configuration is valid"
        else
            log_error "Docker Compose validation failed"
            failed=1
        fi
    else
        log_warning "Docker not found - skipping Docker Compose validation"
    fi

    return ${failed}
}

# Test configuration template processing
test_config_templates() {
    log_info "Testing configuration template processing..."

    local failed=0
    local template_dir="${PROJECT_ROOT}/infrastructure/config/templates"

    if [[ ! -d "${template_dir}" ]]; then
        log_warning "Templates directory not found: ${template_dir}"
        return 0
    fi

    # Test that configuration generation script exists and is executable
    local config_script="${PROJECT_ROOT}/infrastructure/scripts/configure-env.sh"

    if [[ ! -f "${config_script}" ]]; then
        log_error "Configuration script not found: ${config_script}"
        return 1
    fi

    if [[ ! -x "${config_script}" ]]; then
        log_error "Configuration script is not executable: ${config_script}"
        return 1
    fi

    # Test configuration generation (dry-run mode if available)
    cd "${PROJECT_ROOT}"

    # Note: We can't actually run the configuration generation here because
    # it might modify files. This is a limitation of unit testing.
    # In a real scenario, you'd want to test this in a isolated environment.

    log_success "Configuration template system is available"
    return ${failed}
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
        "application/compose.yaml"
        "docs/guides"
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

# Run all unit tests
run_unit_tests() {
    local failed=0

    init_test_log

    log_info "Running configuration and syntax unit tests..."
    log_info "Working directory: ${PROJECT_ROOT}"

    # Run all unit tests (excluding YAML and shell validation which is done by ./scripts/lint.sh)
    test_required_tools || failed=1
    test_project_structure || failed=1
    test_makefile_syntax || failed=1
    test_terraform_syntax || failed=1
    test_docker_compose_syntax || failed=1
    test_config_templates || failed=1

    # Final result
    if [[ ${failed} -eq 0 ]]; then
        log_success "All unit tests passed!"
        log_info "Test log: ${TEST_LOG_FILE}"
        return 0
    else
        log_error "Some unit tests failed!"
        log_error "Check test log for details: ${TEST_LOG_FILE}"
        return 1
    fi
}

# Help function
show_help() {
    cat <<EOF
Unit Tests - Configuration and Syntax Validation

Tests configuration files, templates, and syntax without deploying infrastructure.
Note: YAML and shell script syntax validation is handled by ./scripts/lint.sh

Usage: $0 [COMMAND]

Commands:
    full-test       Run all unit tests (default)
    terraform       Test Terraform/OpenTofu syntax only
    docker          Test Docker Compose syntax only
    makefile        Test Makefile syntax only
    tools           Test required tools availability only
    structure       Test project structure only
    templates       Test configuration templates only
    help           Show this help message

Examples:
    $0                    # Run all unit tests
    $0 terraform         # Test Terraform configuration only
    $0 tools             # Test required tools only

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
    "terraform")
        init_test_log && test_terraform_syntax
        ;;
    "docker")
        init_test_log && test_docker_compose_syntax
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
    "templates")
        init_test_log && test_config_templates
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
