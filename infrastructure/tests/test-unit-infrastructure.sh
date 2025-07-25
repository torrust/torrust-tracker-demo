#!/bin/bash
# Unit tests for infrastructure prerequisites and setup validation
# Focus: Validate libvirt, KVM, networking setup without deployment
# Scope: Local infrastructure prerequisites validation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST_LOG_FILE="/tmp/torrust-unit-infrastructure-test.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "$1" | tee -a "${TEST_LOG_FILE}"
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

# Initialize test log
init_test_log() {
    {
        echo "Unit Tests - Infrastructure Prerequisites"
        echo "Started: $(date)"
        echo "================================================================="
    } >"${TEST_LOG_FILE}"
}

# Test libvirt prerequisites with comprehensive checking
test_libvirt_prerequisites() {
    log_info "Testing libvirt prerequisites..."

    local failed=0

    # Check if libvirt is installed and running
    if systemctl is-active --quiet libvirtd; then
        log_success "libvirtd service is running"
    else
        log_error "libvirtd service is not running. Run: sudo systemctl start libvirtd"
        failed=1
    fi

    # Check if user can access libvirt
    if virsh list >/dev/null 2>&1; then
        log_success "User has libvirt access"
    elif sudo virsh list >/dev/null 2>&1; then
        log_warning "User can access libvirt with sudo (group membership may need refresh)"
        log_info "To fix this, run one of the following:"
        log_info "  1. Log out and log back in"
        log_info "  2. Run: newgrp libvirt"
        log_info "  3. Run: exec su -l \$USER"
        log_info "For unit testing, we'll continue with sudo access..."
        export LIBVIRT_NEEDS_SUDO=1
    else
        log_error "User cannot access libvirt even with sudo"
        log_error "Please check if libvirt is properly installed:"
        log_error "  sudo systemctl status libvirtd"
        log_error "  sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients"
        failed=1
    fi

    # Check if default network exists and is active
    local net_check_cmd="virsh net-list --all"
    if [ "${LIBVIRT_NEEDS_SUDO:-}" = "1" ]; then
        net_check_cmd="sudo $net_check_cmd"
    fi

    if $net_check_cmd | grep -q "default.*active"; then
        log_success "Default libvirt network is active"
    elif $net_check_cmd | grep -q "default"; then
        log_warning "Default network exists but is not active"
        log_info "Run: virsh net-start default && virsh net-autostart default"
    else
        log_warning "Default libvirt network does not exist"
        log_info "This may be created automatically during first deployment"
    fi

    # Check KVM support
    if [ -r /dev/kvm ]; then
        log_success "KVM support available"
    else
        log_error "KVM support not available"
        log_error "Check if virtualization is enabled in BIOS"
        failed=1
    fi

    # Check if default storage pool exists and is active
    local pool_check_cmd="virsh pool-list --all"
    if [ "${LIBVIRT_NEEDS_SUDO:-}" = "1" ]; then
        pool_check_cmd="sudo $pool_check_cmd"
    fi

    if $pool_check_cmd | grep -q "default.*active"; then
        log_success "Default storage pool is active"
    elif $pool_check_cmd | grep -q "default"; then
        log_warning "Default storage pool exists but is not active"
        log_info "Run: virsh pool-start default"
    else
        log_warning "Default storage pool does not exist"
        log_info "This will be created automatically during deployment"
    fi

    # Check libvirt images directory permissions
    if [ -d "/var/lib/libvirt/images" ]; then
        local images_owner
        images_owner=$(stat -c "%U:%G" /var/lib/libvirt/images 2>/dev/null || echo "unknown:unknown")
        if [ "$images_owner" = "libvirt-qemu:libvirt" ]; then
            log_success "libvirt images directory has correct ownership"
        else
            log_warning "libvirt images directory ownership may need fixing (currently: $images_owner)"
            log_info "Run 'make fix-libvirt' if deployment fails with permission errors"
        fi
    fi

    return ${failed}
}

# Test cloud-init syntax validation
test_cloud_init_syntax() {
    log_info "Testing cloud-init syntax validation..."

    local failed=0
    local cloud_init_dir="${PROJECT_ROOT}/infrastructure/cloud-init"

    if [[ ! -d "${cloud_init_dir}" ]]; then
        log_warning "Cloud-init directory not found: ${cloud_init_dir}"
        return 0
    fi

    # Find cloud-init files
    local cloud_init_files
    cloud_init_files=$(find "${cloud_init_dir}" -name "*.yaml" -o -name "*.yml" | head -10)

    if [[ -z "${cloud_init_files}" ]]; then
        log_warning "No cloud-init YAML files found"
        return 0
    fi

    # Test each cloud-init file
    for file in ${cloud_init_files}; do
        local filename
        filename=$(basename "${file}")

        # Skip template files (they need variable substitution)
        if [[ "${filename}" == *.tpl ]]; then
            log_info "Skipping template file: ${filename}"
            continue
        fi

        # Basic YAML syntax check
        if command -v yamllint >/dev/null 2>&1; then
            if ! yamllint -c "${PROJECT_ROOT}/.yamllint-ci.yml" "${file}" >/dev/null 2>&1; then
                log_error "Cloud-init YAML syntax error in: ${filename}"
                failed=1
            else
                log_success "Cloud-init YAML syntax valid: ${filename}"
            fi
        else
            # Fallback to basic YAML parsing with Python
            if ! command -v python3 >/dev/null 2>&1; then
                log_warning "python3 not found, cannot validate YAML syntax"
                return 0
            fi
            if ! python3 -c "import yaml; yaml.safe_load(open('${file}'))" >/dev/null 2>&1; then
                log_error "Cloud-init YAML syntax error in: ${filename}"
                failed=1
            else
                log_success "Cloud-init YAML syntax valid: ${filename}"
            fi
        fi

        # Check for cloud-init header (only user-data files should have it)
        if [[ "${filename}" == *"user-data"* ]]; then
            if grep -q "#cloud-config" "${file}"; then
                log_success "Cloud-init header found in: ${filename}"
            else
                log_warning "No #cloud-config header in user-data file: ${filename}"
            fi
        fi
    done

    return ${failed}
}

