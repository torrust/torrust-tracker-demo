# Makefile for Torrust Tracker Demo - Twelve-Factor App Deployment
.PHONY: help install-deps lint test clean
.PHONY: infra-init infra-plan infra-apply infra-destroy infra-status infra-refresh-state
.PHONY: app-deploy app-redeploy health-check
.PHONY: ssh console vm-console
.PHONY: configure-local configure-production validate-config

# Default variables
VM_NAME ?= torrust-tracker-demo
ENVIRONMENT ?= local
TERRAFORM_DIR = infrastructure/terraform
INFRA_TESTS_DIR = infrastructure/tests
TESTS_DIR = tests
SCRIPTS_DIR = infrastructure/scripts

# Help target
help: ## Show this help message
	@echo "Torrust Tracker Demo - Twelve-Factor App Deployment"
	@echo ""
	@echo "=== TWELVE-FACTOR DEPLOYMENT WORKFLOW ==="
	@echo "  1. infra-apply     - Provision infrastructure (platform setup)"
	@echo "  2. app-deploy      - Deploy application (Build + Release + Run stages)"
	@echo "  3. health-check    - Validate deployment"
	@echo ""
	@echo "=== TESTING WORKFLOW ==="
	@echo "  1. test-syntax     - Fast syntax validation (30s)"
	@echo "  2. test-unit       - Unit tests without deployment (1-2min)" 
	@echo "  3. test-ci         - CI-compatible tests (syntax + config + scripts)"
	@echo "  4. test-local      - Local-only tests (requires virtualization)"
	@echo "  5. test            - Full E2E test with deployment (5-8min)"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Examples:"
	@echo "  make infra-apply ENVIRONMENT=local"
	@echo "  make app-deploy ENVIRONMENT=local"
	@echo "  make health-check ENVIRONMENT=local"

install-deps: ## Install required dependencies (Ubuntu/Debian)
	@echo "Installing dependencies..."
	sudo apt update
	sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager virt-viewer genisoimage
	sudo usermod -aG libvirt $$USER
	sudo usermod -aG kvm $$USER
	@echo "Dependencies installed. Please log out and log back in for group changes to take effect."

# =============================================================================
# INFRASTRUCTURE PROVISIONING TARGETS (PLATFORM SETUP)
# =============================================================================

infra-init: ## Initialize infrastructure (Terraform init)
	@echo "Initializing infrastructure for $(ENVIRONMENT)..."
	$(SCRIPTS_DIR)/provision-infrastructure.sh $(ENVIRONMENT) init

infra-plan: ## Plan infrastructure changes
	@echo "Planning infrastructure for $(ENVIRONMENT)..."
	$(SCRIPTS_DIR)/provision-infrastructure.sh $(ENVIRONMENT) plan

infra-apply: ## Provision infrastructure (platform setup)
	@echo "Provisioning infrastructure for $(ENVIRONMENT)..."
	@echo "⚠️  This command may prompt for your password for sudo operations"
	$(SCRIPTS_DIR)/provision-infrastructure.sh $(ENVIRONMENT) apply

infra-destroy: ## Destroy infrastructure
	@echo "Destroying infrastructure for $(ENVIRONMENT)..."
	$(SCRIPTS_DIR)/provision-infrastructure.sh $(ENVIRONMENT) destroy

infra-status: ## Show infrastructure status
	@echo "Infrastructure status for $(ENVIRONMENT):"
	@cd $(TERRAFORM_DIR) && tofu show -no-color | grep -E "(vm_ip|vm_status)" || echo "No infrastructure found"

infra-refresh-state: ## Refresh Terraform state to detect IP changes
	@echo "Refreshing Terraform state..."
	@cd $(TERRAFORM_DIR) && tofu refresh

# =============================================================================
# TWELVE-FACTOR APPLICATION TARGETS (BUILD + RELEASE + RUN STAGES)
# =============================================================================

app-deploy: ## Deploy application (Twelve-Factor Build + Release + Run stages)
	@echo "Deploying application for $(ENVIRONMENT)..."
	$(SCRIPTS_DIR)/deploy-app.sh $(ENVIRONMENT)

app-redeploy: ## Redeploy application without infrastructure changes
	@echo "Redeploying application for $(ENVIRONMENT)..."
	$(SCRIPTS_DIR)/deploy-app.sh $(ENVIRONMENT)

health-check: ## Validate deployment health
	@echo "Running health check for $(ENVIRONMENT)..."
	$(SCRIPTS_DIR)/health-check.sh $(ENVIRONMENT)

# =============================================================================
# VM ACCESS AND DEBUGGING
# =============================================================================

ssh: ## SSH into the VM
	@VM_IP=$$(cd $(TERRAFORM_DIR) && tofu output -raw vm_ip 2>/dev/null) && \
	if [ -n "$$VM_IP" ] && [ "$$VM_IP" != "No IP assigned yet" ]; then \
		echo "Connecting to VM: $$VM_IP"; \
		ssh -o StrictHostKeyChecking=no torrust@$$VM_IP; \
	else \
		echo "Error: VM IP not available. Run 'make infra-status' to check infrastructure."; \
		exit 1; \
	fi

