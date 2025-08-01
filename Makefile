# Makefile for Torrust Tracker Demo - Twelve-Factor App Deployment
.PHONY: help install-deps test-e2e lint test-unit clean
.PHONY: infra-init infra-plan infra-apply infra-destroy infra-status infra-refresh-state
.PHONY: infra-config-development infra-config-production infra-validate-config
.PHONY: infra-test-prereq infra-test-ci infra-test-local
.PHONY: infra-providers infra-environments provider-info
.PHONY: app-deploy app-redeploy app-health-check
.PHONY: app-test-config app-test-containers app-test-services
.PHONY: vm-ssh vm-console vm-gui-console vm-clean-ssh vm-prepare-ssh vm-status
.PHONY: dev-setup dev-deploy dev-test dev-clean

# Default variables
VM_NAME ?= torrust-tracker-demo
# Default values
ENVIRONMENT ?= development
PROVIDER ?= libvirt
TERRAFORM_DIR = infrastructure/terraform
INFRA_TESTS_DIR = infrastructure/tests
TESTS_DIR = tests
SCRIPTS_DIR = infrastructure/scripts

# Parameter validation for infrastructure commands
check-infra-params:
	@if [ -z "$(ENVIRONMENT)" ]; then \
		echo "❌ Error: ENVIRONMENT not specified"; \
		echo "Usage: make <target> ENVIRONMENT=<env> PROVIDER=<provider>"; \
		echo "Available environments: development, staging, production"; \
		exit 1; \
	fi
	@if [ -z "$(PROVIDER)" ]; then \
		echo "❌ Error: PROVIDER not specified"; \
		echo "Usage: make <target> ENVIRONMENT=<env> PROVIDER=<provider>"; \
		echo "Available providers: libvirt, hetzner"; \
		exit 1; \
	fi

# Help target
help: ## Show this help message
	@echo "Torrust Tracker Demo - Twelve-Factor App Deployment"
	@echo ""
	@echo "🚀 QUICK DEVELOPMENT WORKFLOWS:"
	@echo "  dev-setup          Complete development setup"
	@echo "  dev-deploy         Full deployment workflow (infra + app)"
	@echo "  dev-test           Quick validation (syntax + unit tests)"
	@echo "  dev-clean          Complete cleanup"
	@echo ""
	@echo "📋 INFRASTRUCTURE LAYER:"
	@awk 'BEGIN {FS = ":.*?## "} /^infra-.*:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "🐳 APPLICATION LAYER:"
	@awk 'BEGIN {FS = ":.*?## "} /^app-.*:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "🖥️  VM ACCESS:"
	@awk 'BEGIN {FS = ":.*?## "} /^vm-.*:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "🧪 TESTING (3-LAYER ARCHITECTURE):"
	@awk 'BEGIN {FS = ":.*?## "} /^test.*:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@awk 'BEGIN {FS = ":.*?## "} /^infra-test.*:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@awk 'BEGIN {FS = ":.*?## "} /^app-test.*:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "⚙️  SYSTEM SETUP:"
	@awk 'BEGIN {FS = ":.*?## "} /^(install-deps|clean).*:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
		@echo "Development examples:"
	@echo "  make dev-deploy ENVIRONMENT=development PROVIDER=libvirt"
	@echo "  make infra-apply ENVIRONMENT=development PROVIDER=libvirt"
	@echo "  make app-deploy ENVIRONMENT=development"

install-deps: ## Install required dependencies (Ubuntu/Debian)
	@echo "Installing dependencies..."
	sudo apt update
	sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager virt-viewer genisoimage
	sudo usermod -aG libvirt $$USER
	sudo usermod -aG kvm $$USER
	@echo "Dependencies installed. Please log out and log back in for group changes to take effect."

# =============================================================================
# INFRASTRUCTURE LAYER (PLATFORM SETUP & CONFIGURATION)
# =============================================================================

infra-init: check-infra-params ## Initialize infrastructure (Terraform init)
	@echo "Initializing infrastructure for $(ENVIRONMENT) on $(PROVIDER)..."
	$(SCRIPTS_DIR)/provision-infrastructure.sh $(ENVIRONMENT) $(PROVIDER) init

infra-plan: check-infra-params ## Plan infrastructure changes
	@echo "Planning infrastructure for $(ENVIRONMENT) on $(PROVIDER)..."
	$(SCRIPTS_DIR)/provision-infrastructure.sh $(ENVIRONMENT) $(PROVIDER) plan

infra-apply: check-infra-params ## Provision infrastructure (platform setup)
	@echo "Provisioning infrastructure for $(ENVIRONMENT) on $(PROVIDER)..."
	@echo "⚠️  This command may prompt for your password for sudo operations"
	@if [ "$(SKIP_WAIT)" = "true" ]; then \
		echo "⚠️  SKIP_WAIT=true - Infrastructure will not wait for full readiness"; \
	else \
		echo "ℹ️  Infrastructure will wait for full readiness (use SKIP_WAIT=true to skip)"; \
	fi
	SKIP_WAIT=$(SKIP_WAIT) $(SCRIPTS_DIR)/provision-infrastructure.sh $(ENVIRONMENT) $(PROVIDER) apply

