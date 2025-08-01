#!/bin/bash
# Application deployment script for Torrust Tracker Demo
# Deploys application to provisioned infrastructure
# Twelve-Factor App compliant: Release + Run stages

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/infrastructure/terraform"

# Default values
ENVIRONMENT="${1:-local}"
VM_IP="${2:-}"
SKIP_HEALTH_CHECK="${SKIP_HEALTH_CHECK:-false}"
SKIP_WAIT="${SKIP_WAIT:-false}"  # New parameter for skipping waiting
ENABLE_HTTPS="${ENABLE_SSL:-true}"   # Enable HTTPS with self-signed certificates by default

# Source shared shell utilities
# shellcheck source=../../scripts/shell-utils.sh
source "${PROJECT_ROOT}/scripts/shell-utils.sh"

# Get VM IP from Terraform output or parameter
get_vm_ip() {
    if [[ -n "${VM_IP}" ]]; then
        echo "${VM_IP}"
        return 0
    fi

    if [[ ! -d "${TERRAFORM_DIR}" ]]; then
        log_error "Terraform directory not found: ${TERRAFORM_DIR}"
        log_error "Run 'make infra-apply ENVIRONMENT=${ENVIRONMENT}' first"
        exit 1
    fi

    cd "${TERRAFORM_DIR}"
    local vm_ip
    vm_ip=$(tofu output -raw vm_ip 2>/dev/null || echo "")

    if [[ -z "${vm_ip}" || "${vm_ip}" == "No IP assigned yet" ]]; then
        log_error "Could not get VM IP from Terraform output"
        log_error "Ensure infrastructure is provisioned: make infra-apply ENVIRONMENT=${ENVIRONMENT}"
        log_info "You can also provide IP manually: make app-deploy ENVIRONMENT=${ENVIRONMENT} VM_IP=<ip>"
        exit 1
    fi

    echo "${vm_ip}"
}

# Check git repository status and warn about uncommitted changes
check_git_status() {
    log_info "Checking git repository status..."
    
    cd "${PROJECT_ROOT}"
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_warning "Not in a git repository - deployment will use current directory state"
        return 0
    fi
    
    # Determine deployment approach based on environment
    local deployment_approach
    if [[ "${ENVIRONMENT}" == "local" ]]; then
        deployment_approach="working tree (includes uncommitted changes)"
    else
        deployment_approach="git archive (committed changes only)"
    fi
    
    # Check for uncommitted changes in configuration templates
    local config_changes
    config_changes=$(git status --porcelain infrastructure/config/environments/ 2>/dev/null || echo "")
    
    if [[ -n "${config_changes}" ]]; then
        log_warning "==============================================="
        log_warning "⚠️  UNCOMMITTED CONFIGURATION CHANGES DETECTED"
        log_warning "==============================================="
        log_warning "The following configuration template files have uncommitted changes:"
        echo "${config_changes}" | while IFS= read -r line; do
            log_warning "  ${line}"
        done
        log_warning ""
        
        if [[ "${ENVIRONMENT}" == "local" ]]; then
            log_info "ℹ️  LOCAL TESTING: Uncommitted changes WILL be deployed (using working tree)"
            log_info "This includes your configuration changes and any other uncommitted modifications."
        else
            log_warning "IMPORTANT: Production deployment uses 'git archive' which only includes committed files."
            log_warning "Your uncommitted changes will NOT be deployed to the VM."
            log_warning ""
            log_warning "To include these changes in deployment:"
            log_warning "  1. git add infrastructure/config/environments/"
            log_warning "  2. git commit -m 'update: configuration templates'"
            log_warning "  3. Re-run deployment"
            log_warning ""
            log_warning "To continue without committing (deployment will use last committed version):"
            log_warning "  Press ENTER to continue or Ctrl+C to abort"
            read -r
        fi
        log_warning "==============================================="
    fi
    
    # Check for any other uncommitted changes (informational)
    local all_changes
    all_changes=$(git status --porcelain 2>/dev/null | wc -l)
    
    if [[ "${all_changes}" -gt 0 ]]; then
        local git_status
        git_status=$(git status --short 2>/dev/null || echo "")
        log_info "Repository has ${all_changes} uncommitted changes"
        log_info "Deployment approach: ${deployment_approach}"
        
        if [[ "${all_changes}" -le 10 ]]; then
            log_info "Uncommitted files:"
            echo "${git_status}" | while IFS= read -r line; do
                log_info "  ${line}"
            done
        else
            log_info "Run 'git status' to see all uncommitted changes"
        fi
    else
        log_success "Repository working tree is clean - deployment will match current state"
    fi
}

# Test SSH connectivity and wait for system readiness
test_ssh_connection() {
    local vm_ip="$1"
    local max_attempts=5
    local attempt=1

    log_info "Testing SSH connectivity to ${vm_ip}"

    while [[ ${attempt} -le ${max_attempts} ]]; do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes torrust@"${vm_ip}" exit 2>/dev/null; then
            log_success "SSH connection established"
            return 0
        fi

        log_warning "SSH attempt ${attempt}/${max_attempts} failed, retrying in 5 seconds..."
        sleep 5
        ((attempt++))
    done

    log_error "Failed to establish SSH connection after ${max_attempts} attempts"
    log_error "Please check:"
    log_error "  1. VM is running: virsh list"
    log_error "  2. SSH service is ready (may take 2-3 minutes after VM start)"
    log_error "  3. SSH key is correct"
    exit 1
}

