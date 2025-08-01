#!/bin/bash
# Infrastructure provisioning script for Torrust Tracker Demo
# Provisions base infrastructure using pluggable provider system
# Twelve-Factor App compliant: Build stage only

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/infrastructure/terraform"
CONFIG_DIR="${PROJECT_ROOT}/infrastructure/config"

# Parse arguments with provider support
ENVIRONMENT="${1:-development}"
PROVIDER="${2:-libvirt}"  # New: Provider parameter
ACTION="${3:-apply}"      # Shifted due to provider parameter
SKIP_WAIT="${SKIP_WAIT:-false}"

# Source shared shell utilities
# shellcheck source=../../scripts/shell-utils.sh
source "${PROJECT_ROOT}/scripts/shell-utils.sh"

# Load provider interface
# shellcheck source=providers/provider-interface.sh
source "${SCRIPT_DIR}/providers/provider-interface.sh"

# Load environment configuration
load_environment() {
    local config_script="${SCRIPT_DIR}/configure-env.sh"

    if [[ -f "${config_script}" ]]; then
        log_info "Loading environment configuration: ${ENVIRONMENT}"

        # Source the environment variables
        if ! "${config_script}" "${ENVIRONMENT}"; then
            log_error "Failed to load environment configuration"
            exit 1
        fi

        # Load the generated environment file
        local env_file="${CONFIG_DIR}/environments/${ENVIRONMENT}.env"
        if [[ -f "${env_file}" ]]; then
            # shellcheck source=/dev/null
            source "${env_file}"
            log_info "Environment variables loaded from: ${env_file}"
        else
            log_error "Environment file not found: ${env_file}"
            exit 1
        fi
    else
        log_error "Configuration script not found: ${config_script}"
        exit 1
    fi
}

# Load provider configuration
load_provider_config() {
    local provider_config="${CONFIG_DIR}/providers/${PROVIDER}.env"

    if [[ -f "${provider_config}" ]]; then
        # shellcheck source=/dev/null
        source "${provider_config}"
        log_info "Provider config loaded: ${provider_config}"
    else
        log_info "No provider-specific config found (using defaults): ${provider_config}"
    fi
}

# Validate prerequisites using provider system
validate_prerequisites() {
    log_info "Validating prerequisites for infrastructure provisioning"
    log_info "Environment: ${ENVIRONMENT}, Provider: ${PROVIDER}"

    # Check if OpenTofu/Terraform is available
    if ! command -v tofu >/dev/null 2>&1; then
        log_error "OpenTofu (tofu) not found. Please install OpenTofu first."
        exit 1
    fi

    # Load and validate provider
    load_provider "${PROVIDER}"

    # Provider-specific validation
    provider_validate_prerequisites

    log_success "Prerequisites validation passed"
}

# Initialize Terraform if needed
init_terraform() {
    cd "${TERRAFORM_DIR}"

    if [[ ! -d ".terraform" ]]; then
        log_info "Initializing Terraform"
        tofu init
    else
        log_info "Terraform already initialized"
    fi
}

