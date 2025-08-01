#!/bin/bash
# Configuration processing script for Torrust Tracker Demo
# Processes environment variables and generates configuration files

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_DIR="${PROJECT_ROOT}/infrastructure/config"

# Source utilities
# shellcheck source=../../scripts/shell-utils.sh
source "${PROJECT_ROOT}/scripts/shell-utils.sh"

# Default values
ENVIRONMENT="${1:-development}"
VERBOSE="${VERBOSE:-false}"

# Source shared shell utilities
# shellcheck source=../../scripts/shell-utils.sh
source "${PROJECT_ROOT}/scripts/shell-utils.sh"

# Generate environment-specific configuration from base template
generate_environment_config() {
    local environment="$1"
    local env_file="${CONFIG_DIR}/environments/${environment}.env"
    local base_template="${CONFIG_DIR}/environments/base.env.tpl"

    if [[ ! -f "${base_template}" ]]; then
        log_error "Base template not found: ${base_template}"
        exit 1
    fi

    log_info "Generating ${environment}.env from base template..."
    
    # Generate environment-specific variables
    case "${environment}" in
        "development")
            generate_development_config "${base_template}" "${env_file}"
            ;;
        "production")
            generate_production_config "${base_template}" "${env_file}"
            ;;
        *)
            log_error "Unsupported environment: ${environment}"
            exit 1
            ;;
    esac

    log_success "${environment^} environment file generated: ${env_file}"
}

# Generate development configuration
generate_development_config() {
    local template_file="$1"
    local output_file="$2"
    local defaults_file="${CONFIG_DIR}/environments/development.defaults"

    if [[ ! -f "${defaults_file}" ]]; then
        log_error "Development defaults file not found: ${defaults_file}"
        exit 1
    fi

    log_info "Loading development environment defaults from: ${defaults_file}"
    
    # Export all variables from defaults file for envsubst
    set -a # automatically export all variables
    # shellcheck source=/dev/null
    source "${defaults_file}"
    set +a # stop automatically exporting

    # Generate the configuration file
    envsubst < "${template_file}" > "${output_file}"
}

# Generate production configuration with secure defaults
generate_production_config() {
    local template_file="$1"
    local output_file="$2"
    local defaults_file="${CONFIG_DIR}/environments/production.defaults"

    # Check if production.env already exists and has real secrets
    if [[ -f "${output_file}" ]] && ! grep -q "REPLACE_WITH_SECURE\|REPLACE_WITH_YOUR" "${output_file}"; then
        log_info "Production environment file exists and appears configured"
        log_info "Skipping regeneration to preserve existing secrets"
        return 0
    fi

    if [[ ! -f "${defaults_file}" ]]; then
        log_error "Production defaults file not found: ${defaults_file}"
        exit 1
    fi

    log_info "Loading production environment defaults from: ${defaults_file}"
    
    # Export all variables from defaults file for envsubst
    set -a # automatically export all variables
    # shellcheck source=/dev/null
    source "${defaults_file}"
    set +a # stop automatically exporting

    # Generate the configuration file
    envsubst < "${template_file}" > "${output_file}"

    log_warning "Production environment file created from template: ${output_file}"
    log_warning "IMPORTANT: You must edit this file and replace placeholder values with secure secrets!"
    log_warning "File location: ${output_file}"
}

# Setup development environment from base template
setup_development_environment() {
    local env_file="${CONFIG_DIR}/environments/development.env"

    # Always regenerate development.env from base template for consistency
    generate_environment_config "development"
    log_success "Development environment file created from base template: ${env_file}"
}

# Setup production environment from base template  
setup_production_environment() {
    local env_file="${CONFIG_DIR}/environments/production.env"

    # Generate production template or use existing if configured
    generate_environment_config "production"

    # If file was just generated with placeholders, abort for manual configuration
    if grep -q "REPLACE_WITH_SECURE\|REPLACE_WITH_YOUR" "${env_file}"; then
        log_error "Aborting: Please configure production secrets first, then run this script again."
        exit 1
    fi

    log_success "Production environment file validated"
}

# Load environment configuration
load_environment() {
    local env_file="${CONFIG_DIR}/environments/${ENVIRONMENT}.env"

    # Special handling for template-based environments
    if [[ "${ENVIRONMENT}" == "production" ]]; then
        setup_production_environment
    elif [[ "${ENVIRONMENT}" == "development" ]]; then
        setup_development_environment
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

    # Validate core required variables
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required environment variable not set: ${var}"
            exit 1
        fi
    done

    # Validate SSL configuration variables
    validate_ssl_configuration

    # Validate backup configuration variables
    validate_backup_configuration

    log_success "Environment validation passed"
}