ssh-clean: ## Clean SSH known_hosts for VM (fixes host key verification warnings)
	@echo "Cleaning SSH known_hosts for VM..."
	@$(SCRIPTS_DIR)/ssh-utils.sh clean

ssh-prepare: ## Clean SSH known_hosts and test connectivity  
	@echo "Preparing SSH connection to VM..."
	@$(SCRIPTS_DIR)/ssh-utils.sh prepare

console: ## Access VM console (text-based)
	@echo "Accessing VM console..."
	@virsh console $(VM_NAME) || echo "VM console not accessible. Try 'make vm-console' for graphical console."

vm-console: ## Access VM graphical console (requires GUI)
	@echo "Opening graphical VM console..."
	@virt-viewer --connect qemu:///system $(VM_NAME) &

# =============================================================================
# CONFIGURATION MANAGEMENT
# =============================================================================

configure-local: ## Generate local environment configuration
	@echo "Configuring local environment..."
	$(SCRIPTS_DIR)/configure-env.sh local

configure-production: ## Generate production environment configuration
	@echo "Configuring production environment..."
	$(SCRIPTS_DIR)/configure-env.sh production

validate-config: ## Validate configuration for all environments
	@echo "Validating configuration..."
	$(SCRIPTS_DIR)/validate-config.sh

# =============================================================================
# TESTING AND QUALITY ASSURANCE
# =============================================================================

test-prereq: ## Test system prerequisites for development
	@echo "Testing prerequisites..."
	$(INFRA_TESTS_DIR)/test-unit-infrastructure.sh vm-prereq

test: ## Run comprehensive end-to-end test (follows integration guide)
	@echo "Running comprehensive end-to-end test..."
	$(TESTS_DIR)/test-e2e.sh $(ENVIRONMENT)

test-unit: ## Run unit tests (configuration, scripts, syntax)
	@echo "Running unit tests..."
	@echo "1. Configuration and syntax validation..."
	$(INFRA_TESTS_DIR)/test-unit-config.sh
	@echo "2. Infrastructure scripts validation..."
	$(INFRA_TESTS_DIR)/test-unit-scripts.sh

test-syntax: ## Run syntax validation only
	@echo "Running syntax validation..."
	./scripts/lint.sh

test-ci: ## Run CI-compatible tests (syntax + config + scripts)
	@echo "Running CI-compatible tests..."
	$(INFRA_TESTS_DIR)/test-ci.sh

test-local: ## Run local-only tests (requires virtualization)
	@echo "Running local-only tests..."
	$(INFRA_TESTS_DIR)/test-local.sh

test-legacy: ## [DEPRECATED] Legacy test scripts have been removed
	@echo "⚠️  DEPRECATED: Legacy test scripts have been removed"
	@echo "Use 'make test-unit' for unit tests or 'make test' for E2E tests"
	@exit 1

lint: test-syntax ## Run all linting (alias for test-syntax)

clean: ## Clean up temporary files and caches
	@echo "Cleaning up..."
	@rm -rf $(TERRAFORM_DIR)/.terraform
	@rm -f $(TERRAFORM_DIR)/terraform.tfstate.backup
	@echo "Clean completed"

# =============================================================================
# LEGACY COMPATIBILITY (DEPRECATED)
# =============================================================================

# These targets are maintained for backward compatibility but are deprecated
# Use the twelve-factor targets above instead

init: infra-init ## [DEPRECATED] Use infra-init instead
	@echo "⚠️  DEPRECATED: Use 'make infra-init' instead"

plan: infra-plan ## [DEPRECATED] Use infra-plan instead  
	@echo "⚠️  DEPRECATED: Use 'make infra-plan' instead"

apply: ## [DEPRECATED] Use infra-apply + app-deploy instead
	@echo "⚠️  DEPRECATED: This target combines infrastructure and application deployment"
	@echo "   For twelve-factor compliance, use:"
	@echo "   1. make infra-apply ENVIRONMENT=$(ENVIRONMENT)"
	@echo "   2. make app-deploy ENVIRONMENT=$(ENVIRONMENT)"
	@echo ""
	@echo "Proceeding with legacy deployment..."
	@make infra-apply ENVIRONMENT=$(ENVIRONMENT)
	@make app-deploy ENVIRONMENT=$(ENVIRONMENT)

destroy: infra-destroy ## [DEPRECATED] Use infra-destroy instead
	@echo "⚠️  DEPRECATED: Use 'make infra-destroy' instead"

status: infra-status ## [DEPRECATED] Use infra-status instead
	@echo "⚠️  DEPRECATED: Use 'make infra-status' instead"

refresh-state: infra-refresh-state ## [DEPRECATED] Use infra-refresh-state instead
	@echo "⚠️  DEPRECATED: Use 'make infra-refresh-state' instead"