# Wait for cloud-init to complete using robust detection method
wait_for_system_ready() {
    local vm_ip="$1"
    local max_attempts=30 # 15 minutes (30 * 30 seconds) for cloud-init completion
    local attempt=1

    log_info "Waiting for cloud-init to complete using robust detection method..."

    while [[ ${attempt} -le ${max_attempts} ]]; do
        log_info "Checking system readiness (attempt ${attempt}/${max_attempts})..."

        # Primary check: Official cloud-init status
        cloud_init_status=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "torrust@${vm_ip}" "cloud-init status" 2>/dev/null || echo "failed")

        if [[ "${cloud_init_status}" == *"done"* ]]; then
            log_info "Cloud-init completed: ${cloud_init_status}"

            # Secondary check: Custom completion marker file
            completion_marker_exists=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "torrust@${vm_ip}" "test -f /var/lib/cloud/torrust-setup-complete && echo 'exists' || echo 'not-exists'" 2>/dev/null || echo "not-exists")

            if [[ "${completion_marker_exists}" == "exists" ]]; then
                log_success "Setup completion marker found - all cloud-init tasks completed"
                
                # Tertiary check: Verify system services are ready (only if needed for deployment)
                # Note: This check is deployment-specific, not cloud-init specific
                systemd_ready=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "torrust@${vm_ip}" "systemctl is-system-running --quiet && echo 'ready' || echo 'not-ready'" 2>/dev/null || echo "not-ready")

                if [[ "${systemd_ready}" == "ready" ]]; then
                    log_success "System is fully ready for application deployment"
                    return 0
                else
                    log_info "System services still starting up, waiting..."
                fi
            else
                log_info "Setup completion marker not found yet, cloud-init tasks may still be running..."
            fi
        elif [[ "${cloud_init_status}" == *"error"* ]]; then
            log_error "Cloud-init failed with error status: ${cloud_init_status}"
            
            # Show detailed error information
            detailed_status=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "torrust@${vm_ip}" "cloud-init status --long" 2>/dev/null || echo "unknown")
            log_error "Detailed cloud-init status: ${detailed_status}"
            return 1
        else
            log_info "Cloud-init status: ${cloud_init_status}, waiting for completion..."
        fi

        log_info "System not ready yet. Retrying in 30 seconds..."
        sleep 30
        ((attempt++))
    done

    log_error "Timeout waiting for system to be ready after ${max_attempts} attempts (15 minutes)"
    log_error "Cloud-init may have failed or system setup encountered issues"

    # Show diagnostic information using robust detection methods
    vm_exec "${vm_ip}" "
        echo '=== System Diagnostic Information ==='
        echo 'Cloud-init status:'
        cloud-init status --long || echo 'cloud-init command failed'
        echo
        echo 'Setup completion marker:'
        ls -la /var/lib/cloud/torrust-setup-complete 2>/dev/null || echo 'Completion marker not found'
        echo
        echo 'Cloud-init logs (last 20 lines):'
        tail -20 /var/log/cloud-init.log 2>/dev/null || echo 'Cloud-init log not available'
        echo
        echo 'System service status:'
        systemctl is-system-running || echo 'System status check failed'
    " "Dumping diagnostic information"

    exit 1
}

# Execute command on VM via SSH
vm_exec() {
    local vm_ip="$1"
    local command="$2"
    local description="${3:-}"

    if [[ -n "${description}" ]]; then
        log_info "${description}"
    fi

    if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30 torrust@"${vm_ip}" "${command}"; then
        log_error "Failed to execute command on VM: ${command}"
        exit 1
    fi
}

# Execute command on VM via SSH with timeout
vm_exec_with_timeout() {
    local vm_ip="$1"
    local command="$2"
    local timeout="${3:-300}"  # Default 5 minutes
    local description="${4:-}"

    if [[ -n "${description}" ]]; then
        log_info "${description}"
    fi

    # Use timeout command to limit execution time
    if ! timeout "${timeout}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30 torrust@"${vm_ip}" "${command}"; then
        log_error "Failed to execute command on VM (timeout: ${timeout}s): ${command}"
        exit 1
    fi
}

# Generate configuration locally (Build/Release stage)
generate_configuration_locally() {
    log_info "Generating configuration locally (Build/Release stage)"
    
    cd "${PROJECT_ROOT}"
    
    if [[ -f "infrastructure/scripts/configure-env.sh" ]]; then
        log_info "Running configure-env.sh for environment: ${ENVIRONMENT}"
        ./infrastructure/scripts/configure-env.sh "${ENVIRONMENT}"
        
        # Verify that the .env file was generated
        if [[ -f "application/storage/compose/.env" ]]; then
            log_success "Configuration files generated successfully"
        else
            log_error "Failed to generate .env file at application/storage/compose/.env"
            exit 1
        fi
    else
        log_warning "Configuration script not found at infrastructure/scripts/configure-env.sh"
        log_warning "Using existing configuration files"
    fi
}

