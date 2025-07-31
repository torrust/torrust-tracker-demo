#!/bin/bash
# Application-specific shell utilities for Torrust Tracker Demo
# Common logging functions for application scripts
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

# Application shell utilities - can be sourced multiple times safely
export APP_SHELL_UTILS_LOADED=1

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
