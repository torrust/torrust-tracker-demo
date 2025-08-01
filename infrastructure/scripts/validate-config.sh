#!/bin/bash
# Configuration validation script for Torrust Tracker Demo
# Validates generated configuration files for syntax and completeness

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Default values
ENVIRONMENT="${1:-development}"
VERBOSE="${VERBOSE:-false}"

# Source shared shell utilities
# shellcheck source=../../scripts/shell-utils.sh
source "${PROJECT_ROOT}/scripts/shell-utils.sh"

# Check if required tools are available
check_dependencies() {
    local missing_tools=()

    # Check for TOML validation tool (optional but recommended)
    if ! command -v toml-test >/dev/null 2>&1 && ! command -v taplo >/dev/null 2>&1; then
        log_warning "TOML validation tools not found (toml-test or taplo). Syntax validation will be limited."
    fi

    # Check for YAML validation tool
    if ! command -v yamllint >/dev/null 2>&1; then
        missing_tools+=("yamllint")
    fi

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_warning "Missing optional validation tools: ${missing_tools[*]}"
        log_info "Install with: sudo apt-get install yamllint"
    fi
}

# Validate TOML configuration files
validate_toml_files() {
    local tracker_config="${PROJECT_ROOT}/application/storage/tracker/etc/tracker.toml"

    if [[ ! -f "${tracker_config}" ]]; then
        log_error "Tracker configuration file not found: ${tracker_config}"
        log_error "Run './infrastructure/scripts/configure-env.sh ${ENVIRONMENT}' first"
        return 1
    fi

    log_info "Validating TOML configuration files..."

    # Basic TOML syntax validation using simple parsing
    if command -v taplo >/dev/null 2>&1; then
        if taplo check "${tracker_config}"; then
            log_success "TOML syntax validation passed (using taplo)"
        else
            log_error "TOML syntax validation failed"
            return 1
        fi
    else
        # Basic validation - check for common TOML syntax issues
        if grep -q "^\[.*\]$" "${tracker_config}" && ! grep -q "= $" "${tracker_config}"; then
            log_success "Basic TOML structure validation passed"
        else
            log_error "Basic TOML structure validation failed"
            return 1
        fi
    fi

    # Validate required sections exist
    local required_sections=(
        "logging"
        "core"
        "core.database"
        "http_api"
        "udp_trackers"
        "http_trackers"
    )

    for section in "${required_sections[@]}"; do
        if grep -q "^\[${section}\]$\|^\[\[${section}\]\]$" "${tracker_config}"; then
            [[ "${VERBOSE}" == "true" ]] && log_info "Section found: [${section}]"
        else
            log_error "Required section missing: [${section}]"
            return 1
        fi
    done

    log_success "Tracker configuration validation passed"
}

# Validate YAML configuration files
validate_yaml_files() {
    local prometheus_config="${PROJECT_ROOT}/application/storage/prometheus/etc/prometheus.yml"

    if [[ ! -f "${prometheus_config}" ]]; then
        log_error "Prometheus configuration file not found: ${prometheus_config}"
        log_error "Run './infrastructure/scripts/configure-env.sh ${ENVIRONMENT}' first"
        return 1
    fi

    log_info "Validating YAML configuration files..."

    # Check if file is in ignored directory
    if [[ "${prometheus_config}" == *"application/storage/"* ]]; then
        log_info "Skipping yamllint for file in ignored directory: application/storage/"
        # Basic YAML validation using Python instead
        if python3 -c "import yaml; yaml.safe_load(open('${prometheus_config}'))" 2>/dev/null; then
            log_success "Basic YAML syntax validation passed (file in ignored directory)"
        else
            log_error "Basic YAML syntax validation failed"
            return 1
        fi
    else
        # YAML syntax validation for files not in ignored directories
        if command -v yamllint >/dev/null 2>&1; then
            # Use project yamllint config if it exists
            if [[ -f "${PROJECT_ROOT}/.yamllint-ci.yml" ]]; then
                if yamllint -c "${PROJECT_ROOT}/.yamllint-ci.yml" "${prometheus_config}"; then
                    log_success "YAML syntax validation passed (using yamllint with project config)"
                else
                    log_error "YAML syntax validation failed"
                    return 1
                fi
            else
                if yamllint "${prometheus_config}"; then
                    log_success "YAML syntax validation passed (using yamllint)"
                else
                    log_error "YAML syntax validation failed"
                    return 1
                fi
            fi
        else
            # Basic YAML validation using Python
            if python3 -c "import yaml; yaml.safe_load(open('${prometheus_config}'))" 2>/dev/null; then
                log_success "Basic YAML syntax validation passed"
            else
                log_error "Basic YAML syntax validation failed"
                return 1
            fi
        fi
    fi

    # Validate required Prometheus sections
    local required_keys=(
        "global"
        "scrape_configs"
    )

    for key in "${required_keys[@]}"; do
        if grep -q "^${key}:" "${prometheus_config}"; then
            [[ "${VERBOSE}" == "true" ]] && log_info "Key found: ${key}"
        else
            log_error "Required key missing: ${key}"
            return 1
        fi
    done

    log_success "Prometheus configuration validation passed"
}