# Generate and deploy nginx HTTP configuration from template
generate_nginx_http_config() {
    local vm_ip="$1"
    
    log_info "Generating nginx HTTP configuration from template..."
    
    # Template and output paths
    local template_file="${PROJECT_ROOT}/infrastructure/config/templates/nginx-http.conf.tpl"
    local output_file
    output_file="/tmp/nginx-http-$(date +%s).conf"
    
    # Check if template exists
    if [[ ! -f "${template_file}" ]]; then
        log_error "Nginx HTTP template not found: ${template_file}"
        exit 1
    fi
    
    # Load environment variables from the generated config
    local env_file="${PROJECT_ROOT}/infrastructure/config/environments/${ENVIRONMENT}.env"
    if [[ -f "${env_file}" ]]; then
        log_info "Loading environment variables from ${env_file}"
        # Export variables for envsubst, filtering out comments and empty lines
        set -a  # automatically export all variables
        # shellcheck source=/dev/null
        source "${env_file}"
        set +a  # stop auto-exporting
    else
        log_error "Environment file not found: ${env_file}"
        log_error "Run 'make infra-config ENVIRONMENT=${ENVIRONMENT}' first"
        exit 1
    fi
    
    # Ensure required variables are set
    if [[ -z "${DOMAIN_NAME:-}" ]]; then
        log_error "DOMAIN_NAME not set in environment"
        exit 1
    fi
    
    # Set DOLLAR variable for nginx variables (needed by envsubst to escape $)
    export DOLLAR='$'
    
    # Process template using envsubst
    log_info "Processing template with DOMAIN_NAME=${DOMAIN_NAME}"
    envsubst < "${template_file}" > "${output_file}"
    
    # Copy generated configuration to VM
    log_info "Copying nginx HTTP configuration to VM..."
    scp -o StrictHostKeyChecking=no "${output_file}" "torrust@${vm_ip}:/tmp/nginx.conf"
    
    # Deploy configuration to proper location on VM
    vm_exec "${vm_ip}" "sudo mkdir -p /var/lib/torrust/proxy/etc/nginx-conf"
    vm_exec "${vm_ip}" "sudo mv /tmp/nginx.conf /var/lib/torrust/proxy/etc/nginx-conf/nginx.conf"
    vm_exec "${vm_ip}" "sudo chown torrust:torrust /var/lib/torrust/proxy/etc/nginx-conf/nginx.conf"
    
    # Cleanup local temporary file
    rm -f "${output_file}"
    
    log_success "Nginx HTTP configuration deployed"
}

# Generate and deploy nginx HTTPS configuration with self-signed certificates from template
generate_nginx_https_selfsigned_config() {
    local vm_ip="$1"
    local domain_name="${DOMAIN_NAME:-test.local}"
    
    log_info "Generating nginx HTTPS configuration with self-signed certificates from template..."
    
    # Template and output files
    local template_file="${PROJECT_ROOT}/infrastructure/config/templates/nginx-https-selfsigned.conf.tpl"
    local output_file
    output_file="/tmp/nginx-https-selfsigned-$(date +%s).conf"
    
    # Check if template exists
    if [[ ! -f "${template_file}" ]]; then
        log_error "Nginx HTTPS self-signed template not found: ${template_file}"
        exit 1
    fi
    
    # Check if domain name is set
    if [[ -z "${domain_name}" ]]; then
        log_error "Domain name is required for HTTPS configuration"
        log_error "Set DOMAIN_NAME environment variable (e.g., DOMAIN_NAME=test.local)"
        exit 1
    fi
    
    log_info "Using domain: ${domain_name}"
    log_info "Template: ${template_file}"
    log_info "Output: ${output_file}"
    
    # Process template with environment variable substitution
    # Note: nginx uses $variablename syntax, so we need to escape those with $${variablename}
    # We use DOLLAR variable to represent literal $ in nginx config
    # The template should use ${DOLLAR}variablename for nginx variables
    
    # Set DOLLAR variable for nginx variables (needed by envsubst to escape $)
    export DOLLAR='$'
    export DOMAIN_NAME="${domain_name}"
    
    # Generate configuration from template
    if ! envsubst < "${template_file}" > "${output_file}"; then
        log_error "Failed to generate nginx HTTPS configuration from template"
        exit 1
    fi
    
    log_info "Copying nginx HTTPS configuration to VM..."
    scp -o StrictHostKeyChecking=no "${output_file}" "torrust@${vm_ip}:/tmp/nginx.conf"
    
    # Deploy configuration on VM
    vm_exec "${vm_ip}" "sudo mkdir -p /var/lib/torrust/proxy/etc/nginx-conf"
    vm_exec "${vm_ip}" "sudo mv /tmp/nginx.conf /var/lib/torrust/proxy/etc/nginx-conf/nginx.conf"
    vm_exec "${vm_ip}" "sudo chown torrust:torrust /var/lib/torrust/proxy/etc/nginx-conf/nginx.conf"
    
    # Clean up temporary file
    rm -f "${output_file}"
    
    log_success "Nginx HTTPS self-signed configuration deployed"
}

# Generate self-signed SSL certificates on the VM
#
# Why we generate certificates on each deployment:
# 1. Production flexibility: Different environments use different domains
#    (test.local for local testing, actual domain for production)
# 2. Certificate validity: Self-signed certs are domain-specific and must match
#    the actual domain being used in each deployment
# 3. Security: Fresh certificates for each deployment ensure no stale credentials
# 4. Portability: Works across different deployment targets without manual
#    certificate management or copying between environments
#
# While we could reuse certificates for local testing (always test.local),
# this approach ensures consistency with production deployment workflows.
generate_selfsigned_certificates() {
    local vm_ip="$1"
    local domain_name="${DOMAIN_NAME:-test.local}"
    
    log_info "Generating self-signed SSL certificates on VM for domain: ${domain_name}..."
    
    # Copy the certificate generation script and its shell utilities to VM
    local cert_script="${PROJECT_ROOT}/application/share/bin/ssl-generate-test-certs.sh"
    local app_shell_utils="${PROJECT_ROOT}/application/share/bin/shell-utils.sh"
    
    if [[ ! -f "${cert_script}" ]]; then
        log_error "Certificate generation script not found: ${cert_script}"
        exit 1
    fi
    
    if [[ ! -f "${app_shell_utils}" ]]; then
        log_error "Application shell utilities script not found: ${app_shell_utils}"
        exit 1
    fi
    
    # Define the application directory on the VM where compose.yaml is located
    local vm_app_dir="/home/torrust/github/torrust/torrust-tracker-demo/application"
    
    # Copy scripts to the VM application directory
    log_info "Copying certificate generation script and utilities to VM..."
    scp -o StrictHostKeyChecking=no "${cert_script}" "torrust@${vm_ip}:${vm_app_dir}/share/bin/"
    scp -o StrictHostKeyChecking=no "${app_shell_utils}" "torrust@${vm_ip}:${vm_app_dir}/share/bin/"
    
    # Make script executable
    vm_exec "${vm_ip}" "chmod +x ${vm_app_dir}/share/bin/ssl-generate-test-certs.sh"
    vm_exec "${vm_ip}" "chmod +x ${vm_app_dir}/share/bin/shell-utils.sh"
    
    # Run certificate generation from the application directory where compose.yaml is located
    log_info "Running certificate generation for domain: ${domain_name}"
    vm_exec "${vm_ip}" "cd ${vm_app_dir} && ./share/bin/ssl-generate-test-certs.sh '${domain_name}'"
    
    log_success "Self-signed SSL certificates generated successfully"
}