infra-destroy: check-infra-params ## Destroy infrastructure
	@echo "Destroying infrastructure for $(ENVIRONMENT) on $(PROVIDER)..."
	$(SCRIPTS_DIR)/provision-infrastructure.sh $(ENVIRONMENT) $(PROVIDER) destroy

infra-status: check-infra-params ## Show infrastructure status
	@echo "Infrastructure status for $(ENVIRONMENT) on $(PROVIDER):"
	@cd $(TERRAFORM_DIR) && tofu show -no-color | grep -E "(vm_ip|vm_status)" || echo "No infrastructure found"

infra-refresh-state: check-infra-params ## Refresh Terraform state to detect IP changes
	@echo "Refreshing Terraform state..."
	@cd $(TERRAFORM_DIR) && tofu refresh

# Provider and environment information
infra-providers: ## List available infrastructure providers
	@echo "Available Infrastructure Providers:"
	@$(SCRIPTS_DIR)/providers/provider-interface.sh list || echo "No providers found"
	@echo ""
	@echo "Usage examples:"
	@echo "  make infra-apply ENVIRONMENT=development PROVIDER=libvirt"
	@echo "  make infra-apply ENVIRONMENT=staging PROVIDER=digitalocean"
	@echo "  make infra-apply ENVIRONMENT=production PROVIDER=hetzner"

infra-environments: ## List available environments
	@echo "Available Environments:"
	@ls infrastructure/config/environments/*.env \
		infrastructure/config/environments/*.env.tpl 2>/dev/null | \
		xargs -I {} basename {} | sed 's/\.env.*//g' | sort | uniq || \
		echo "No environments found"
	@echo ""
	@echo "Environments:"
	@echo "  development - Local development and testing"
	@echo "  staging     - Pre-production testing"
	@echo "  production  - Production deployment"

provider-info: ## Show provider information (requires PROVIDER=<name>)
	@if [ -z "$(PROVIDER)" ]; then \
		echo "Error: PROVIDER not specified"; \
		echo "Usage: make provider-info PROVIDER=<provider>"; \
		exit 1; \
	fi
	@echo "Getting information for provider: $(PROVIDER)"
	@$(SCRIPTS_DIR)/providers/provider-interface.sh info $(PROVIDER)

infra-config-development: ## Generate development environment configuration
	@echo "Configuring development environment..."
	$(SCRIPTS_DIR)/configure-env.sh development

infra-config-production: ## Generate production environment configuration
	@echo "Configuring production environment..."
	$(SCRIPTS_DIR)/configure-env.sh production

infra-validate-config: ## Validate configuration for all environments
	@echo "Validating configuration..."
	$(SCRIPTS_DIR)/validate-config.sh

infra-test-prereq: ## Test system prerequisites for development
	@echo "Testing prerequisites..."
	$(INFRA_TESTS_DIR)/test-unit-infrastructure.sh vm-prereq

infra-test-ci: ## Run infrastructure-only CI tests (no global concerns)
	@echo "Running infrastructure-only CI tests..."
	$(INFRA_TESTS_DIR)/test-unit-config.sh
	$(INFRA_TESTS_DIR)/test-unit-scripts.sh

infra-test-local: ## Run local-only infrastructure tests (requires virtualization)
	@echo "Running local-only infrastructure tests..."
	$(INFRA_TESTS_DIR)/test-local.sh

# =============================================================================
# APPLICATION LAYER (BUILD + RELEASE + RUN STAGES)
# =============================================================================

app-deploy: ## Deploy application (Twelve-Factor Build + Release + Run stages)
	@echo "Deploying application for $(ENVIRONMENT)..."
	@if [ "$(SKIP_WAIT)" = "true" ]; then \
		echo "⚠️  SKIP_WAIT=true - Application will not wait for service readiness"; \
	else \
		echo "ℹ️  Application will wait for service readiness (use SKIP_WAIT=true to skip)"; \
	fi
	SKIP_WAIT=$(SKIP_WAIT) $(SCRIPTS_DIR)/deploy-app.sh $(ENVIRONMENT)

app-redeploy: ## Redeploy application without infrastructure changes
	@echo "Redeploying application for $(ENVIRONMENT)..."
	$(SCRIPTS_DIR)/deploy-app.sh $(ENVIRONMENT)

app-health-check: ## Validate deployment health
	@echo "Running health check for $(ENVIRONMENT)..."
	$(SCRIPTS_DIR)/health-check.sh $(ENVIRONMENT)

app-test-config: ## Test application configuration
	@echo "Testing application configuration..."
	$(TESTS_DIR)/test-unit-application.sh config