# Provision infrastructure
provision_infrastructure() {
    log_info "Provisioning infrastructure"
    log_info "Environment: ${ENVIRONMENT}, Provider: ${PROVIDER}, Action: ${ACTION}"

    cd "${TERRAFORM_DIR}"

    # Generate provider-specific Terraform variables
    local vars_file="${TERRAFORM_DIR}/${PROVIDER}.auto.tfvars"
    provider_generate_terraform_vars "${vars_file}"

    case "${ACTION}" in
    "init")
        log_info "Initializing Terraform"
        tofu init
        ;;
    "plan")
        log_info "Planning infrastructure changes"
        tofu plan
        ;;
    "apply")
        log_info "Preparing to apply infrastructure changes"

        # Provider-specific sudo requirements (mainly for libvirt)
        if [[ "${PROVIDER}" == "libvirt" ]]; then
            log_warning "LibVirt infrastructure provisioning requires administrator privileges for volume operations"
            if ! ensure_sudo_cached "provision libvirt infrastructure"; then
                log_error "Cannot proceed without administrator privileges"
                log_error "Infrastructure provisioning requires sudo access for libvirt volume management"
                exit 1
            fi
        fi

        log_info "Applying infrastructure changes"
        init_terraform

        # Clean SSH known_hosts to prevent host key verification issues
        log_info "Cleaning SSH known_hosts to prevent host key verification warnings"
        if command -v "${SCRIPT_DIR}/ssh-utils.sh" >/dev/null 2>&1; then
            "${SCRIPT_DIR}/ssh-utils.sh" clean-all || log_warning "SSH cleanup failed (non-critical)"
        fi

        tofu apply -auto-approve

        # Wait for infrastructure to be fully ready (unless skipped)
        if [[ "${SKIP_WAIT}" != "true" ]]; then
            log_info "⏳ Waiting for infrastructure to be fully ready..."
            log_info "   (Use SKIP_WAIT=true to skip this waiting)"
            
            # Wait for VM IP assignment
            if ! wait_for_vm_ip "${ENVIRONMENT}" "${PROJECT_ROOT}"; then
                log_error "Failed to wait for VM IP assignment"
                exit 1
            fi
            
            # Wait for cloud-init completion  
            if ! wait_for_cloud_init_completion "${ENVIRONMENT}"; then
                log_error "Failed to wait for cloud-init completion"
                exit 1
            fi
            
            log_success "🎉 Infrastructure is fully ready for application deployment!"
        else
            log_warning "⚠️  Skipping wait for infrastructure readiness (SKIP_WAIT=true)"
            log_info "   Note: You may need to wait before running app-deploy"
        fi

        # Get VM IP and display connection info
        local vm_ip
        vm_ip=$(cd "${TERRAFORM_DIR}" && tofu output -raw vm_ip 2>/dev/null || echo "")

        if [[ -n "${vm_ip}" ]]; then
            log_success "Infrastructure provisioned successfully"
            log_info "Provider: ${PROVIDER}"
            log_info "VM IP: ${vm_ip}"

            # Clean specific IP from known_hosts
            if command -v "${SCRIPT_DIR}/ssh-utils.sh" >/dev/null 2>&1; then
                "${SCRIPT_DIR}/ssh-utils.sh" clean "${vm_ip}" || log_warning "SSH cleanup for ${vm_ip} failed (non-critical)"
            fi

            log_info "SSH Access: ssh torrust@${vm_ip}"
            log_info "Next step: make app-deploy ENVIRONMENT=${ENVIRONMENT}"
        else
            log_warning "Infrastructure provisioned but VM IP not available yet"
            log_info "Try: make infra-status ENVIRONMENT=${ENVIRONMENT} PROVIDER=${PROVIDER} to check VM IP"
        fi
        ;;
    "destroy")
        log_info "Destroying infrastructure"
        tofu destroy -auto-approve
        log_success "Infrastructure destroyed"
        ;;
    *)
        log_error "Unknown action: ${ACTION}"
        show_help
        exit 1
        ;;
    esac
}

# Main execution
main() {
    log_info "Starting infrastructure provisioning (Twelve-Factor Build Stage)"
    log_info "Environment: ${ENVIRONMENT}, Provider: ${PROVIDER}, Action: ${ACTION}"

    validate_prerequisites
    load_environment
    load_provider_config
    
    # Load and validate provider
    load_provider "${PROVIDER}"
    provider_validate_prerequisites
    
    provision_infrastructure

    log_success "Infrastructure provisioning completed"
}

# Show help
show_help() {
    cat <<EOF
Infrastructure Provisioning Script (Twelve-Factor Build Stage)

Usage: $0 [ENVIRONMENT] [PROVIDER] [ACTION]

Arguments:
    ENVIRONMENT    Environment name (development, staging, production)
    PROVIDER       Infrastructure provider (libvirt, hetzner, aws, etc.)
    ACTION         Action to perform (init, plan, apply, destroy)

Examples:
    $0 development libvirt init     # Initialize Terraform for development on libvirt
    $0 development libvirt plan     # Plan infrastructure changes
    $0 development libvirt apply    # Apply infrastructure changes
    $0 production hetzner apply     # Deploy production on Hetzner
    $0 staging digitalocean destroy # Destroy staging on DigitalOcean

Available providers:
EOF
    
    # List available providers
    local providers
    providers=$(list_available_providers 2>/dev/null || echo "None configured yet")
    echo "    ${providers}"
    echo ""
    
    cat <<EOF
Provider information:
    Use: make provider-info PROVIDER=<name> for details

Twelve-Factor Compliance:
    This script implements the BUILD stage - infrastructure provisioning only.
    No application code or configuration is deployed here.
    
    After successful completion, run:
    make app-deploy ENVIRONMENT=${ENVIRONMENT}
EOF
}

# Handle arguments
case "${1:-}" in
"help" | "-h" | "--help")
    show_help
    exit 0
    ;;
"")
    log_error "Environment argument required"
    show_help
    exit 1
    ;;
*)
    main "$@"
    ;;
esac