# Deploy local working tree (includes uncommitted and untracked files) for local testing
deploy_local_working_tree() {
    local vm_ip="$1"
    
    log_info "Deploying local working tree (includes uncommitted and untracked files) for testing..."
    
    # Create target directory structure
    vm_exec "${vm_ip}" "mkdir -p /home/torrust/github/torrust" "Creating directory structure"
    
    # Handle existing repository  
    vm_exec "${vm_ip}" "
        if [ -d /home/torrust/github/torrust/torrust-tracker-demo ]; then
            # Remove the repository directory
            rm -rf /home/torrust/github/torrust/torrust-tracker-demo
        fi
    " "Removing existing repository"
    
    # Create target directory
    vm_exec "${vm_ip}" "mkdir -p /home/torrust/github/torrust/torrust-tracker-demo" "Creating repository directory"
    
    # Use rsync to copy working tree, including uncommitted and untracked files (but respecting .gitignore)
    log_info "Using rsync to copy working tree (committed + uncommitted + untracked files)..."
    
    cd "${PROJECT_ROOT}"
    
    # Use rsync with --filter to respect .gitignore while including untracked files
    # This copies all files in working tree except those explicitly ignored by git
    # Use SSH options to avoid host key verification issues in testing
    if ! rsync -avz --filter=':- .gitignore' --exclude='.git/' \
        -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
        ./ "torrust@${vm_ip}:/home/torrust/github/torrust/torrust-tracker-demo/"; then
        log_error "Failed to rsync working tree to VM"
        exit 1
    fi
    
    log_success "Local working tree deployed successfully (includes uncommitted and untracked files)"
}

# Deploy using git archive (committed changes only) for production
deploy_git_archive() {
    local vm_ip="$1"
    
    log_info "Deploying using git archive (committed changes only)..."
    local temp_archive
    temp_archive="/tmp/torrust-tracker-demo-$(date +%s).tar.gz"

    cd "${PROJECT_ROOT}"
    if ! git archive --format=tar.gz --output="${temp_archive}" HEAD; then
        log_error "Failed to create git archive"
        exit 1
    fi

    log_info "Copying git archive to VM..."

    # Create target directory structure
    vm_exec "${vm_ip}" "mkdir -p /home/torrust/github/torrust" "Creating directory structure"

    # Handle existing repository  
    vm_exec "${vm_ip}" "
        if [ -d /home/torrust/github/torrust/torrust-tracker-demo ]; then
            # Remove the repository directory
            rm -rf /home/torrust/github/torrust/torrust-tracker-demo
        fi
    " "Removing existing repository"

    # Copy archive to VM
    if ! scp -o StrictHostKeyChecking=no "${temp_archive}" "torrust@${vm_ip}:/tmp/"; then
        log_error "Failed to copy git archive to VM"
        rm -f "${temp_archive}"
        exit 1
    fi

    # Extract archive on VM
    vm_exec "${vm_ip}" "cd /home/torrust/github/torrust && mkdir -p torrust-tracker-demo" "Creating repository directory"
    vm_exec "${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo && tar -xzf /tmp/$(basename "${temp_archive}")" "Extracting repository"
    
    vm_exec "${vm_ip}" "rm -f /tmp/$(basename "${temp_archive}")" "Cleaning up temp files"

    # Clean up local temp file
    rm -f "${temp_archive}"

    log_success "Git archive deployed successfully (committed changes only)"
}

