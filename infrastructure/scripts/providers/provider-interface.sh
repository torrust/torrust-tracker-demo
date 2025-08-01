#!/bin/bash
# Provider interface for infrastructure provisioning
# Defines standard functions that all providers must implement

set -euo pipefail

# Set PROJECT_ROOT if not set
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
    export PROJECT_ROOT
fi

# Load shell utilities
# shellcheck source=../../scripts/shell-utils.sh
source "${PROJECT_ROOT}/scripts/shell-utils.sh"

# Load a provider's implementation
load_provider() {
    local provider="$1"
    local provider_script="${PROJECT_ROOT}/infrastructure/terraform/providers/${provider}/provider.sh"

    if [[ ! -f "${provider_script}" ]]; then
        log_error "Provider not found: ${provider}"
        log_error "Provider script missing: ${provider_script}"
        log_info "Available providers:"
        list_available_providers
        exit 1
    fi

    log_info "Loading provider: ${provider}"

    # shellcheck source=/dev/null
    source "${provider_script}"

    # Validate required functions exist
    validate_provider_interface "${provider}"
}

# Validate that provider implements required interface
validate_provider_interface() {
    local provider="$1"
    local required_functions=(
        "provider_validate_prerequisites"
        "provider_generate_terraform_vars"
        "provider_get_info"
    )

    for func in "${required_functions[@]}"; do
        if ! declare -F "${func}" >/dev/null 2>&1; then
            log_error "Provider ${provider} missing required function: ${func}"
            exit 1
        fi
    done

    log_success "Provider ${provider} interface validated"
}

# Discover available providers
list_available_providers() {
    local providers_dir="${PROJECT_ROOT}/infrastructure/terraform/providers"

    if [[ ! -d "${providers_dir}" ]]; then
        log_warning "No providers directory found: ${providers_dir}"
        return
    fi

    local found_providers=()
    for provider_dir in "${providers_dir}"/*; do
        if [[ -d "${provider_dir}" ]]; then
            local provider_name
            provider_name=$(basename "${provider_dir}")
            local provider_script="${provider_dir}/provider.sh"

            if [[ -f "${provider_script}" ]]; then
                found_providers+=("${provider_name}")
            fi
        fi
    done

    if [[ ${#found_providers[@]} -eq 0 ]]; then
        echo "No providers found"
        return
    fi

    printf "%s\n" "${found_providers[@]}"
}

# Get provider information
get_provider_info() {
    local provider="$1"

    if [[ -z "${provider}" ]]; then
        log_error "Provider name required"
        echo "Usage: get_provider_info <provider>"
        return 1
    fi

    load_provider "${provider}"
    provider_get_info
}

# Provider interface helper commands
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    case "${1:-}" in
        "list")
            list_available_providers
            ;;
        "info")
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 info <provider>"
                exit 1
            fi
            get_provider_info "$2"
            ;;
        *)
            echo "Usage: $0 {list|info <provider>}"
            echo ""
            echo "Commands:"
            echo "  list           - List available infrastructure providers"
            echo "  info <provider> - Show information about a specific provider"
            echo ""
            echo "Available providers:"
            list_available_providers
            exit 1
            ;;
    esac
fi
