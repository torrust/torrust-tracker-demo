#!/bin/bash
# Shared shell utilities for Torrust Tracker Demo
# Common logging functions, colors, and utilities used across all scripts
#
# Usage:
#   # Source this file in your script:
#   source "path/to/shell-utils.sh"
#
#   # Optional: Set log file for tee output (defaults to stdout only if not set)
#   export SHELL_UTILS_LOG_FILE="/tmp/my-script.log"
#
#   # Use logging functions:
#   log_info "This is an info message"
#   log_success "Operation completed successfully"
#   log_warning "This is a warning"
#   log_error "This is an error"
#   log_section "Major Section Title"
#
#   # Use HTTP testing:
#   result=$(test_http_endpoint "http://example.com" "expected content")
#   if [[ "$result" == "success" ]]; then echo "Endpoint working"; fi
#
#   # Use retry logic:
#   retry_with_timeout "Testing connection" 5 2 "ping -c1 example.com >/dev/null"
#
#   # Time operations:
#   time_operation "Deployment" "make deploy"

# Shared shell utilities - can be sourced multiple times safely
export SHELL_UTILS_LOADED=1

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export MAGENTA='\033[0;35m'
export WHITE='\033[1;37m'
export NC='\033[0m' # No Color

# Core logging function
# Uses tee to output to both stdout and log file if SHELL_UTILS_LOG_FILE is set
log() {
    local message="$1"
    if [[ -n "${SHELL_UTILS_LOG_FILE:-}" ]]; then
        echo -e "${message}" | tee -a "${SHELL_UTILS_LOG_FILE}"
    else
        echo -e "${message}"
    fi
}

# Logging functions with standardized prefixes and colors
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

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        log "${CYAN}[DEBUG]${NC} $1"
    fi
}

log_trace() {
    if [[ "${TRACE:-false}" == "true" ]]; then
        log "${MAGENTA}[TRACE]${NC} $1"
    fi
}

# Section header logging - displays a prominent section separator
log_section() {
    log ""
    log "${BLUE}===============================================${NC}"
    log "${BLUE}$1${NC}"
    log "${BLUE}===============================================${NC}"
}

# Additional utility functions

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Print colored status (legacy compatibility function)
print_status() {
    local status="$1"
    local message="$2"
    case "${status}" in
    "SUCCESS")
        log_success "${message}"
        ;;
    "ERROR")
        log_error "${message}"
        ;;
    "WARNING")
        log_warning "${message}"
        ;;
    "INFO")
        log_info "${message}"
        ;;
    "DEBUG")
        log_debug "${message}"
        ;;
    *)
        log "${message}"
        ;;
    esac
}

# Initialize log file with header
init_log_file() {
    local log_file="${1:-${SHELL_UTILS_LOG_FILE}}"
    local script_name="${2:-$(basename "${0}")}"

    if [[ -n "${log_file}" ]]; then
        export SHELL_UTILS_LOG_FILE="${log_file}"
        {
            echo "================================================================="
            echo "Log for: ${script_name}"
            echo "Started: $(date)"
            echo "Working Directory: $(pwd)"
            echo "================================================================="
        } >"${SHELL_UTILS_LOG_FILE}"
    fi
}

# Log file completion message
finalize_log_file() {
    local log_file="${1:-${SHELL_UTILS_LOG_FILE}}"

    if [[ -n "${log_file}" ]]; then
        {
            echo "================================================================="
            echo "Completed: $(date)"
            echo "================================================================="
        } >>"${SHELL_UTILS_LOG_FILE}"
    fi
}

# Helper to get script directory (useful for relative paths)
get_script_dir() {
    cd "$(dirname "${BASH_SOURCE[1]}")" && pwd
}