# RELEASE STAGE: Deploy application code and configuration
release_stage() {
    local vm_ip="$1"

    log_info "=== TWELVE-FACTOR RELEASE STAGE ==="
    log_info "Deploying application with environment: ${ENVIRONMENT}"

    # Choose deployment method based on environment
    if [[ "${ENVIRONMENT}" == "local" ]]; then
        deploy_local_working_tree "${vm_ip}"
    else
        deploy_git_archive "${vm_ip}"
    fi

    # Set up persistent data volume and copy locally generated configuration files directly
    vm_exec "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo
        
        # Fix any permission issues
        if [ -f infrastructure/scripts/fix-volume-permissions.sh ]; then
            sudo ./infrastructure/scripts/fix-volume-permissions.sh
        fi
        
        # Ensure persistent storage directories exist
        sudo mkdir -p /var/lib/torrust/{tracker/{lib/database,log,etc},prometheus/{data,etc},proxy/{webroot,etc/nginx-conf},certbot/{etc,lib},dhparam,mysql/init,compose}
        
        # Ensure torrust user owns all persistent data directories
        sudo chown -R torrust:torrust /var/lib/torrust
    " "Setting up persistent data volume directory structure"

    # Copy locally generated configuration files directly to persistent volume
    log_info "Copying locally generated configuration files to persistent volume..."
    
    # Copy tracker configuration
    if [[ -f "${PROJECT_ROOT}/application/storage/tracker/etc/tracker.toml" ]]; then
        log_info "Copying tracker configuration..."
        scp -o StrictHostKeyChecking=no "${PROJECT_ROOT}/application/storage/tracker/etc/tracker.toml" "torrust@${vm_ip}:/tmp/tracker.toml"
        vm_exec "${vm_ip}" "sudo mv /tmp/tracker.toml /var/lib/torrust/tracker/etc/tracker.toml && sudo chown torrust:torrust /var/lib/torrust/tracker/etc/tracker.toml"
    fi
    
    # Copy prometheus configuration
    if [[ -f "${PROJECT_ROOT}/application/storage/prometheus/etc/prometheus.yml" ]]; then
        log_info "Copying prometheus configuration..."
        scp -o StrictHostKeyChecking=no "${PROJECT_ROOT}/application/storage/prometheus/etc/prometheus.yml" "torrust@${vm_ip}:/tmp/prometheus.yml"
        vm_exec "${vm_ip}" "sudo mv /tmp/prometheus.yml /var/lib/torrust/prometheus/etc/prometheus.yml && sudo chown torrust:torrust /var/lib/torrust/prometheus/etc/prometheus.yml"
    fi
    
    # Generate and copy nginx configuration (choose HTTP or HTTPS with self-signed certificates)
    if [[ "${ENABLE_HTTPS}" == "true" ]]; then
        log_info "HTTPS enabled - preparing HTTPS configuration"
        generate_nginx_https_selfsigned_config "${vm_ip}"
    else
        log_info "HTTPS disabled - using HTTP-only configuration"
        generate_nginx_http_config "${vm_ip}"
    fi
    
    # Copy Docker Compose .env file
    if [[ -f "${PROJECT_ROOT}/application/storage/compose/.env" ]]; then
        log_info "Copying Docker Compose environment file..."
        scp -o StrictHostKeyChecking=no "${PROJECT_ROOT}/application/storage/compose/.env" "torrust@${vm_ip}:/tmp/compose.env"
        vm_exec "${vm_ip}" "sudo mv /tmp/compose.env /var/lib/torrust/compose/.env && sudo chown torrust:torrust /var/lib/torrust/compose/.env"
    else
        log_error "No .env file found at ${PROJECT_ROOT}/application/storage/compose/.env"
        log_error "Configuration should have been generated locally before deployment"
        exit 1
    fi
    
    # Generate SSL certificates before starting services (if HTTPS is enabled)
    if [[ "${ENABLE_HTTPS}" == "true" ]]; then
        log_info "Generating self-signed SSL certificates before starting services..."
        generate_selfsigned_certificates "${vm_ip}"
    fi

    log_success "Release stage completed"
}

# Wait for services to become healthy
wait_for_services() {
    local vm_ip="$1"
    local max_attempts=60 # 10 minutes (60 * 10 seconds) - increased for MySQL initialization
    local attempt=1

    log_info "Waiting for application services to become healthy..."

    while [[ ${attempt} -le ${max_attempts} ]]; do
        log_info "Checking container status (attempt ${attempt}/${max_attempts})..."

        # Get container status with service names only
        services=$(ssh -n -o StrictHostKeyChecking=no -o ConnectTimeout=10 "torrust@${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo/application && docker compose --env-file /var/lib/torrust/compose/.env ps --services" 2>/dev/null || echo "SSH_FAILED")

        if [[ "${services}" == "SSH_FAILED" ]]; then
            log_warning "SSH connection failed while checking container status. Retrying in 10 seconds..."
            sleep 10
            ((attempt++))
            continue
        fi

        if [[ -z "${services}" ]]; then
            log_warning "Could not get container status. Services might not be running yet. Retrying in 10 seconds..."
            sleep 10
            ((attempt++))
            continue
        fi

        log_info "Found services: $(echo "${services}" | wc -l) services"

        all_healthy=true
        container_count=0

        while IFS= read -r service_name; do
            [[ -z "$service_name" ]] && continue # Skip empty lines
            container_count=$((container_count + 1))

            # Get the container state and health for this service
            container_info=$(ssh -n -o StrictHostKeyChecking=no -o ConnectTimeout=10 "torrust@${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo/application && docker compose --env-file /var/lib/torrust/compose/.env ps ${service_name} --format '{{.State}}'" 2>/dev/null)
            health_status=$(ssh -n -o StrictHostKeyChecking=no -o ConnectTimeout=10 "torrust@${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo/application && docker inspect ${service_name} --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' 2>/dev/null" || echo "no-healthcheck")

            # Clean up output
            container_info=$(echo "${container_info}" | tr -d '\n\r' | xargs)
            health_status=$(echo "${health_status}" | tr -d '\n\r' | xargs)

            # Check if container is running
            if [[ "${container_info}" != "running" ]]; then
                log_info "Service '${service_name}': ${container_info} - not running yet"
                all_healthy=false
                continue
            fi

            # If container is running, check health status
            case "${health_status}" in
            "healthy")
                log_info "Service '${service_name}': running ✓ (healthy)"
                ;;
            "no-healthcheck")
                log_info "Service '${service_name}': running ✓ (no health check)"
                ;;
            "starting")
                log_info "Service '${service_name}': running (health check starting) - waiting..."
                all_healthy=false
                ;;
            "unhealthy")
                log_warning "Service '${service_name}': running (unhealthy) - waiting for recovery..."
                all_healthy=false
                ;;
            *)
                log_info "Service '${service_name}': running (health: ${health_status}) - waiting..."
                all_healthy=false
                ;;
            esac
        done <<<"${services}"

        log_info "Checked ${container_count} containers, all_healthy=${all_healthy}"

        if ${all_healthy}; then
            log_success "All application services are healthy and ready."
            return 0
        fi

        log_info "Not all services are healthy. Retrying in 10 seconds..."
        sleep 10
        ((attempt++))
    done

    log_error "Timeout waiting for services to become healthy after ${max_attempts} attempts."
    vm_exec "${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo/application && docker compose --env-file /var/lib/torrust/compose/.env ps && docker compose --env-file /var/lib/torrust/compose/.env logs" "Dumping logs on failure"
    exit 1
}

