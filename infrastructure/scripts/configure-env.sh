#!/bin/bash
# Configuration processing script for Torrust Tracker Demo
# Processes environment variables and generates configuration files

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_DIR="${PROJECT_ROOT}/infrastructure/config"

# Default values
ENVIRONMENT="${1:-local}"
VERBOSE="${VERBOSE:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "$1"
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
    log "${RED}[ERROR]${NC} $1" >&2
}

# Setup production environment from template
setup_production_environment() {
    local env_file="${CONFIG_DIR}/environments/production.env"
    local template_file="${CONFIG_DIR}/environments/production.env.tpl"

    if [[ ! -f "${env_file}" ]]; then
        if [[ ! -f "${template_file}" ]]; then
            log_error "Production template not found: ${template_file}"
            exit 1
        fi

        log_info "Creating production.env from template..."
        cp "${template_file}" "${env_file}"
        log_warning "Production environment file created from template: ${env_file}"
        log_warning "IMPORTANT: You must edit this file and replace placeholder values with secure secrets!"
        log_warning "File location: ${env_file}"
        log_error "Aborting: Please configure production secrets first, then run this script again."
        exit 1
    fi

    # Validate that placeholder values have been replaced
    if grep -q "REPLACE_WITH_SECURE" "${env_file}"; then
        log_error "Production environment file contains placeholder values!"
        log_error "Please edit ${env_file} and replace all 'REPLACE_WITH_SECURE_*' values with actual secrets."
        log_error "Found placeholder values:"
        grep "REPLACE_WITH_SECURE" "${env_file}" | while read -r line; do
            log_error "  ${line}"
        done
        exit 1
    fi

    log_success "Production environment file validated"
}

# Load environment configuration
load_environment() {
    local env_file="${CONFIG_DIR}/environments/${ENVIRONMENT}.env"

    # Special handling for production environment
    if [[ "${ENVIRONMENT}" == "production" ]]; then
        setup_production_environment
    fi

    if [[ ! -f "${env_file}" ]]; then
        log_error "Environment file not found: ${env_file}"
        exit 1
    fi

    log_info "Loading environment: ${ENVIRONMENT}"
    # Export variables so they're available to envsubst
    set -a # automatically export all variables
    # shellcheck source=/dev/null
    source "${env_file}"
    set +a # stop automatically exporting
}

# Validate required environment variables
validate_environment() {
    local required_vars=(
        "ENVIRONMENT"
        "MYSQL_ROOT_PASSWORD"
        "MYSQL_PASSWORD"
        "TRACKER_ADMIN_TOKEN"
        "GF_SECURITY_ADMIN_PASSWORD"
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required environment variable not set: ${var}"
            exit 1
        fi
    done

    log_success "Environment validation passed"
}

# Process configuration templates
process_templates() {
    local templates_dir="${CONFIG_DIR}/templates"
    local output_dir="${PROJECT_ROOT}/application/storage/tracker/etc"

    # Ensure output directory exists
    mkdir -p "${output_dir}"

    # Process tracker configuration template
    if [[ -f "${templates_dir}/tracker.toml.tpl" ]]; then
        log_info "Processing tracker configuration template"
        envsubst <"${templates_dir}/tracker.toml.tpl" >"${output_dir}/tracker.toml"
        log_info "Generated: ${output_dir}/tracker.toml"
    fi

    # Process prometheus configuration template
    if [[ -f "${templates_dir}/prometheus.yml.tpl" ]]; then
        log_info "Processing prometheus configuration template"
        local prometheus_output_dir="${PROJECT_ROOT}/application/storage/prometheus/etc"
        mkdir -p "${prometheus_output_dir}"
        envsubst <"${templates_dir}/prometheus.yml.tpl" >"${prometheus_output_dir}/prometheus.yml"
        log_info "Generated: ${prometheus_output_dir}/prometheus.yml"
    fi

    # Process nginx configuration template
    if [[ -f "${templates_dir}/nginx.conf.tpl" ]]; then
        log_info "Processing nginx configuration template"
        local nginx_output_dir="${PROJECT_ROOT}/application/storage/proxy/etc/nginx-conf"
        mkdir -p "${nginx_output_dir}"
        envsubst <"${templates_dir}/nginx.conf.tpl" >"${nginx_output_dir}/nginx.conf"
        log_info "Generated: ${nginx_output_dir}/nginx.conf"
    fi

    log_success "Configuration templates processed"
}

# Generate .env file for Docker Compose
generate_docker_env() {
    local templates_dir="${CONFIG_DIR}/templates"
    local env_output="${PROJECT_ROOT}/application/.env"

    log_info "Generating Docker Compose environment file"

    # Set generation date for template
    GENERATION_DATE="$(date)"
    export GENERATION_DATE

    # Ensure ENVIRONMENT is exported for template substitution
    export ENVIRONMENT

    # Process Docker Compose environment template
    if [[ -f "${templates_dir}/docker-compose.env.tpl" ]]; then
        envsubst <"${templates_dir}/docker-compose.env.tpl" >"${env_output}"
        log_info "Generated: ${env_output}"
    else
        log_error "Docker Compose environment template not found: ${templates_dir}/docker-compose.env.tpl"
        exit 1
    fi
}

# Main execution
main() {
    log_info "Starting configuration processing for environment: ${ENVIRONMENT}"

    load_environment
    validate_environment
    process_templates
    generate_docker_env

    log_success "Configuration processing completed successfully"
}

# Show help
show_help() {
    cat <<EOF
Configuration Processing Script

Usage: $0 [ENVIRONMENT]

Arguments:
    ENVIRONMENT    Environment name (local, production)

Examples:
    $0 local       # Process local environment configuration
    $0 production  # Process production environment configuration

Environment Variables:
    VERBOSE        Enable verbose output (true/false)
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
