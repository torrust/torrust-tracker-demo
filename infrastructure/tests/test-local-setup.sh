#!/bin/bash
# Test script to verify Torrust Tracker infrastructure setup
# This script tests the local VM deployment and basic functionality

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/infrastructure/terraform"
TEST_LOG_FILE="/tmp/torrust-infrastructure-test.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
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

# Test functions
test_prerequisites() {
    log_info "Testing prerequisites..."

    # Check if OpenTofu is installed
    if command -v tofu >/dev/null 2>&1; then
        log_success "OpenTofu is installed: $(tofu version | head -n1)"
    else
        log_error "OpenTofu is not installed"
        return 1
    fi

    # Check if libvirt is installed and running
    if systemctl is-active --quiet libvirtd; then
        log_success "libvirtd service is running"
    else
        log_error "libvirtd service is not running. Run: sudo systemctl start libvirtd"
        return 1
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
        log_info "For now, we'll continue with sudo access..."
        export LIBVIRT_NEEDS_SUDO=1
    else
        log_error "User cannot access libvirt even with sudo"
        log_error "Please check if libvirt is properly installed:"
        log_error "  sudo systemctl status libvirtd"
        log_error "  sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients"
        return 1
    fi

    # Check if default network exists and is active
    local net_check_cmd="virsh net-list --all"
    if [ "${LIBVIRT_NEEDS_SUDO:-}" = "1" ]; then
        net_check_cmd="sudo $net_check_cmd"
    fi

    if $net_check_cmd | grep -q "default.*active"; then
        log_success "Default libvirt network is active"
    elif $net_check_cmd | grep -q "default"; then
        log_warning "Default network exists but is not active, attempting to start..."
        local start_cmd="virsh net-start default && virsh net-autostart default"
        if [ "${LIBVIRT_NEEDS_SUDO:-}" = "1" ]; then
            start_cmd="sudo $start_cmd"
        fi
        if eval "$start_cmd"; then
            log_success "Default network started successfully"
        else
            log_error "Failed to start default network"
            return 1
        fi
    else
        log_error "Default libvirt network does not exist"
        log_error "This is unusual and may indicate a problem with libvirt installation"
        return 1
    fi

    # Check KVM support
    if [ -r /dev/kvm ]; then
        log_success "KVM support available"
    else
        log_error "KVM support not available"
        return 1
    fi

    # Check if default storage pool exists and is active
    local pool_check_cmd="virsh pool-list --all"
    if [ "${LIBVIRT_NEEDS_SUDO:-}" = "1" ]; then
        pool_check_cmd="sudo $pool_check_cmd"
    fi

    if $pool_check_cmd | grep -q "default.*active"; then
        log_success "Default storage pool is active"
    elif $pool_check_cmd | grep -q "default"; then
        log_warning "Default storage pool exists but is not active, attempting to start..."
        local start_pool_cmd="virsh pool-start default"
        if [ "${LIBVIRT_NEEDS_SUDO:-}" = "1" ]; then
            start_pool_cmd="sudo $start_pool_cmd"
        fi
        if eval "$start_pool_cmd"; then
            log_success "Default storage pool started successfully"
        else
            log_error "Failed to start default storage pool"
            return 1
        fi
    else
        log_warning "Default storage pool does not exist, creating it..."
        local create_pool_cmd="virsh pool-define-as default dir --target /var/lib/libvirt/images && virsh pool-autostart default && virsh pool-start default"
        if [ "${LIBVIRT_NEEDS_SUDO:-}" = "1" ]; then
            create_pool_cmd="sudo $create_pool_cmd"
        fi
        if eval "$create_pool_cmd"; then
            log_success "Default storage pool created successfully"
        else
            log_error "Failed to create default storage pool"
            return 1
        fi
    fi

    # Check libvirt images directory permissions
    if [ -d "/var/lib/libvirt/images" ]; then
        local images_owner
        images_owner=$(stat -c "%U:%G" /var/lib/libvirt/images 2>/dev/null || echo "unknown:unknown")
        if [ "$images_owner" = "libvirt-qemu:libvirt" ]; then
            log_success "libvirt images directory has correct ownership"
        else
            log_warning "libvirt images directory ownership needs fixing (currently: $images_owner)"
            log_info "Run 'make fix-libvirt' to fix this automatically"
        fi
    fi

    return 0
}