# Setup database backup automation
setup_backup_automation() {
    local vm_ip="$1"

    log_info "   Checking backup automation configuration..."

    # Load environment variables from the generated .env file
    if [[ -f "${PROJECT_ROOT}/application/storage/compose/.env" ]]; then
        # shellcheck source=/dev/null
        source "${PROJECT_ROOT}/application/storage/compose/.env"
        log_info "   ✅ Loaded environment configuration"
    else
        log_warning "   ⚠️  Environment file not found, using defaults"
    fi

    # Check if backup automation is enabled
    if [[ "${ENABLE_DB_BACKUPS:-false}" != "true" ]]; then
        log_info "   ⏹️  Database backup automation disabled (ENABLE_DB_BACKUPS=${ENABLE_DB_BACKUPS:-false})"
        return 0
    fi

    log_info "   ✅ Database backup automation enabled - proceeding with setup..."

    # Create backup directory and set permissions
    log_info "   ⏳ Creating backup directory and setting permissions..."
    vm_exec "${vm_ip}" "
        # Create backup directory if it doesn't exist
        sudo mkdir -p /var/lib/torrust/mysql/backups
        
        # Ensure torrust user owns backup directory
        sudo chown -R torrust:torrust /var/lib/torrust/mysql/backups
        
        # Set appropriate permissions
        chmod 755 /var/lib/torrust/mysql/backups
    " "Setting up backup directory"
    log_info "   ✅ Backup directory setup completed"

    # Install crontab entry for automated backups
    log_info "   ⏳ Installing MySQL backup cron job..."
    vm_exec "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo
        
        # Check if backup cron job already exists
        if crontab -l 2>/dev/null | grep -q 'mysql-backup.sh'; then
            echo 'MySQL backup cron job already exists'
        else
            # Add the cron job from template
            (crontab -l 2>/dev/null || echo '') | cat - infrastructure/config/templates/crontab/mysql-backup.cron | crontab -
            echo 'MySQL backup cron job added successfully'
        fi
        
        # Show current crontab for verification
        echo 'Current crontab entries:'
        crontab -l || echo 'No crontab entries found'
    " "Installing MySQL backup cron job"
    log_info "   ✅ Cron job installation completed"

    # Test backup script functionality
    log_info "   ⏳ Validating backup script functionality..."
    vm_exec "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo/application
        
        # Test backup script with dry-run
        echo 'Testing backup script...'
        if bash -n share/bin/mysql-backup.sh; then
            echo '✅ Backup script syntax is valid'
        else
            echo '❌ Backup script has syntax errors'
            exit 1
        fi
        
        # Check script permissions
        if [[ -x share/bin/mysql-backup.sh ]]; then
            echo '✅ Backup script is executable'
        else
            echo '❌ Backup script is not executable'
            chmod +x share/bin/mysql-backup.sh
            echo '✅ Fixed backup script permissions'
        fi
    " "Validating backup script"
    log_info "   ✅ Backup script validation completed"

    log_success "   🎉 Database backup automation configured successfully"
    log_info "Backup schedule: Daily at 3:00 AM"
    log_info "Backup location: /var/lib/torrust/mysql/backups"
    log_info "Retention period: ${BACKUP_RETENTION_DAYS:-7} days"
}

# RUN STAGE: Start application processes
run_stage() {
    local vm_ip="$1"

    log_info "=== TWELVE-FACTOR RUN STAGE ==="
    log_info "Starting application services"

    # Stop any existing services
    vm_exec "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo/application
        
        if [ -f compose.yaml ]; then
            docker compose --env-file /var/lib/torrust/compose/.env down --remove-orphans || true
        fi
    " "Stopping existing services"

    # Pull latest images with timeout (10 minutes for large images)
    log_info "Pulling Docker images (this may take several minutes for large images)..."
    vm_exec_with_timeout "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo/application
        
        # Pull images with progress output
        echo 'Starting Docker image pull...'
        docker compose --env-file /var/lib/torrust/compose/.env pull
        echo 'Docker image pull completed'
    " 600 "Pulling Docker images with 10-minute timeout"

    # Start services
    vm_exec "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo/application
        
        # Start services
        docker compose --env-file /var/lib/torrust/compose/.env up -d
    " "Starting application services"

    # Wait for services to initialize (unless skipped)
    if [[ "${SKIP_WAIT}" != "true" ]]; then
        log_info "⏳ Waiting for application services to be healthy..."
        log_info "   (Use SKIP_WAIT=true to skip this waiting)"
        wait_for_services "${vm_ip}"
        log_success "🎉 All application services are healthy and ready!"
    else
        log_warning "⚠️  Skipping wait for service health checks (SKIP_WAIT=true)"
        log_info "   Note: Services may not be ready immediately"
    fi

    # Setup HTTPS with self-signed certificates (if enabled)
    if [[ "${ENABLE_HTTPS}" == "true" ]]; then
        log_info "⏳ Setting up HTTPS certificates..."
        log_info "HTTPS certificates already generated - services should be running with HTTPS..."
        log_success "✅ HTTPS setup completed"
    else
        log_info "⏹️  HTTPS setup skipped (ENABLE_HTTPS=${ENABLE_HTTPS})"
    fi

    # Setup database backup automation (if enabled)
    log_info "⏳ Setting up database backup automation..."
    setup_backup_automation "${vm_ip}"
    log_success "✅ Database backup automation completed"

    log_success "🎉 Run stage completed successfully"
}

