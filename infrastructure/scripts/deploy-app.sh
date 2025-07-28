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
ENVIRONMENT="${1:-l            container_info=$(ssh -n -o StrictHostKeyChecking=no -o ConnectTimeout=10 "torrust@${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo/application && docker compose --env-file /var/lib/torrust/application/.env ps ${service_name} --format '{{.State}}'" 2>/dev/null)cal}"
VM_IP="${2:-}"
SKIP_HEALTH_CHECK="${SKIP_HEALTH_CHECK:-false}"

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
        log_warning "IMPORTANT: Deployment uses 'git archive' which only includes committed files."
        log_warning "Your uncommitted changes will NOT be deployed to the VM."
        log_warning ""
        log_warning "To include these changes in deployment:"
        log_warning "  1. git add infrastructure/config/environments/"
        log_warning "  2. git commit -m 'update: configuration templates'"
        log_warning "  3. Re-run deployment"
        log_warning ""
        log_warning "To continue without committing (deployment will use last committed version):"
        log_warning "  Press ENTER to continue or Ctrl+C to abort"
        log_warning "==============================================="
        read -r
    fi
    
    # Check for any other uncommitted changes (informational)
    local all_changes
    all_changes=$(git status --porcelain 2>/dev/null | wc -l)
    
    if [[ "${all_changes}" -gt 0 ]]; then
        local git_status
        git_status=$(git status --short 2>/dev/null || echo "")
        log_info "Repository has ${all_changes} uncommitted changes (git archive will use committed version)"
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

# RELEASE STAGE: Deploy application code and configuration
release_stage() {
    local vm_ip="$1"

    log_info "=== TWELVE-FACTOR RELEASE STAGE ==="
    log_info "Deploying application with environment: ${ENVIRONMENT}"

    # Deploy local repository using git archive (testing local changes)
    log_info "Creating git archive of local repository..."
    local temp_archive
    temp_archive="/tmp/torrust-tracker-demo-$(date +%s).tar.gz"

    cd "${PROJECT_ROOT}"
    if ! git archive --format=tar.gz --output="${temp_archive}" HEAD; then
        log_error "Failed to create git archive"
        exit 1
    fi

    log_info "Copying local repository to VM..."

    # Create target directory structure
    vm_exec "${vm_ip}" "mkdir -p /home/torrust/github/torrust" "Creating directory structure"

    # Check if we need to preserve storage before removing repository
    storage_exists=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "torrust@${vm_ip}" "
        if [ -d /home/torrust/github/torrust/torrust-tracker-demo/application/storage ]; then
            echo 'true'
        else
            echo 'false'
        fi
    " 2>/dev/null || echo "false")

    if [[ "${storage_exists}" == "true" ]]; then
        log_warning "Preserving existing storage folder with persistent data"
    fi

    # Handle existing repository - preserve storage folder if it exists
    vm_exec "${vm_ip}" "
        if [ -d /home/torrust/github/torrust/torrust-tracker-demo ]; then
            if [ -d /home/torrust/github/torrust/torrust-tracker-demo/application/storage ]; then
                # Move storage folder to temporary location
                mv /home/torrust/github/torrust/torrust-tracker-demo/application/storage /tmp/torrust-storage-backup-\$(date +%s) || true
            fi
            
            # Remove the repository directory (excluding storage)
            rm -rf /home/torrust/github/torrust/torrust-tracker-demo
        fi
    " "Removing existing repository (preserving storage)"

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

    # Restore storage folder if it was backed up
    vm_exec "${vm_ip}" "
        storage_backup=\$(ls /tmp/torrust-storage-backup-* 2>/dev/null | head -1 || echo '')
        if [ -n \"\$storage_backup\" ] && [ -d \"\$storage_backup\" ]; then
            rm -rf /home/torrust/github/torrust/torrust-tracker-demo/application/storage
            mv \"\$storage_backup\" /home/torrust/github/torrust/torrust-tracker-demo/application/storage
        fi
    " "Restoring preserved storage folder"

    # Check if storage was restored and log appropriately
    storage_restored=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "torrust@${vm_ip}" "
        if [ -d /home/torrust/github/torrust/torrust-tracker-demo/application/storage/mysql ] || [ -d /home/torrust/github/torrust/torrust-tracker-demo/application/storage/tracker ]; then
            echo 'true'
        else
            echo 'false'
        fi
    " 2>/dev/null || echo "false")

    if [[ "${storage_restored}" == "true" ]]; then
        log_info "Storage folder restored with existing persistent data"
    fi

    # Clean up local temp file
    rm -f "${temp_archive}"

    # Verify deployment
    vm_exec "${vm_ip}" "test -f /home/torrust/github/torrust/torrust-tracker-demo/Makefile" "Verifying repository deployment"

    log_success "Local repository deployed successfully"

    # Process configuration (Release stage - combining code with config)
    vm_exec "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo
        
        if [ -f infrastructure/scripts/configure-env.sh ]; then
            ./infrastructure/scripts/configure-env.sh ${ENVIRONMENT}
        else
            echo 'Configuration script not found, using defaults'
        fi
    " "Processing configuration for environment: ${ENVIRONMENT}"

    # Set up persistent data volume and directory structure
    vm_exec "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo
        
        # Fix any permission issues
        if [ -f infrastructure/scripts/fix-volume-permissions.sh ]; then
            sudo ./infrastructure/scripts/fix-volume-permissions.sh
        fi
        
        # Ensure persistent storage directories exist
        sudo mkdir -p /var/lib/torrust/{tracker/{lib/database,log,etc},prometheus/{data,etc},proxy/{webroot,etc/nginx-conf},certbot/{etc,lib},dhparam,mysql/init,application}
        
        # Copy .env file to persistent storage if it doesn't exist
        if [ -f application/.env ] && [ ! -f /var/lib/torrust/application/.env ]; then
            sudo cp application/.env /var/lib/torrust/application/.env
        elif [ ! -f /var/lib/torrust/application/.env ]; then
            # Create default .env from template if none exists
            if [ -f .env.production ]; then
                sudo cp .env.production /var/lib/torrust/application/.env
            fi
        fi
        
        # Copy generated configuration files to persistent storage
        # These files are generated by configure-env.sh and need to be in the persistent volume
        if [ -f application/storage/tracker/etc/tracker.toml ]; then
            sudo cp application/storage/tracker/etc/tracker.toml /var/lib/torrust/tracker/etc/
        fi
        if [ -f application/storage/prometheus/etc/prometheus.yml ]; then
            sudo cp application/storage/prometheus/etc/prometheus.yml /var/lib/torrust/prometheus/etc/
        fi
        if [ -f application/storage/proxy/etc/nginx-conf/nginx.conf ]; then
            sudo cp application/storage/proxy/etc/nginx-conf/nginx.conf /var/lib/torrust/proxy/etc/nginx-conf/
        fi
        
        # Ensure torrust user owns all persistent data
        sudo chown -R torrust:torrust /var/lib/torrust
    " "Setting up persistent data volume directory structure"

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
        services=$(ssh -n -o StrictHostKeyChecking=no -o ConnectTimeout=10 "torrust@${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo/application && docker compose --env-file /var/lib/torrust/application/.env ps --services" 2>/dev/null || echo "SSH_FAILED")

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
            container_info=$(ssh -n -o StrictHostKeyChecking=no -o ConnectTimeout=10 "torrust@${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo/application && docker compose --env-file /var/lib/torrust/application/.env ps ${service_name} --format '{{.State}}'" 2>/dev/null)
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
    vm_exec "${vm_ip}" "cd /home/torrust/github/torrust/torrust-tracker-demo/application && docker compose --env-file /var/lib/torrust/application/.env ps && docker compose --env-file /var/lib/torrust/application/.env logs" "Dumping logs on failure"
    exit 1
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
            docker compose --env-file /var/lib/torrust/application/.env down --remove-orphans || true
        fi
    " "Stopping existing services"

    # Pull latest images with timeout (10 minutes for large images)
    log_info "Pulling Docker images (this may take several minutes for large images)..."
    vm_exec_with_timeout "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo/application
        
        # Pull images with progress output
        echo 'Starting Docker image pull...'
        docker compose --env-file /var/lib/torrust/application/.env pull
        echo 'Docker image pull completed'
    " 600 "Pulling Docker images with 10-minute timeout"

    # Start services
    vm_exec "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo/application
        
        # Start services
        docker compose --env-file /var/lib/torrust/application/.env up -d
    " "Starting application services"

    # Wait for services to initialize
    wait_for_services "${vm_ip}"

    log_success "Run stage completed"
}

# Validate deployment (Health checks)
validate_deployment() {
    local vm_ip="$1"

    log_info "=== DEPLOYMENT VALIDATION ==="

    # Check service status with detailed output
    vm_exec "${vm_ip}" "
        cd /home/torrust/github/torrust/torrust-tracker-demo/application
        echo '=== Docker Compose Services (Detailed Status) ==='
        docker compose --env-file /var/lib/torrust/application/.env ps --format 'table {{.Service}}\t{{.State}}\t{{.Status}}\t{{.Ports}}'
        
        echo ''
        echo '=== Docker Compose Services (Default Format) ==='
        docker compose --env-file /var/lib/torrust/application/.env ps
        
        echo ''
        echo '=== Container Health Check Details ==='
        # Show health status for each container
        for container in \$(docker compose --env-file /var/lib/torrust/application/.env ps --format '{{.Name}}'); do
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
        docker compose --env-file /var/lib/torrust/application/.env logs --tail=10
    " "Checking detailed service status"

    # Test application endpoints
    vm_exec "${vm_ip}" "
        echo '=== Testing Application Endpoints ==='
        
        # Test global health check endpoint (through nginx proxy)
        if curl -f -s http://localhost/health_check >/dev/null 2>&1; then
            echo '✅ Global health check endpoint: OK'
        else
            echo '❌ Global health check endpoint: FAILED'
            exit 1
        fi
        
        # Test API stats endpoint (through nginx proxy, requires auth)
        # Save response to temp file and get HTTP status code
        api_http_code=\$(curl -s -o /tmp/api_response.json -w '%{http_code}' \"http://localhost/api/v1/stats?token=MyAccessToken\" 2>&1 || echo \"000\")
        api_response_body=\$(cat /tmp/api_response.json 2>/dev/null || echo \"No response\")
        
        # Check if HTTP status is 200 (success)
        if [ \"\$api_http_code\" -eq 200 ] 2>/dev/null; then
            echo '✅ API stats endpoint: OK'
        else
            echo '❌ API stats endpoint: FAILED'
            echo \"  HTTP Code: \$api_http_code\"
            echo \"  Response: \$api_response_body\"
            rm -f /tmp/api_response.json
            exit 1
        fi
        rm -f /tmp/api_response.json
        
        # Test HTTP tracker endpoint (through nginx proxy - expects 404 for root)
        if curl -s -w '%{http_code}' http://localhost/ -o /dev/null | grep -q '404'; then
            echo '✅ HTTP tracker endpoint: OK (nginx proxy responding, tracker ready for BitTorrent clients)'
        else
            echo '❌ HTTP tracker endpoint: FAILED'
            exit 1
        fi
        
        echo '✅ All endpoints are responding'
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
    echo "Health Check:    http://${vm_ip}/health_check"                                   # DevSkim: ignore DS137138
    echo "API Stats:       http://${vm_ip}/api/v1/stats?token=MyAccessToken" # DevSkim: ignore DS137138
    echo "HTTP Tracker:    http://${vm_ip}/ (for BitTorrent clients)"                      # DevSkim: ignore DS137138
    echo "UDP Tracker:     udp://${vm_ip}:6868, udp://${vm_ip}:6969"
    echo "Grafana:         http://${vm_ip}:3100 (admin/admin)" # DevSkim: ignore DS137138
    echo
    echo "=== NEXT STEPS ==="
    echo "Health Check:    make app-health-check ENVIRONMENT=${ENVIRONMENT}"
    echo "View Logs:       ssh torrust@${vm_ip} 'cd torrust-tracker-demo/application && docker compose --env-file /var/lib/torrust/application/.env logs'"
    echo "Stop Services:   ssh torrust@${vm_ip} 'cd torrust-tracker-demo/application && docker compose --env-file /var/lib/torrust/application/.env down'"
    echo
}

# Main execution
main() {
    log_info "Starting application deployment (Twelve-Factor Release + Run Stages)"
    log_info "Environment: ${ENVIRONMENT}"

    # Check git status and warn about uncommitted changes
    check_git_status

    local vm_ip
    vm_ip=$(get_vm_ip)

    test_ssh_connection "${vm_ip}"
    wait_for_system_ready "${vm_ip}"
    release_stage "${vm_ip}"
    run_stage "${vm_ip}"

    if [[ "${SKIP_HEALTH_CHECK}" != "true" ]]; then
        validate_deployment "${vm_ip}"
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