test_terraform_syntax() {
    log_info "Testing OpenTofu configuration syntax..."

    cd "${TERRAFORM_DIR}"

    # Initialize if needed
    if [ ! -d ".terraform" ]; then
        log_info "Initializing OpenTofu..."
        if tofu init; then
            log_success "OpenTofu initialization successful"
        else
            log_error "OpenTofu initialization failed"
            return 1
        fi
    fi

    # Validate configuration
    if tofu validate; then
        log_success "OpenTofu configuration is valid"
    else
        log_error "OpenTofu configuration validation failed"
        return 1
    fi

    # Plan (dry run) - only if libvirt is available and not in CI
    if [ "${CI:-}" = "true" ]; then
        log_info "CI environment detected, skipping OpenTofu plan (requires libvirt)"
        log_success "OpenTofu syntax validation completed for CI"
    elif [ -S "/var/run/libvirt/libvirt-sock" ]; then
        if tofu plan -out=test.tfplan >/dev/null 2>&1; then
            log_success "OpenTofu plan successful"
            rm -f test.tfplan
        else
            log_error "OpenTofu plan failed"
            return 1
        fi
    else
        log_warning "libvirt not available, skipping OpenTofu plan"
        log_success "OpenTofu syntax validation completed"
    fi

    return 0
}

test_cloud_init_syntax() {
    log_info "Testing cloud-init configuration syntax..."

    local cloud_init_dir="${PROJECT_ROOT}/infrastructure/cloud-init"

    # Check if cloud-init files exist
    local required_files=("user-data.yaml.tpl" "user-data-minimal.yaml.tpl" "meta-data.yaml" "network-config.yaml")
    for file in "${required_files[@]}"; do
        if [ -f "${cloud_init_dir}/${file}" ]; then
            log_success "Found ${file}"
        else
            log_error "Missing ${file}"
            return 1
        fi
    done

    # Validate YAML syntax (if yamllint is available)
    if command -v yamllint >/dev/null 2>&1; then
        # Test static YAML files
        for file in meta-data.yaml network-config.yaml; do
            if yamllint -c "${PROJECT_ROOT}/.yamllint-ci.yml" "${cloud_init_dir}/${file}" >/dev/null 2>&1; then
                log_success "${file} YAML syntax is valid"
            else
                log_warning "${file} YAML syntax check failed (continuing anyway)"
            fi
        done

        # Test template files by substituting variables
        local temp_dir="/tmp/torrust-cloud-init-test"
        mkdir -p "${temp_dir}"

        for template in user-data.yaml.tpl user-data-minimal.yaml.tpl; do
            local test_file="${temp_dir}/${template%.tpl}"
            # Substitute template variables with dummy values for syntax testing
            sed "s/\\\${ssh_public_key}/ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/" "${cloud_init_dir}/${template}" >"${test_file}"

            if yamllint -c "${PROJECT_ROOT}/.yamllint-ci.yml" "${test_file}" >/dev/null 2>&1; then
                log_success "${template} YAML syntax is valid (after variable substitution)"
            else
                log_warning "${template} YAML syntax check failed (continuing anyway)"
            fi
        done

        # Cleanup
        rm -rf "${temp_dir}"
    else
        log_warning "yamllint not available, skipping YAML syntax validation"
    fi

    return 0
}

deploy_vm() {
    log_info "Deploying test VM..."

    cd "${TERRAFORM_DIR}"

    # Apply configuration
    if tofu apply -auto-approve; then
        log_success "VM deployment successful"
        return 0
    else
        log_error "VM deployment failed"
        return 1
    fi
}