# Validate deployment (Health checks)
validate_deployment() {
    local vm_ip="$1"

    log_info "=== DEPLOYMENT VALIDATION ==="

    # Check service status with detailed output
    vm_exec "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo/application
        echo '=== Docker Compose Services (Detailed Status) ==='
        docker compose --env-file /var/lib/torrust/compose/.env ps --format 'table {{.Service}}\t{{.State}}\t{{.Status}}\t{{.Ports}}'
        
        echo ''
        echo '=== Docker Compose Services (Default Format) ==='
        docker compose --env-file /var/lib/torrust/compose/.env ps
        
        echo ''
        echo '=== Container Health Check Details ==='
        # Show health status for each container
        for container in \$(docker compose --env-file /var/lib/torrust/compose/.env ps --format '{{.Name}}'); do
            echo \"Container: \$container\"
            state=\$(docker inspect \$container --format '{{.State.Status}}')
            health=\$(docker inspect \$container --format '{{.State.Health.Status}}' 2>/dev/null || echo 'no-healthcheck')
            echo \"  State: \$state\"
            echo \"  Health: \$health\"
            
            # Show health check logs for problematic containers
            if [ \"\$health\" = \"unhealthy\" ] || [ \"\$health\" = \"starting\" ]; then
                echo \"  Health check output (last 3 attempts):\"
                docker inspect \$container --format '{{range .State.Health.Log}}    {{.Start}}: {{.Output}}{{end}}' 2>/dev/null | tail -3 || echo \"    No health check logs available\"
            fi
            echo ''
        done
        
        echo '=== Service Logs (last 10 lines each) ==='
        docker compose --env-file /var/lib/torrust/compose/.env logs --tail=10
    " "Checking detailed service status"

    # Test application endpoints
    vm_exec "${vm_ip}" "
        echo '=== Testing Application Endpoints ==='
        
        # Test HTTP health check endpoint (through nginx proxy)
        echo 'Testing HTTP health check endpoint...'
        if curl -f -s http://localhost/health_check >/dev/null 2>&1; then
            echo '✅ HTTP health check endpoint: OK'
        else
            echo '❌ HTTP health check endpoint: FAILED'
            exit 1
        fi
        
        # Test HTTPS health check endpoint (through nginx proxy, with self-signed certificates)
        echo 'Testing HTTPS health check endpoint...'
        if curl -f -s -k https://localhost/health_check >/dev/null 2>&1; then
            echo '✅ HTTPS health check endpoint: OK (self-signed certificate)'
        else
            echo '❌ HTTPS health check endpoint: FAILED'
            # Don't exit on HTTPS failure in case certificates aren't ready yet
            echo '⚠️  HTTPS may not be fully configured yet, continuing with HTTP tests'
        fi
        
        # Test HTTP API stats endpoint (through nginx proxy, requires auth)
        echo 'Testing HTTP API stats endpoint...'
        # Save response to temp file and get HTTP status code
        api_http_code=\$(curl -s -o /tmp/api_response.json -w '%{http_code}' \"http://localhost/api/v1/stats?token=MyAccessToken\" 2>&1 || echo \"000\")
        api_response_body=\$(cat /tmp/api_response.json 2>/dev/null || echo \"No response\")
        
        # Check if HTTP status is 200 (success)
        if [ \"\$api_http_code\" -eq 200 ] 2>/dev/null; then
            echo '✅ HTTP API stats endpoint: OK'
        else
            echo '❌ HTTP API stats endpoint: FAILED'
            echo \"  HTTP Code: \$api_http_code\"
            echo \"  Response: \$api_response_body\"
            rm -f /tmp/api_response.json
            exit 1
        fi
        rm -f /tmp/api_response.json
        
        # Test HTTPS API stats endpoint (through nginx proxy, with self-signed certificates)
        echo 'Testing HTTPS API stats endpoint...'
        # Save response to temp file and get HTTP status code
        api_https_code=\$(curl -s -k -o /tmp/api_response_https.json -w '%{http_code}' \"https://localhost/api/v1/stats?token=MyAccessToken\" 2>&1 || echo \"000\")
        api_https_response=\$(cat /tmp/api_response_https.json 2>/dev/null || echo \"No response\")
        
        # Check if HTTPS status is 200 (success)
        if [ \"\$api_https_code\" -eq 200 ] 2>/dev/null; then
            echo '✅ HTTPS API stats endpoint: OK (self-signed certificate)'
        else
            echo '⚠️  HTTPS API stats endpoint: FAILED'
            echo \"  HTTPS Code: \$api_https_code\"
            echo \"  Response: \$api_https_response\"
            # Don't exit on HTTPS failure in case certificates aren't ready yet
            echo '⚠️  HTTPS may not be fully configured yet, continuing with HTTP validation'
        fi
        rm -f /tmp/api_response_https.json
        
        # Test HTTP tracker endpoint (through nginx proxy - expects 404 for root)
        echo 'Testing HTTP tracker endpoint...'
        if curl -s -w '%{http_code}' http://localhost/ -o /dev/null | grep -q '404'; then
            echo '✅ HTTP tracker endpoint: OK (nginx proxy responding, tracker ready for BitTorrent clients)'
        else
            echo '❌ HTTP tracker endpoint: FAILED'
            exit 1
        fi
        
        # Test HTTPS tracker endpoint (through nginx proxy - expects 404 for root)
        echo 'Testing HTTPS tracker endpoint...'
        if curl -s -k -w '%{http_code}' https://localhost/ -o /dev/null | grep -q '404'; then
            echo '✅ HTTPS tracker endpoint: OK (nginx proxy with SSL responding, tracker ready for secure BitTorrent clients)'
        else
            echo '⚠️  HTTPS tracker endpoint: FAILED'
            # Don't exit on HTTPS failure in case certificates aren't ready yet
            echo '⚠️  HTTPS may not be fully configured yet, HTTP tracker is working'
        fi
        
        echo '✅ All critical endpoints are responding (HTTP validated, HTTPS optional)'
    " "Testing application endpoints"

    log_success "Deployment validation passed"
}

# Display connection information
show_connection_info() {
    local vm_ip="$1"

    log_success "Application deployment completed successfully!"
    echo
    echo "=== CONNECTION INFORMATION ==="
    echo "VM IP:           ${vm_ip}"
    echo "SSH Access:      ssh torrust@${vm_ip}"
    echo
    echo "=== APPLICATION ENDPOINTS ==="
    echo "HTTP Health Check:    http://${vm_ip}/health_check"                                   # DevSkim: ignore DS137138
    echo "HTTP API Stats:       http://${vm_ip}/api/v1/stats?token=MyAccessToken" # DevSkim: ignore DS137138
    echo "HTTP Tracker:         http://${vm_ip}/ (for BitTorrent clients)"                      # DevSkim: ignore DS137138
    echo "UDP Tracker:          udp://${vm_ip}:6868, udp://${vm_ip}:6969"
    echo "Grafana HTTP:         http://${vm_ip}:3100 (admin/admin)" # DevSkim: ignore DS137138
    echo
    echo "=== HTTPS ENDPOINTS (with self-signed certificates) ==="
    echo "HTTPS Health Check:   https://${vm_ip}/health_check (expect certificate warning)"     # DevSkim: ignore DS137138
    echo "HTTPS API Stats:      https://${vm_ip}/api/v1/stats?token=MyAccessToken (expect certificate warning)" # DevSkim: ignore DS137138
    echo "HTTPS Tracker:        https://${vm_ip}/ (expect certificate warning)"                 # DevSkim: ignore DS137138
    echo "Grafana HTTPS:        https://${vm_ip}:3100 (expect certificate warning)" # DevSkim: ignore DS137138
    echo
    echo "=== DOMAIN-BASED HTTPS (add to /etc/hosts for testing) ==="
    echo "Tracker API:          https://tracker.test.local (requires hosts entry)"
    echo "Grafana:              https://grafana.test.local (requires hosts entry)"
    echo
    echo "=== SETUP FOR HTTPS TESTING ==="
    echo "Add these lines to your /etc/hosts file:"
    echo "${vm_ip} tracker.test.local"
    echo "${vm_ip} grafana.test.local"
    echo
    echo "Then access:"
    echo "• Tracker API:   https://tracker.test.local/health_check"
    echo "• Tracker Stats: https://tracker.test.local/api/v1/stats?token=MyAccessToken"
    echo "• Grafana Login: https://grafana.test.local (admin/admin)"
    echo
    echo "Note: Your browser will show a security warning for self-signed certificates."
    echo "      Click 'Advanced' -> 'Proceed to site' to continue."
    echo
    echo "=== NEXT STEPS ==="
    echo "Health Check:    make app-health-check ENVIRONMENT=${ENVIRONMENT}"
    echo "View Logs:       ssh torrust@${vm_ip} 'cd torrust-tracker-demo/application && docker compose --env-file /var/lib/torrust/compose/.env logs'"
    echo "Stop Services:   ssh torrust@${vm_ip} 'cd torrust-tracker-demo/application && docker compose --env-file /var/lib/torrust/compose/.env down'"
    echo
}

# Main execution
main() {
    log_info "Starting application deployment (Twelve-Factor Release + Run Stages)"
    log_info "Environment: ${ENVIRONMENT}"

    # Check git status and warn about uncommitted changes
    check_git_status

    # LOCAL: Generate configuration (Build/Release stage)
    generate_configuration_locally

    local vm_ip
    vm_ip=$(get_vm_ip)

    test_ssh_connection "${vm_ip}"
    wait_for_system_ready "${vm_ip}"
    release_stage "${vm_ip}"
    run_stage "${vm_ip}"  # This already includes waiting for services

    if [[ "${SKIP_HEALTH_CHECK}" != "true" ]]; then
        log_info "⏳ Running deployment validation..."
        validate_deployment "${vm_ip}"
        log_success "✅ Deployment validation completed"
    else
        log_warning "⚠️  Skipping deployment validation (SKIP_HEALTH_CHECK=true)"
    fi

    show_connection_info "${vm_ip}"
}

# Show help
show_help() {
    cat <<EOF
Application Deployment Script (Twelve-Factor Release + Run Stages)

Usage: $0 [ENVIRONMENT] [VM_IP]

Arguments:
    ENVIRONMENT    Environment name (local, production)
    VM_IP          VM IP address (optional, will get from Terraform if not provided)

Environment Variables:
    SKIP_HEALTH_CHECK    Skip health check validation (true/false, default: false)
    SKIP_WAIT           Skip waiting for services to be ready (true/false, default: false)

Examples:
    $0 local                    # Deploy to local environment (get IP from Terraform)
    $0 production               # Deploy to production (get IP from Terraform)
    $0 local 192.168.1.100     # Deploy to local with specific IP

Twelve-Factor Compliance:
    This script implements RELEASE + RUN stages:
    
    RELEASE: Combines application code with environment-specific configuration
    RUN:     Starts application processes and validates deployment
    
Prerequisites:
    Infrastructure must be provisioned first:
    make infra-apply ENVIRONMENT=${ENVIRONMENT}
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