# Validate environment-specific configuration
validate_environment_config() {
    local tracker_config="${PROJECT_ROOT}/application/storage/tracker/etc/tracker.toml"

    log_info "Validating environment-specific configuration..."

    case "${ENVIRONMENT}" in
    "local")
        # Local environment allows public mode for integration testing
        if grep -q 'threshold = "info"' "${tracker_config}"; then
            [[ "${VERBOSE}" == "true" ]] && log_info "${ENVIRONMENT}: Info logging enabled"
        else
            log_error "${ENVIRONMENT}: Info logging not enabled"
            return 1
        fi

        if grep -q 'on_reverse_proxy = true' "${tracker_config}"; then
            [[ "${VERBOSE}" == "true" ]] && log_info "${ENVIRONMENT}: Reverse proxy enabled"
        else
            log_error "${ENVIRONMENT}: Reverse proxy should be enabled"
            return 1
        fi

        if grep -q 'private = false' "${tracker_config}"; then
            [[ "${VERBOSE}" == "true" ]] && log_info "${ENVIRONMENT}: Public tracker mode enabled (for integration testing)"
        else
            log_error "${ENVIRONMENT}: Public tracker mode should be enabled for integration testing"
            return 1
        fi

        if grep -q 'driver = "mysql"' "${tracker_config}"; then
            [[ "${VERBOSE}" == "true" ]] && log_info "${ENVIRONMENT}: MySQL database configured"
        else
            log_error "${ENVIRONMENT}: MySQL database not configured"
            return 1
        fi

        if grep -q 'external_ip = "0.0.0.0"' "${tracker_config}"; then
            [[ "${VERBOSE}" == "true" ]] && log_info "${ENVIRONMENT}: External IP set to 0.0.0.0"
        else
            log_warning "${ENVIRONMENT}: External IP not set to 0.0.0.0 (this may be intentional)"
        fi
        ;;

    "production")
        # Production environment requires private mode for security
        if grep -q 'threshold = "info"' "${tracker_config}"; then
            [[ "${VERBOSE}" == "true" ]] && log_info "${ENVIRONMENT}: Info logging enabled"
        else
            log_error "${ENVIRONMENT}: Info logging not enabled"
            return 1
        fi

        if grep -q 'on_reverse_proxy = true' "${tracker_config}"; then
            [[ "${VERBOSE}" == "true" ]] && log_info "${ENVIRONMENT}: Reverse proxy enabled"
        else
            log_error "${ENVIRONMENT}: Reverse proxy should be enabled"
            return 1
        fi

        if grep -q 'private = true' "${tracker_config}"; then
            [[ "${VERBOSE}" == "true" ]] && log_info "${ENVIRONMENT}: Private tracker mode enabled"
        else
            log_error "${ENVIRONMENT}: Private tracker mode should be enabled"
            return 1
        fi

        if grep -q 'driver = "mysql"' "${tracker_config}"; then
            [[ "${VERBOSE}" == "true" ]] && log_info "${ENVIRONMENT}: MySQL database configured"
        else
            log_error "${ENVIRONMENT}: MySQL database not configured"
            return 1
        fi

        if grep -q 'external_ip = "0.0.0.0"' "${tracker_config}"; then
            [[ "${VERBOSE}" == "true" ]] && log_info "${ENVIRONMENT}: External IP set to 0.0.0.0"
        else
            log_warning "${ENVIRONMENT}: External IP not set to 0.0.0.0 (this may be intentional)"
        fi
        ;;

    *)
        log_error "Unknown environment: ${ENVIRONMENT}"
        return 1
        ;;
    esac

    log_success "Environment-specific configuration validation passed"
}

# Check for template variable substitution issues
validate_template_substitution() {
    local tracker_config="${PROJECT_ROOT}/application/storage/tracker/etc/tracker.toml"
    local prometheus_config="${PROJECT_ROOT}/application/storage/prometheus/etc/prometheus.yml"

    log_info "Checking for unsubstituted template variables..."

    local files_to_check=("${tracker_config}" "${prometheus_config}")
    local found_issues=false

    for file in "${files_to_check[@]}"; do
        if [[ -f "${file}" ]]; then
            # Check for unsubstituted variables (${VAR} patterns)
            if grep -n '\$[{][^}]*[}]' "${file}"; then
                log_error "Unsubstituted template variables found in: ${file}"
                found_issues=true
            fi
        fi
    done

    if [[ "${found_issues}" == "true" ]]; then
        log_error "Template substitution validation failed"
        return 1
    fi

    log_success "Template substitution validation passed"
}

# Main validation function
main() {
    log_info "Starting configuration validation for environment: ${ENVIRONMENT}"

    check_dependencies
    validate_toml_files
    validate_yaml_files
    validate_environment_config
    validate_template_substitution

    log_success "All configuration validation checks passed!"
}

# Show help
show_help() {
    cat <<EOF
Configuration Validation Script

Usage: $0 [ENVIRONMENT]

Arguments:
    ENVIRONMENT    Environment name (development, production)

Examples:
    $0 local       # Validate local environment configuration
    $0 production  # Validate production environment configuration

Environment Variables:
    VERBOSE        Enable verbose output (true/false)

Prerequisites:
    - Configuration files must be generated first using configure-env.sh
    - Optional tools for enhanced validation: yamllint, taplo

Validation Checks:
    - TOML and YAML syntax validation
    - Required configuration sections presence
    - Environment-specific settings validation
    - Template variable substitution verification
EOF
}

# Handle arguments
case "${1:-}" in
"help" | "-h" | "--help")
    show_help
    exit 0
    ;;
*)
    main "$@"
    ;;
esac