test_vm_connectivity() {
    log_info "Testing VM connectivity..."

    cd "${TERRAFORM_DIR}"

    # Get VM IP from Terraform output
    local vm_ip
    vm_ip=$(tofu output -raw vm_ip 2>/dev/null || echo "")

    if [ -z "${vm_ip}" ]; then
        log_error "Could not get VM IP from OpenTofu output"
        return 1
    fi

    log_info "VM IP: ${vm_ip}"

    # Wait for VM to be ready (cloud-init can take time)
    log_info "Waiting for VM to be ready (this may take a few minutes)..."
    local max_attempts=30
    local attempt=1

    while [ ${attempt} -le ${max_attempts} ]; do
        if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o BatchMode=yes torrust@"${vm_ip}" "echo 'VM is ready'" >/dev/null 2>&1; then
            log_success "VM is accessible via SSH"
            break
        fi

        log_info "Attempt ${attempt}/${max_attempts}: VM not ready yet, waiting..."
        sleep 20
        ((attempt++))
    done

    if [ ${attempt} -gt ${max_attempts} ]; then
        log_error "VM did not become accessible within expected time"
        return 1
    fi

    return 0
}

test_vm_services() {
    log_info "Testing VM services..."

    cd "${TERRAFORM_DIR}"
    local vm_ip
    vm_ip=$(tofu output -raw vm_ip)

    # Test Docker installation
    if ssh -o StrictHostKeyChecking=no torrust@"${vm_ip}" "docker --version" >/dev/null 2>&1; then
        log_success "Docker is installed and accessible"
    else
        log_error "Docker is not working"
        return 1
    fi

    # Test UFW status
    if ssh -o StrictHostKeyChecking=no torrust@"${vm_ip}" "sudo ufw status" | grep -q "Status: active"; then
        log_success "UFW firewall is active"
    else
        log_error "UFW firewall is not active"
        return 1
    fi

    # Test if required ports are open
    local required_ports=("22" "80" "443" "6868" "6969" "7070" "1212")
    for port in "${required_ports[@]}"; do
        if ssh -o StrictHostKeyChecking=no torrust@"${vm_ip}" "sudo ufw status numbered" | grep -q "${port}"; then
            log_success "Port ${port} is configured in UFW"
        else
            log_warning "Port ${port} might not be configured in UFW"
        fi
    done

    return 0
}

cleanup_vm() {
    log_info "Cleaning up test VM..."

    cd "${TERRAFORM_DIR}"

    if tofu destroy -auto-approve; then
        log_success "VM cleanup successful"
    else
        log_error "VM cleanup failed"
        return 1
    fi

    return 0
}

run_full_test() {
    log_info "Starting full infrastructure test..."
    echo "Test started at: $(date)" >"${TEST_LOG_FILE}"

    local failed=0

    test_prerequisites || failed=1
    test_terraform_syntax || failed=1
    test_cloud_init_syntax || failed=1

    if [ ${failed} -eq 0 ]; then
        deploy_vm || failed=1

        if [ ${failed} -eq 0 ]; then
            test_vm_connectivity || failed=1
            test_vm_services || failed=1
        fi

        # Always try to cleanup
        cleanup_vm || log_warning "Cleanup failed, manual cleanup may be required"
    fi

    if [ ${failed} -eq 0 ]; then
        log_success "All tests passed!"
        return 0
    else
        log_error "Some tests failed. Check ${TEST_LOG_FILE} for details."
        return 1
    fi
}

# Help function
show_help() {
    cat <<EOF
Torrust Tracker Infrastructure Test Script

Usage: $0 [COMMAND]

Commands:
    full-test       Run complete test suite (default)
    prerequisites   Test only prerequisites
    syntax          Test configuration syntax only
    deploy          Deploy VM only
    connectivity    Test VM connectivity only
    services        Test VM services only
    cleanup         Cleanup/destroy VM only
    help           Show this help message

Examples:
    $0                    # Run full test
    $0 prerequisites      # Check if tools are installed
    $0 syntax            # Validate configurations
    $0 deploy            # Deploy VM for manual testing

Test log is written to: ${TEST_LOG_FILE}
EOF
}

# Main execution
main() {
    local command="${1:-full-test}"

    case "${command}" in
    "full-test")
        run_full_test
        ;;
    "prerequisites")
        test_prerequisites
        ;;
    "syntax")
        test_terraform_syntax && test_cloud_init_syntax
        ;;
    "deploy")
        deploy_vm
        ;;
    "connectivity")
        test_vm_connectivity
        ;;
    "services")
        test_vm_services
        ;;
    "cleanup")
        cleanup_vm
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

# Run main function with all arguments
main "$@"
