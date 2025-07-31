#!/bin/bash
# Infrastructure-specific shell utilities for Torrust Tracker Demo
# Common logging functions and infrastructure utilities
#
# Usage:
#   # Source this file in your script:
#   source "$(dirname "${BASH_SOURCE[0]}")/shell-utils.sh"
#
#   # Use logging functions:
#   log_info "This is an info message"
#   log_success "Operation completed successfully"
#   log_warning "This is a warning"
#   log_error "This is an error"
#   log_section "Major Section Title"
#
#   # Use sudo management:
#   ensure_sudo_cached "operation description"
#   run_with_sudo "operation description" command args...

# Infrastructure shell utilities - can be sourced multiple times safely
export INFRA_SHELL_UTILS_LOADED=1

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
log() {
    local message="$1"
    echo -e "${message}"
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

# Section header logging - displays a prominent section separator
log_section() {
    log ""
    log "${BLUE}===============================================${NC}"
    log "${BLUE}$1${NC}"
    log "${BLUE}===============================================${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
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
