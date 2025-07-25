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

${BLUE}EXAMPLES:${NC}
    # Enable logging to file
    export SHELL_UTILS_LOG_FILE="/tmp/my-script.log"
    
    # Enable debug mode
    export DEBUG=true
    
    # Dry run mode
    export DRY_RUN=true

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