# Helper to get project root (assuming this file is in scripts/ subdirectory)
get_project_root() {
    cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

# Validate that required environment variables are set
require_env_vars() {
    local missing_vars=()
    for var in "$@"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("${var}")
        fi
    done

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi
}

# Safe directory change with error handling
safe_cd() {
    local target_dir="$1"
    if [[ ! -d "${target_dir}" ]]; then
        log_error "Directory does not exist: ${target_dir}"
        return 1
    fi

    if ! cd "${target_dir}"; then
        log_error "Failed to change to directory: ${target_dir}"
        return 1
    fi

    log_debug "Changed to directory: $(pwd)"
}

# Execute command with logging
execute_with_log() {
    local cmd="$*"
    log_info "Executing: ${cmd}"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_warning "DRY RUN: Would execute: ${cmd}"
        return 0
    fi

    if eval "${cmd}"; then
        log_success "Command completed successfully"
        return 0
    else
        local exit_code=$?
        log_error "Command failed with exit code ${exit_code}: ${cmd}"
        return ${exit_code}
    fi
}

# Show usage/help information
show_script_usage() {
    local script_name="${1:-$(basename "${0}")}"
    local description="${2:-No description provided}"
    local usage="${3:-Usage: ${script_name} [options]}"

    cat <<EOF
${WHITE}${script_name}${NC}

${description}

${BLUE}USAGE:${NC}
    ${usage}

${BLUE}ENVIRONMENT VARIABLES:${NC}
    SHELL_UTILS_LOG_FILE    Optional log file path for tee output
    DEBUG                   Set to 'true' to enable debug logging
    TRACE                   Set to 'true' to enable trace logging
    DRY_RUN                 Set to 'true' to show commands without executing

${BLUE}AVAILABLE FUNCTIONS:${NC}
    Logging: log_info, log_success, log_warning, log_error, log_debug, log_trace
    HTTP Testing: test_http_endpoint <url> [expected_content] [timeout]
    Retry Logic: retry_with_timeout <description> <max_attempts> <sleep_interval> <command>
    Timing: time_operation <operation_name> <command>
    Sudo Management: ensure_sudo_cached, run_with_sudo, clear_sudo_cache
    Utilities: command_exists, safe_cd, execute_with_log, require_env_vars

${BLUE}EXAMPLES:${NC}
    # Enable logging to file
    export SHELL_UTILS_LOG_FILE="/tmp/my-script.log"
    
    # Enable debug mode
    export DEBUG=true
    
    # Test HTTP endpoint
    if [[ \$(test_http_endpoint "https://example.com" "success") == "success" ]]; then
        log_success "Endpoint is working"
    fi
    
    # Retry with timeout
    retry_with_timeout "Testing connection" 5 2 "ping -c1 example.com >/dev/null"
    
    # Time an operation
    time_operation "Deployment" "make deploy"

EOF
}

# Sudo cache management functions

# Check if sudo credentials are cached
is_sudo_cached() {
    sudo -n true 2>/dev/null
}

# Warn user about upcoming sudo operations and ensure sudo is cached
ensure_sudo_cached() {
    local operation_description="${1:-the operation}"

    if is_sudo_cached; then
        log_debug "Sudo credentials already cached"
        return 0
    fi

    log_warning "The next step requires administrator privileges"
    log_info "You may be prompted for your password to ${operation_description}"
    echo ""

    # Use a harmless sudo command to cache credentials
    # This will prompt for password if needed, but won't actually do anything
    if sudo -v; then
        log_success "Administrator privileges confirmed"
        return 0
    else
        log_error "Failed to obtain administrator privileges"
        return 1
    fi
}

# Run a command with sudo, ensuring credentials are cached first
run_with_sudo() {
    local description="$1"
    shift

    if ! ensure_sudo_cached "$description"; then
        return 1
    fi

    # Now run the actual command - no password prompt expected
    sudo "$@"
}

# Clear sudo cache (useful for testing or security)
clear_sudo_cache() {
    sudo -k
    log_debug "Sudo credentials cache cleared"
}

# HTTP and Network Testing Functions

# Test HTTP endpoints with optional content validation
test_http_endpoint() {
    local url="$1"
    local expected_content="$2"
    local timeout="${3:-5}"

    local response
    response=$(curl -f -s --max-time "${timeout}" "${url}" 2>/dev/null || echo "")

    if [[ -n "${expected_content}" ]] && echo "${response}" | grep -q "${expected_content}"; then
        echo "success"
    elif [[ -z "${expected_content}" ]] && [[ -n "${response}" ]]; then
        echo "success"
    else
        echo "failed"
    fi
}

# Retry Logic and Timing Functions

# Execute a command with retry logic and configurable parameters
retry_with_timeout() {
    local description="$1"
    local max_attempts="$2"
    local sleep_interval="$3"
    local test_command="$4"

    local attempt=1
    while [[ ${attempt} -le ${max_attempts} ]]; do
        log_info "${description} (attempt ${attempt}/${max_attempts})..."

        if eval "${test_command}"; then
            return 0
        fi

        if [[ ${attempt} -eq ${max_attempts} ]]; then
            log_error "${description} failed after ${max_attempts} attempts"
            return 1
        fi

        sleep "${sleep_interval}"
        ((attempt++))
    done
}

# Time an operation and log the duration
time_operation() {
    local operation_name="$1"
    local command="$2"

    local start_time
    start_time=$(date +%s)

    if eval "${command}"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "${operation_name} completed successfully in ${duration} seconds"
        return 0
    else
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_error "${operation_name} failed after ${duration} seconds"
        return 1
    fi
}

# =============================================================================
# Infrastructure Waiting Functions
# =============================================================================

# Helper function to get VM IP address from libvirt
get_vm_ip_from_libvirt() {
    virsh domifaddr torrust-tracker-demo 2>/dev/null | grep ipv4 | awk '{print $4}' | cut -d'/' -f1 || echo ""
}

# Helper function for SSH connections with standard options
ssh_to_vm() {
    local vm_ip="$1"
    local command="$2"
    local output_redirect="${3:->/dev/null 2>&1}"

    eval ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no torrust@"${vm_ip}" "\"${command}\"" "${output_redirect}"
}

# Wait for VM IP assignment after infrastructure provisioning
wait_for_vm_ip() {
    local environment="${1:-local}"
    local project_root="${2:-$(pwd)}"
    
    log_info "⏳ Waiting for VM IP assignment..."
    local max_attempts=30
    local attempt=1
    local vm_ip=""

    while [[ ${attempt} -le ${max_attempts} ]]; do
        log_info "   Checking for VM IP (attempt ${attempt}/${max_attempts})..."

        # Try to get IP from terraform output
        cd "${project_root}" || return 1
        vm_ip=$(make infra-status ENVIRONMENT="${environment}" 2>/dev/null | grep "vm_ip" | grep -v "No IP assigned yet" | awk -F '"' '{print $2}' || echo "")

        if [[ -n "${vm_ip}" && "${vm_ip}" != "No IP assigned yet" ]]; then
            log_success "✅ VM IP assigned: ${vm_ip}"
            return 0
        fi

        # Also check libvirt directly as fallback
        vm_ip=$(get_vm_ip_from_libvirt)
        if [[ -n "${vm_ip}" ]]; then
            log_success "✅ VM IP assigned (via libvirt): ${vm_ip}"
            # Refresh terraform state to sync with actual VM state
            log_info "   Refreshing terraform state to sync with VM..."
            make infra-refresh-state ENVIRONMENT="${environment}" || true
            return 0
        fi

        log_info "   VM IP not yet assigned, waiting 10 seconds..."
        sleep 10
        ((attempt++))
    done

    log_error "❌ Timeout waiting for VM IP assignment after $((max_attempts * 10)) seconds"
    log_error "   VM may still be starting or cloud-init may be running"
    log_error "   You can check manually with: virsh domifaddr torrust-tracker-demo"
    return 1
}

# Wait for VM to be fully ready (cloud-init completion and Docker availability)
wait_for_cloud_init_completion() {
    local environment="${1:-local}"
    
    log_info "⏳ Waiting for cloud-init to complete..."
    local max_attempts=60 # 10 minutes total
    local attempt=1
    local vm_ip=""

    # First get the VM IP
    vm_ip=$(get_vm_ip_from_libvirt)
    if [[ -z "${vm_ip}" ]]; then
        log_error "❌ VM IP not available - cannot check readiness"
        return 1
    fi

    log_info "   VM IP: ${vm_ip} - checking cloud-init readiness..."

    while [[ ${attempt} -le ${max_attempts} ]]; do
        log_info "   Checking cloud-init status (attempt ${attempt}/${max_attempts})..."

        # Check if SSH is available
        if ! ssh_to_vm "${vm_ip}" "echo 'SSH OK'"; then
            log_info "   SSH not ready yet, waiting 10 seconds..."
            sleep 10
            ((attempt++))
            continue
        fi

        # Primary check: Official cloud-init status
        local cloud_init_status
        cloud_init_status=$(ssh_to_vm "${vm_ip}" "cloud-init status" "2>/dev/null" || echo "unknown")

        if [[ "${cloud_init_status}" == *"done"* ]]; then
            log_success "✅ Cloud-init reports completion: ${cloud_init_status}"

            # Secondary check: Custom completion marker file
            if ssh_to_vm "${vm_ip}" "test -f /var/lib/cloud/torrust-setup-complete"; then
                log_success "✅ Setup completion marker found"
                
                # Tertiary check: Verify critical services are available
                # Note: This is not tied to specific software, just basic system readiness
                if ssh_to_vm "${vm_ip}" "systemctl is-active docker >/dev/null 2>&1"; then
                    log_success "✅ Critical services are active"
                    log_success "🎉 VM is ready for application deployment"
                    return 0
                else
                    log_info "   Critical services not ready yet, waiting 10 seconds..."
                fi
            else
                log_info "   Setup completion marker not found yet, waiting 10 seconds..."
            fi
        elif [[ "${cloud_init_status}" == *"error"* ]]; then
            log_error "❌ Cloud-init failed with error status: ${cloud_init_status}"
            
            # Try to get more detailed error information
            local cloud_init_result
            cloud_init_result=$(ssh_to_vm "${vm_ip}" "cloud-init status --long" "2>/dev/null" || echo "unknown")
            log_error "   Cloud-init detailed status: ${cloud_init_result}"
            return 1
        else
            log_info "   Cloud-init status: ${cloud_init_status}, waiting 10 seconds..."
        fi

        sleep 10
        ((attempt++))
    done

    log_error "❌ Timeout waiting for cloud-init to finish after $((max_attempts * 10)) seconds"
    log_error "   You can check manually with: ssh torrust@${vm_ip} 'cloud-init status --long'"
    return 1
}