# Test VM-related tool availability
test_vm_tools() {
    log_info "Testing VM management tools availability..."

    local failed=0
    local required_vm_tools=("virsh" "virt-viewer" "genisoimage")
    local optional_vm_tools=("virt-manager" "virt-install")

    # Test required VM tools
    for tool in "${required_vm_tools[@]}"; do
        if ! command -v "${tool}" >/dev/null 2>&1; then
            log_error "Required VM tool not found: ${tool}"
            failed=1
        else
            log_success "VM tool available: ${tool}"
        fi
    done

    # Test optional VM tools (warn but don't fail)
    for tool in "${optional_vm_tools[@]}"; do
        if ! command -v "${tool}" >/dev/null 2>&1; then
            log_warning "Optional VM tool not found: ${tool}"
        else
            log_success "Optional VM tool available: ${tool}"
        fi
    done

    return ${failed}
}

# Test that we can create temporary VMs (dry-run style validation)
test_vm_creation_prerequisites() {
    log_info "Testing VM creation prerequisites..."

    local failed=0

    # Check available disk space for VM images
    local available_space
    available_space=$(df /var/lib/libvirt/images 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    local available_gb=$((available_space / 1024 / 1024))

    if [[ ${available_gb} -gt 20 ]]; then
        log_success "Sufficient disk space available: ${available_gb}GB"
    elif [[ ${available_gb} -gt 10 ]]; then
        log_warning "Limited disk space available: ${available_gb}GB (recommended: >20GB)"
    else
        log_error "Insufficient disk space: ${available_gb}GB (minimum: 10GB)"
        failed=1
    fi

    # Check available memory
    local available_memory
    available_memory=$(free -m | awk 'NR==2 {print $7}' || echo "0")

    if [[ ${available_memory} -gt 4000 ]]; then
        log_success "Sufficient available memory: ${available_memory}MB"
    elif [[ ${available_memory} -gt 2000 ]]; then
        log_warning "Limited available memory: ${available_memory}MB (recommended: >4GB)"
    else
        log_error "Insufficient available memory: ${available_memory}MB (minimum: 2GB)"
        failed=1
    fi

    # Check CPU virtualization support
    if grep -E '(vmx|svm)' /proc/cpuinfo >/dev/null 2>&1; then
        log_success "CPU virtualization support detected"
    else
        log_error "CPU virtualization support not detected"
        log_error "Check if virtualization is enabled in BIOS/UEFI"
        failed=1
    fi

    return ${failed}
}

# Run all infrastructure unit tests
run_unit_tests() {
    local failed=0

    init_test_log

    log_info "Running infrastructure prerequisites unit tests..."
    log_info "Working directory: ${PROJECT_ROOT}"

    # Run all unit tests
    test_vm_tools || failed=1
    test_libvirt_prerequisites || failed=1
    test_cloud_init_syntax || failed=1
    test_vm_creation_prerequisites || failed=1

    # Final result
    if [[ ${failed} -eq 0 ]]; then
        log_success "All infrastructure unit tests passed!"
        log_info "System is ready for VM deployment"
        log_info "Test log: ${TEST_LOG_FILE}"
        return 0
    else
        log_error "Some infrastructure unit tests failed!"
        log_error "System may not be ready for VM deployment"
        log_error "Check test log for details: ${TEST_LOG_FILE}"
        return 1
    fi
}

# Help function
show_help() {
    cat <<EOF
Unit Tests - Infrastructure Prerequisites

Tests infrastructure prerequisites without deploying VMs.

Usage: $0 [COMMAND]

Commands:
    full-test       Run all infrastructure unit tests (default)
    libvirt         Test libvirt prerequisites only
    cloud-init      Test cloud-init syntax only
    vm-tools        Test VM management tools only
    vm-prereq       Test VM creation prerequisites only
    help           Show this help message

Examples:
    $0                    # Run all infrastructure unit tests
    $0 libvirt           # Test libvirt setup only
    $0 cloud-init        # Test cloud-init files only

Test log: ${TEST_LOG_FILE}
EOF
}

# Main execution
main() {
    local command="${1:-full-test}"

    case "${command}" in
    "full-test")
        run_unit_tests
        ;;
    "libvirt")
        init_test_log && test_libvirt_prerequisites
        ;;
    "cloud-init")
        init_test_log && test_cloud_init_syntax
        ;;
    "vm-tools")
        init_test_log && test_vm_tools
        ;;
    "vm-prereq")
        init_test_log && test_vm_creation_prerequisites
        ;;
    "help" | "-h" | "--help")
        show_help
        ;;
    *)
        log_error "Unknown command: ${command}"
        show_help
        exit 1
        ;;
    esac
}

# Execute main function
main "$@"
