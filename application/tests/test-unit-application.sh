#!/bin/bash
# Unit tests for application deployment validation
# Focus: Validate application configuration, Docker Compose, and deployment-related files
# Scope: No actual deployment, only static validation of application components

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLICATION_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST_LOG_FILE="/tmp/torrust-unit-application-test.log"

# Source shared shell utilities
# shellcheck source=../../scripts/shell-utils.sh
source "${PROJECT_ROOT}/scripts/shell-utils.sh"

# Set log file for tee output
export SHELL_UTILS_LOG_FILE="${TEST_LOG_FILE}"

# Initialize test log
init_test_log() {
    init_log_file "${TEST_LOG_FILE}" "Unit Tests - Application Deployment Validation"
    log_info "Application Root: ${APPLICATION_ROOT}"
}

# Test Docker Compose syntax validation
test_docker_compose_syntax() {
    log_info "Testing Docker Compose syntax validation..."

    local compose_file="${APPLICATION_ROOT}/compose.yaml"
    local failed=0

    if [[ ! -f "${compose_file}" ]]; then
        log_error "Docker Compose file not found: ${compose_file}"
        return 1
    fi

    cd "${APPLICATION_ROOT}"

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

# Test application configuration files
test_application_config() {
    log_info "Testing application configuration files..."

    local failed=0
    local config_files=(
        "compose.yaml"
    )

    # Optional files (for development/local testing)
    local optional_files=(
        ".env"
        ".env.production"
        ".env.local"
    )

    cd "${APPLICATION_ROOT}"

    # Check required configuration files
    for config_file in "${config_files[@]}"; do
        if [[ ! -f "${config_file}" ]]; then
            log_error "Required configuration file missing: ${config_file}"
            failed=1
        else
            log_info "Found configuration file: ${config_file}"
        fi
    done

    # Check optional configuration files (info only, no failure)
    local env_file_found=false
    for config_file in "${optional_files[@]}"; do
        if [[ -f "${config_file}" ]]; then
            log_info "Found optional configuration file: ${config_file}"
            env_file_found=true
        fi
    done

    if [[ "$env_file_found" = false ]]; then
        log_info "No environment files found (normal for CI, generated during deployment)"
    fi

    # Test that configuration templates exist
    local template_dir="${APPLICATION_ROOT}/config/templates"
    if [[ -d "${template_dir}" ]]; then
        log_info "Configuration templates directory found: ${template_dir}"
    else
        log_warning "Configuration templates directory not found: ${template_dir}"
    fi

    if [[ ${failed} -eq 0 ]]; then
        log_success "Application configuration files are present"
    fi

    return ${failed}
}

# Test application directory structure
test_application_structure() {
    log_info "Testing application directory structure..."

    local failed=0
    local required_paths=(
        "compose.yaml"
        "config"
        "share"
        "docs"
    )

    cd "${APPLICATION_ROOT}"

    for path in "${required_paths[@]}"; do
        if [[ ! -e "${path}" ]]; then
            log_error "Required application path missing: ${path}"
            failed=1
        fi
    done

    if [[ ${failed} -eq 0 ]]; then
        log_success "Application directory structure is valid"
    fi

    return ${failed}
}

# Test deployment scripts
test_deployment_scripts() {
    log_info "Testing deployment scripts..."

    local failed=0
    local scripts_dir="${APPLICATION_ROOT}/share/bin"

    if [[ ! -d "${scripts_dir}" ]]; then
        log_warning "Scripts directory not found: ${scripts_dir}"
        return 0
    fi

    # Check for key utility scripts
    local key_scripts=(
        "ssl_renew.sh"
        "tracker-db-backup.sh"
        "tracker-filtered-logs.sh"
    )

    for script in "${key_scripts[@]}"; do
        local script_path="${scripts_dir}/${script}"
        if [[ -f "${script_path}" ]]; then
            if [[ -x "${script_path}" ]]; then
                log_info "Found executable utility script: ${script}"
            else
                log_warning "Utility script exists but is not executable: ${script}"
            fi
        else
            log_warning "Utility script not found: ${script}"
        fi
    done

    log_success "Utility scripts validation completed"
    return ${failed}
}

# Test Grafana configuration
test_grafana_config() {
    log_info "Testing Grafana configuration..."

    local failed=0
    local grafana_dir="${APPLICATION_ROOT}/share/grafana"

    if [[ ! -d "${grafana_dir}" ]]; then
        log_warning "Grafana directory not found: ${grafana_dir}"
        return 0
    fi

    # Check for dashboard files
    if find "${grafana_dir}" -name "*.json" -type f | grep -q .; then
        log_success "Grafana dashboard files found"
    else
        log_warning "No Grafana dashboard files found in ${grafana_dir}"
    fi

    return ${failed}
}

# Run all application unit tests
run_application_tests() {
    local failed=0

    init_test_log

    log_info "Running application deployment unit tests..."
    log_info "Application directory: ${APPLICATION_ROOT}"

    # Run all application tests
    test_application_structure || failed=1
    test_application_config || failed=1
    test_docker_compose_syntax || failed=1
    test_deployment_scripts || failed=1
    test_grafana_config || failed=1

    # Final result
    if [[ ${failed} -eq 0 ]]; then
        log_success "All application unit tests passed!"
        log_info "Test log: ${TEST_LOG_FILE}"
        return 0
    else
        log_error "Some application unit tests failed!"
        log_error "Check test log for details: ${TEST_LOG_FILE}"
        return 1
    fi
}

# Help function
show_help() {
    cat <<EOF
Unit Tests - Application Deployment Validation

Tests application configuration, Docker Compose, and deployment-related files
without performing actual deployment.

Usage: $0 [COMMAND]

Commands:
    full-test       Run all application tests (default)
    docker          Test Docker Compose syntax only
    config          Test application configuration only
    structure       Test application directory structure only
    scripts         Test deployment scripts only
    grafana         Test Grafana configuration only
    help           Show this help message

Examples:
    $0                    # Run all application tests
    $0 docker            # Test Docker Compose only
    $0 config            # Test application configuration only

Application Root: ${APPLICATION_ROOT}
Test log: ${TEST_LOG_FILE}
EOF
}

# Main execution
main() {
    local command="${1:-full-test}"

    case "${command}" in
    "full-test")
        run_application_tests
        ;;
    "docker")
        init_test_log && test_docker_compose_syntax
        ;;
    "config")
        init_test_log && test_application_config
        ;;
    "structure")
        init_test_log && test_application_structure
        ;;
    "scripts")
        init_test_log && test_deployment_scripts
        ;;
    "grafana")
        init_test_log && test_grafana_config
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