app-test-containers: ## Test application containers
	@echo "Testing application containers..."
	$(TESTS_DIR)/test-unit-application.sh containers

app-test-services: ## Test application services
	@echo "Testing application services..."
	$(TESTS_DIR)/test-unit-application.sh services

app-test-ci: ## Run application-only CI tests (no global concerns)
	@echo "Running application-only CI tests..."
	application/tests/test-ci.sh

# =============================================================================
# VM ACCESS AND DEBUGGING
# =============================================================================

vm-ssh: ## SSH into the VM
	@VM_IP=$$(cd $(TERRAFORM_DIR) && tofu output -raw vm_ip 2>/dev/null) && \
	if [ -n "$$VM_IP" ] && [ "$$VM_IP" != "No IP assigned yet" ]; then \
		echo "Connecting to VM: $$VM_IP"; \
		ssh -o StrictHostKeyChecking=no torrust@$$VM_IP; \
	else \
		echo "Error: VM IP not available. Run 'make infra-status' to check infrastructure."; \
		exit 1; \
	fi

vm-clean-ssh: ## Clean SSH known_hosts for VM (fixes host key verification warnings)
	@echo "Cleaning SSH known_hosts for VM..."
	@$(SCRIPTS_DIR)/ssh-utils.sh clean

vm-prepare-ssh: ## Clean SSH known_hosts and test connectivity  
	@echo "Preparing SSH connection to VM..."
	@$(SCRIPTS_DIR)/ssh-utils.sh prepare

vm-console: ## Access VM console (text-based)
	@echo "Accessing VM console..."
	@virsh console $(VM_NAME) || echo "VM console not accessible. Try 'make vm-gui-console' for graphical console."

vm-gui-console: ## Access VM graphical console (requires GUI)
	@echo "Opening graphical VM console..."
	@virt-viewer --connect qemu:///system $(VM_NAME) &

vm-status: ## Show detailed VM status
	@echo "VM Status for $(VM_NAME):"
	@echo "================================"
	@virsh domstate $(VM_NAME) 2>/dev/null || echo "VM not found"
	@virsh dominfo $(VM_NAME) 2>/dev/null | grep -E "(State|Memory|CPUs)" || true
	@echo ""
	@echo "Network Info:"
	@virsh domifaddr $(VM_NAME) 2>/dev/null || echo "No network info available"
	@echo ""
	@echo "Terraform State:"
	@cd $(TERRAFORM_DIR) && tofu output 2>/dev/null || echo "No Terraform state found"

# =============================================================================
# QUICK DEVELOPMENT WORKFLOWS
# =============================================================================

dev-setup: ## Complete development setup
	@echo "Setting up development environment..."
	@make install-deps

dev-deploy: ## Full deployment workflow (infra + app)
	@echo "Running full deployment workflow for $(ENVIRONMENT)..."
	@make infra-apply ENVIRONMENT=$(ENVIRONMENT)
	@make app-deploy ENVIRONMENT=$(ENVIRONMENT)
	@make app-health-check ENVIRONMENT=$(ENVIRONMENT)
	@echo "✅ Development deployment complete"

dev-test: ## Quick validation (syntax + unit tests)
	@echo "Running quick validation tests..."
	@make lint
	@make test-unit
	@echo "✅ Quick tests passed"

dev-clean: ## Complete cleanup
	@echo "Cleaning up development environment..."
	@make infra-destroy ENVIRONMENT=$(ENVIRONMENT) || true
	@make clean
	@echo "✅ Development environment cleaned"

# =============================================================================
# GLOBAL TESTING AND QUALITY ASSURANCE
# =============================================================================

test-e2e: ## Run comprehensive end-to-end test (follows integration guide)
	@echo "Running comprehensive end-to-end test..."
	$(TESTS_DIR)/test-e2e.sh $(ENVIRONMENT)

test-ci: ## Run project-wide CI tests (global concerns)
	@echo "Running project-wide CI tests..."
	@echo "1. Global concerns (syntax, structure, Makefile)..."
	tests/test-ci.sh
	@echo "2. Infrastructure layer tests..."
	@make infra-test-ci
	@echo "3. Application layer tests..."
	@make app-test-ci
	@echo "✅ All CI tests passed!"
	
test-unit: ## Run unit tests (configuration, scripts, syntax)
	@echo "Running unit tests..."
	@echo "1. Configuration and syntax validation..."
	$(INFRA_TESTS_DIR)/test-unit-config.sh
	@echo "2. Infrastructure scripts validation..."
	$(INFRA_TESTS_DIR)/test-unit-scripts.sh

lint: ## Run syntax validation only
	@echo "Running syntax validation..."
	./scripts/lint.sh

clean: ## Clean up temporary files and caches
	@echo "Cleaning up..."
	@rm -rf $(TERRAFORM_DIR)/.terraform
	@rm -f $(TERRAFORM_DIR)/terraform.tfstate.backup
	@echo "Clean completed"

