#!/bin/bash
# Infrastructure provisioning script for Torrust Tracker Demo
# Provisions base infrastructure without application deployment
# Twelve-Factor App compliant: Build stage only

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/infrastructure/terraform"

# Default values
ENVIRONMENT="${1:-local}"
ACTION="${2:-apply}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

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
    else
        log_error "Configuration script not found: ${config_script}"
        exit 1
    fi
}

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites for infrastructure provisioning"

    # Check if OpenTofu/Terraform is available
    if ! command -v tofu >/dev/null 2>&1; then
        log_error "OpenTofu (tofu) not found. Please install OpenTofu first."
        exit 1
    fi

    # Check if libvirt is available (for local environment)
    if [[ "${ENVIRONMENT}" == "local" ]]; then
        if ! command -v virsh >/dev/null 2>&1; then
            log_error "virsh not found. Please install libvirt-clients."
            exit 1
        fi

        # Check if user has libvirt access
        if ! virsh list >/dev/null 2>&1; then
            log_error "No libvirt access. Please add user to libvirt group and restart session."
            exit 1
        fi
    fi

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
    log_info "Provisioning infrastructure for environment: ${ENVIRONMENT}"

    cd "${TERRAFORM_DIR}"

    case "${ACTION}" in
    "init")
        log_info "Initializing Terraform"
        tofu init
        ;;
    "plan")
        log_info "Planning infrastructure changes"
        tofu plan -var-file="local.tfvars"
        ;;
    "apply")
        log_info "Applying infrastructure changes"
        init_terraform
        tofu apply -auto-approve -var-file="local.tfvars"

        # Get VM IP and display connection info
        local vm_ip
        vm_ip=$(tofu output -raw vm_ip 2>/dev/null || echo "")

        if [[ -n "${vm_ip}" ]]; then
            log_success "Infrastructure provisioned successfully"
            log_info "VM IP: ${vm_ip}"
            log_info "SSH Access: ssh torrust@${vm_ip}"
            log_info "Next step: make app-deploy ENVIRONMENT=${ENVIRONMENT}"
        else
            log_warning "Infrastructure provisioned but VM IP not available yet"
            log_info "Try: make status to check VM IP"
        fi
        ;;
    "destroy")
        log_info "Destroying infrastructure"
        tofu destroy -auto-approve -var-file="local.tfvars"
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
    log_info "Environment: ${ENVIRONMENT}, Action: ${ACTION}"

    validate_prerequisites
    load_environment
    provision_infrastructure

    log_success "Infrastructure provisioning completed"
}

# Show help
show_help() {
    cat <<EOF
Infrastructure Provisioning Script (Twelve-Factor Build Stage)

Usage: $0 [ENVIRONMENT] [ACTION]

Arguments:
    ENVIRONMENT    Environment name (local, production)
    ACTION         Action to perform (init, plan, apply, destroy)

Examples:
    $0 local init     # Initialize Terraform for local environment
    $0 local plan     # Plan infrastructure changes for local
    $0 local apply    # Apply infrastructure changes for local
    $0 local destroy  # Destroy local infrastructure

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
