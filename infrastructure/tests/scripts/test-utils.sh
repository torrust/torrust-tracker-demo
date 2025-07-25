#!/bin/bash
# Shared test utilities for infrastructure script tests
# Common functions and configuration used across all script test files

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "$1" | tee -a "${TEST_LOG_FILE:-/tmp/torrust-test.log}"
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
    log "${RED}[ERROR]${NC} $1"
}

# Test script exists and is executable
test_script_executable() {
    local script_path="$1"
    local script_name
    script_name=$(basename "${script_path}")

    if [[ ! -f "${script_path}" ]]; then
        log_error "Script not found: ${script_name}"
        return 1
    fi

    if [[ ! -x "${script_path}" ]]; then
        log_error "Script not executable: ${script_name}"
        return 1
    fi

    log_success "Script exists and is executable: ${script_name}"
    return 0
}

# Test script help/usage functionality
test_script_help() {
    local script_path="$1"
    local script_name
    script_name=$(basename "${script_path}")

    log_info "Testing help functionality for: ${script_name}"

    # Try common help flags
    local help_flags=("help" "--help" "-h")
    local help_working=false

    for flag in "${help_flags[@]}"; do
        if "${script_path}" "${flag}" >/dev/null 2>&1; then
            help_working=true
            break
        fi
    done

    if [[ "${help_working}" == "true" ]]; then
        log_success "Help functionality works for: ${script_name}"
        return 0
    else
        log_warning "No help functionality found for: ${script_name}"
        return 0 # Don't fail on this, just warn
    fi
}

# Test script shebang and basic structure
test_script_structure() {
    local script_path="$1"
    local script_name
    script_name=$(basename "${script_path}")

    log_info "Testing script structure for: ${script_name}"

    local failed=0

    # Check shebang
    local first_line
    first_line=$(head -n1 "${script_path}")
    if [[ ! "${first_line}" =~ ^#!/bin/bash ]]; then
        log_warning "Script ${script_name} doesn't use #!/bin/bash shebang"
    fi

    # Check for set -euo pipefail (good practice)
    if ! grep -q "set -euo pipefail" "${script_path}"; then
        log_warning "Script ${script_name} doesn't use 'set -euo pipefail'"
    fi

    log_success "Script structure validation completed for: ${script_name}"
    return ${failed}
}

# Initialize test log for individual script tests
init_script_test_log() {
    local script_name="$1"
    local log_file="${2:-/tmp/torrust-test-${script_name}.log}"

    {
        echo "Unit Tests - ${script_name}"
        echo "Started: $(date)"
        echo "================================================================="
    } >"${log_file}"

    export TEST_LOG_FILE="${log_file}"
}

# Common test configuration
# Get project paths
get_project_paths() {
    # Get project root from the script's location, handling nested sources
    local source_path
    source_path="${BASH_SOURCE[0]}"
    if [[ -L "${source_path}" ]]; then
        source_path="$(readlink "${source_path}")"
    fi
    # Handle being sourced from other scripts
    local script_dir
    script_dir="$(cd "$(dirname "${source_path}")" && pwd)"

    # Traverse up to find project root (marked by .git directory)
    local root_dir="${script_dir}"
    while [[ ! -d "${root_dir}/.git" && "${root_dir}" != "/" ]]; do
        root_dir="$(dirname "${root_dir}")"
    done

    if [[ "${root_dir}" == "/" ]]; then
        log_error "Could not determine project root. Is this a git repository?"
        exit 1
    fi

    PROJECT_ROOT="${root_dir}"
    SCRIPTS_DIR="${PROJECT_ROOT}/infrastructure/scripts"
    TESTS_DIR="${PROJECT_ROOT}/infrastructure/tests"
    export PROJECT_ROOT SCRIPTS_DIR TESTS_DIR
}