# Validate SSL certificate configuration
validate_ssl_configuration() {
    # Check if DOMAIN_NAME is set and not a placeholder
    if [[ -z "${DOMAIN_NAME:-}" ]]; then
        log_error "SSL configuration: DOMAIN_NAME is not set"
        exit 1
    fi
    
    if [[ "${DOMAIN_NAME}" == "REPLACE_WITH_YOUR_DOMAIN" ]]; then
        log_error "SSL configuration: DOMAIN_NAME contains placeholder value 'REPLACE_WITH_YOUR_DOMAIN'"
        log_error "Please edit your environment file and set a real domain name"
        exit 1
    fi

    # Check if CERTBOT_EMAIL is set and not a placeholder
    if [[ -z "${CERTBOT_EMAIL:-}" ]]; then
        log_error "SSL configuration: CERTBOT_EMAIL is not set"
        exit 1
    fi
    
    if [[ "${CERTBOT_EMAIL}" == "REPLACE_WITH_YOUR_EMAIL" ]]; then
        log_error "SSL configuration: CERTBOT_EMAIL contains placeholder value 'REPLACE_WITH_YOUR_EMAIL'"
        log_error "Please edit your environment file and set a real email address"
        exit 1
    fi

    # Validate email format (basic validation)
    if [[ ! "${CERTBOT_EMAIL}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "SSL configuration: CERTBOT_EMAIL '${CERTBOT_EMAIL}' is not a valid email format"
        exit 1
    fi

    # Check if ENABLE_SSL is a valid boolean
    if [[ -z "${ENABLE_SSL:-}" ]]; then
        log_error "SSL configuration: ENABLE_SSL is not set"
        exit 1
    fi
    
    if [[ "${ENABLE_SSL}" != "true" && "${ENABLE_SSL}" != "false" ]]; then
        log_error "SSL configuration: ENABLE_SSL must be 'true' or 'false', got '${ENABLE_SSL}'"
        exit 1
    fi

    # Log SSL configuration validation result
    if [[ "${ENABLE_SSL}" == "true" ]]; then
        log_info "SSL configuration: Enabled for domain '${DOMAIN_NAME}' with email '${CERTBOT_EMAIL}'"
    else
        log_info "SSL configuration: Disabled (ENABLE_SSL=false)"
    fi
}

# Validate backup configuration
validate_backup_configuration() {
    # Check if ENABLE_DB_BACKUPS is a valid boolean
    if [[ -z "${ENABLE_DB_BACKUPS:-}" ]]; then
        log_error "Backup configuration: ENABLE_DB_BACKUPS is not set"
        exit 1
    fi
    
    if [[ "${ENABLE_DB_BACKUPS}" != "true" && "${ENABLE_DB_BACKUPS}" != "false" ]]; then
        log_error "Backup configuration: ENABLE_DB_BACKUPS must be 'true' or 'false', got '${ENABLE_DB_BACKUPS}'"
        exit 1
    fi

    # Validate BACKUP_RETENTION_DAYS is numeric and reasonable
    if [[ -z "${BACKUP_RETENTION_DAYS:-}" ]]; then
        log_error "Backup configuration: BACKUP_RETENTION_DAYS is not set"
        exit 1
    fi
    
    if ! [[ "${BACKUP_RETENTION_DAYS}" =~ ^[0-9]+$ ]]; then
        log_error "Backup configuration: BACKUP_RETENTION_DAYS must be a positive integer, got '${BACKUP_RETENTION_DAYS}'"
        exit 1
    fi
    
    if [[ "${BACKUP_RETENTION_DAYS}" -lt 1 ]]; then
        log_error "Backup configuration: BACKUP_RETENTION_DAYS must be at least 1 day, got '${BACKUP_RETENTION_DAYS}'"
        exit 1
    fi
    
    if [[ "${BACKUP_RETENTION_DAYS}" -gt 365 ]]; then
        log_warning "Backup configuration: BACKUP_RETENTION_DAYS is very high (${BACKUP_RETENTION_DAYS} days)"
        log_warning "This may consume significant disk space"
    fi

    # Log backup configuration validation result
    if [[ "${ENABLE_DB_BACKUPS}" == "true" ]]; then
        log_info "Backup configuration: Enabled with ${BACKUP_RETENTION_DAYS} days retention"
    else
        log_info "Backup configuration: Disabled (ENABLE_DB_BACKUPS=false)"
    fi
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
    local env_output="${PROJECT_ROOT}/application/storage/compose/.env"

    log_info "Generating Docker Compose environment file"

    # Ensure the storage/compose directory exists
    mkdir -p "$(dirname "${env_output}")"

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

Usage: $0 [ENVIRONMENT|COMMAND]

Arguments:
    ENVIRONMENT         Environment name (development, production)
    generate-secrets    Generate secure secrets for production

Commands:
    generate-secrets    Generate secure random secrets and show configuration guidance

Examples:
    $0 development      # Process development environment configuration
    $0 production       # Process production environment configuration (requires configured secrets)
    $0 generate-secrets # Generate secure secrets for production setup

Environment Variables:
    VERBOSE             Enable verbose output (true/false)
EOF
}

# Generate secure secrets for production
generate_production_secrets() {
    log_info "Generating secure random secrets for production environment..."
    echo ""
    echo "=== TORRUST TRACKER PRODUCTION SECRETS ==="
    echo ""
    echo "Copy these values into: infrastructure/config/environments/production.env"
    echo ""
    echo "# === GENERATED SECRETS ==="
    echo "MYSQL_ROOT_PASSWORD=$(gpg --armor --gen-random 1 40)"
    echo "MYSQL_PASSWORD=$(gpg --armor --gen-random 1 40)"
    echo "TRACKER_ADMIN_TOKEN=$(gpg --armor --gen-random 1 40)"
    echo "GF_SECURITY_ADMIN_PASSWORD=$(gpg --armor --gen-random 1 40)"
    echo ""
    echo "# === DOMAIN CONFIGURATION (REPLACE WITH YOUR VALUES) ==="
    echo "DOMAIN_NAME=your-domain.com"
    echo "CERTBOT_EMAIL=admin@your-domain.com"
    echo ""
    echo "⚠️  Security Notes:"
    echo "   - Store these secrets securely"
    echo "   - Never commit production.env to version control"
    echo "   - Replace domain placeholders with your actual domain"
    echo ""
    echo "✅ Next Steps:"
    echo "   1. Replace 'your-domain.com' with your actual domain"
    echo "   2. Replace 'admin@your-domain.com' with your real email"
    echo "   3. Run: make infra-config-production"
    echo ""
}

# Handle arguments
case "${1:-}" in
"help" | "-h" | "--help")
    show_help
    exit 0
    ;;
"generate-secrets")
    generate_production_secrets
    exit 0
    ;;
*)
    main "$@"
    ;;
esac
