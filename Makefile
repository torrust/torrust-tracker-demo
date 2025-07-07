# Makefile for Torrust Tracker Local Testing Infrastructure
.PHONY: help init plan apply destroy test clean status refresh-state ssh install-deps console vm-console lint lint-yaml lint-shell lint-markdown

# Default variables
VM_NAME ?= torrust-tracker-demo
TERRAFORM_DIR = infrastructure/terraform
TESTS_DIR = infrastructure/tests

# Help target
help: ## Show this help message
	@echo "Torrust Tracker Local Testing Infrastructure"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install-deps: ## Install required dependencies (Ubuntu/Debian)
	@echo "Installing dependencies..."
	sudo apt update
	sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager virt-viewer genisoimage
	sudo usermod -aG libvirt $$USER
	sudo usermod -aG kvm $$USER
	sudo systemctl enable libvirtd
	sudo systemctl start libvirtd
	@echo "Setting up libvirt storage and permissions..."
	@sudo virsh pool-define-as default dir --target /var/lib/libvirt/images || true
	@sudo virsh pool-autostart default || true
	@sudo virsh pool-start default || true
	@sudo chown -R libvirt-qemu:libvirt /var/lib/libvirt/images/ || true
	@sudo chmod -R 755 /var/lib/libvirt/images/ || true
	@echo "Installing OpenTofu..."
	curl -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh
	chmod +x install-opentofu.sh
	sudo ./install-opentofu.sh --install-method deb
	rm install-opentofu.sh
	@echo "Dependencies installed. Please log out and log back in for group changes to take effect."

init: ## Initialize OpenTofu
	@echo "Initializing OpenTofu..."
	cd $(TERRAFORM_DIR) && tofu init

plan: ## Show what OpenTofu will do
	@echo "Planning infrastructure changes..."
	@if [ -f $(TERRAFORM_DIR)/local.tfvars ]; then \
		cd $(TERRAFORM_DIR) && tofu plan -var-file="local.tfvars"; \
	else \
		echo "WARNING: No local.tfvars found. Please create it first with 'make setup-ssh-key'"; \
		exit 1; \
	fi

apply-minimal: ## Deploy VM with minimal cloud-init configuration
	@echo "Ensuring libvirt permissions are correct..."
	@$(MAKE) fix-libvirt
	@echo "Deploying VM with minimal configuration..."
	cd $(TERRAFORM_DIR) && tofu apply -var-file="local.tfvars" -var="use_minimal_config=true" -parallelism=1 -auto-approve
	@echo "Fixing permissions after deployment..."
	@$(MAKE) fix-libvirt

apply: ## Deploy the VM
	@echo "Ensuring libvirt permissions are correct..."
	@$(MAKE) fix-libvirt
	@echo "Deploying VM..."
	@if [ -f $(TERRAFORM_DIR)/local.tfvars ]; then \
		echo "Using local SSH key configuration..."; \
		cd $(TERRAFORM_DIR) && tofu apply -var-file="local.tfvars" -parallelism=1 -auto-approve; \
	else \
		echo "WARNING: No local.tfvars found. Creating with placeholder..."; \
		echo 'ssh_public_key = "REPLACE_WITH_YOUR_SSH_PUBLIC_KEY"' > $(TERRAFORM_DIR)/local.tfvars; \
		echo "Please edit $(TERRAFORM_DIR)/local.tfvars with your SSH public key and run 'make apply' again"; \
		exit 1; \
	fi
	@echo "Fixing permissions after deployment..."
	@$(MAKE) fix-libvirt

destroy: ## Destroy the VM
	@echo "Destroying VM..."
	cd $(TERRAFORM_DIR) && tofu destroy -auto-approve

status: ## Show current infrastructure status
	@echo "Infrastructure status:"
	cd $(TERRAFORM_DIR) && tofu show

refresh-state: ## Refresh Terraform state to detect IP changes
	@echo "Refreshing Terraform state..."
	cd $(TERRAFORM_DIR) && tofu refresh
	@echo "Updated outputs:"
	cd $(TERRAFORM_DIR) && tofu output

ssh: ## SSH into the VM
	@echo "Connecting to VM..."
	@VM_IP=$$(virsh domifaddr $(VM_NAME) | grep ipv4 | awk '{print $$4}' | cut -d'/' -f1); \
	if [ -n "$$VM_IP" ]; then \
		echo "Connecting to $$VM_IP..."; \
		ssh torrust@$$VM_IP; \
	else \
		echo "Could not get VM IP. Is the VM deployed?"; \
		exit 1; \
	fi

test: ## Run all tests
	@echo "Running infrastructure tests..."
	$(TESTS_DIR)/test-local-setup.sh full-test

test-prereq: ## Test prerequisites only
	@echo "Testing prerequisites..."
	$(TESTS_DIR)/test-local-setup.sh prerequisites

check-libvirt: ## Check libvirt installation and permissions
	@echo "Checking libvirt setup..."
	@echo "1. Checking if libvirt service is running:"
	@sudo systemctl status libvirtd --no-pager -l || echo "libvirtd not running"
	@echo ""
	@echo "2. Checking user groups:"
	@groups | grep -q libvirt && echo "✓ User is in libvirt group" || echo "✗ User is NOT in libvirt group"
	@groups | grep -q kvm && echo "✓ User is in kvm group" || echo "✗ User is NOT in kvm group"
	@echo ""
	@echo "3. Testing libvirt access:"
	@virsh list --all >/dev/null 2>&1 && echo "✓ User can access libvirt" || echo "✗ User cannot access libvirt (try 'sudo virsh list')"
	@echo ""
	@echo "4. Checking default network:"
	@virsh net-list --all 2>/dev/null | grep -q default && echo "✓ Default network exists" || echo "✗ Default network missing"
	@echo ""
	@echo "5. Checking KVM support:"
	@test -r /dev/kvm && echo "✓ KVM device accessible" || echo "✗ KVM device not accessible"
	@echo ""
	@echo "If you see any ✗ marks, run 'make fix-libvirt' to attempt fixes"

fix-libvirt: ## Fix common libvirt permission issues
	@echo "Setting up user-friendly libvirt configuration..."
	@infrastructure/scripts/setup-user-libvirt.sh
	@echo "Attempting to fix libvirt permissions..."
	@echo "Adding user to required groups..."
	sudo usermod -aG libvirt $$USER
	sudo usermod -aG kvm $$USER
	@echo "Starting libvirt service..."
	sudo systemctl enable libvirtd
	sudo systemctl start libvirtd
	@echo "Checking if default network needs to be started..."
	@sudo virsh net-list --all | grep -q "default.*inactive" && sudo virsh net-start default || true
	@sudo virsh net-autostart default 2>/dev/null || true
	@echo ""
	@echo "✓ Fix attempt completed!"
	@echo "IMPORTANT: You need to log out and log back in (or run 'newgrp libvirt') for group changes to take effect"
	@echo "Then run 'make check-libvirt' to verify the fixes worked"

test-syntax: ## Test configuration syntax only
	@echo "Testing configuration syntax..."
	$(TESTS_DIR)/test-local-setup.sh syntax

lint: ## Run all linting checks (yamllint, shellcheck, markdownlint)
	@echo "Running linting checks..."
	./scripts/lint.sh

lint-yaml: ## Run only yamllint
	@echo "Running yamllint..."
	./scripts/lint.sh --yaml

lint-shell: ## Run only shellcheck
	@echo "Running shellcheck..."
	./scripts/lint.sh --shell

lint-markdown: ## Run only markdownlint
	@echo "Running markdownlint..."
	./scripts/lint.sh --markdown

test-integration: ## Run integration tests (requires deployed VM)
	@echo "Running integration tests..."
	$(TESTS_DIR)/test-integration.sh full-test

deploy-test: ## Deploy VM for testing (without cleanup)
	@echo "Deploying test VM..."
	$(TESTS_DIR)/test-local-setup.sh deploy

clean: ## Clean up temporary files
	@echo "Cleaning up..."
	rm -f $(TERRAFORM_DIR)/.terraform.lock.hcl
	rm -f $(TERRAFORM_DIR)/terraform.tfstate.backup
	rm -f install-opentofu.sh
	rm -f /tmp/torrust-infrastructure-test.log

clean-and-fix: ## Clean up all VMs and fix libvirt permissions
	@echo "Cleaning up VMs and fixing permissions..."
	@echo "1. Stopping and undefining any existing VMs:"
	@for vm in $$(virsh list --all --name 2>/dev/null | grep -v '^$$'); do \
		echo "  Cleaning up VM: $$vm"; \
		virsh destroy $$vm 2>/dev/null || true; \
		virsh undefine $$vm 2>/dev/null || true; \
	done
	@echo "2. Removing OpenTofu state:"
	@cd $(TERRAFORM_DIR) && rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl 2>/dev/null || true
	@echo "3. Cleaning libvirt images:"
	@sudo rm -f /var/lib/libvirt/images/torrust-tracker-demo* /var/lib/libvirt/images/ubuntu-24.04-base.qcow2 2>/dev/null || true
	@echo "4. Fixing libvirt setup:"
	@$(MAKE) fix-libvirt
	@echo "✓ Clean up complete. You can now run 'make apply' safely."

# New target for setting up SSH key
setup-ssh-key: ## Setup local SSH key configuration
	@if [ -f $(TERRAFORM_DIR)/local.tfvars ]; then \
		echo "Local SSH configuration already exists at $(TERRAFORM_DIR)/local.tfvars"; \
		echo "Current configuration:"; \
		cat $(TERRAFORM_DIR)/local.tfvars; \
	else \
		echo "Creating local SSH key configuration..."; \
		echo 'ssh_public_key = "REPLACE_WITH_YOUR_SSH_PUBLIC_KEY"' > $(TERRAFORM_DIR)/local.tfvars; \
		echo ""; \
		echo "✓ Created $(TERRAFORM_DIR)/local.tfvars"; \
		echo ""; \
		echo "Next steps:"; \
		echo "1. Get your SSH public key:"; \
		echo "   cat ~/.ssh/id_rsa.pub"; \
		echo "   # or cat ~/.ssh/id_ed25519.pub"; \
		echo ""; \
		echo "2. Edit the file and replace the placeholder:"; \
		echo "   vim $(TERRAFORM_DIR)/local.tfvars"; \
		echo ""; \
		echo "3. Deploy the VM:"; \
		echo "   make apply"; \
	fi

restart-and-monitor: ## Destroy, deploy fresh, and monitor cloud-init
	@echo "🔄 Complete restart: destroying existing VM..."
	@$(MAKE) destroy || true
	@echo "🚀 Deploying fresh VM..."
	@$(MAKE) apply &
	@echo "⏳ Waiting 10 seconds for VM to start..."
	@sleep 10
	@echo "📡 Starting cloud-init monitoring..."
	@$(MAKE) monitor-cloud-init

fresh-start: restart-and-monitor ## Alias for restart-and-monitor

# Development targets
dev-setup: install-deps init fix-libvirt setup-ssh-key ## Complete development setup
	@echo "Development environment setup complete!"
	@echo "Next steps:"
	@echo "1. Log out and log back in for group changes"
	@echo "2. Edit $(TERRAFORM_DIR)/local.tfvars with your SSH public key"
	@echo "3. Run 'make test-prereq' to verify setup"
	@echo "4. Run 'make apply' to deploy a VM"

quick-test: test-prereq test-syntax ## Quick test without VM deployment
	@echo "Quick tests completed!"

# Help for specific workflows
workflow-help: ## Show common workflows
	@echo "Common workflows:"
	@echo ""
	@echo "1. First-time setup:"
	@echo "   make dev-setup"
	@echo "   # Log out and log back in"
	@echo "   # Edit infrastructure/cloud-init/user-data.yaml to add your SSH key"
	@echo "   make test-prereq"
	@echo ""
	@echo "2. Deploy and test:"
	@echo "   make apply"
	@echo "   make ssh"
	@echo "   make destroy"
	@echo ""
	@echo "3. Run full test suite:"
	@echo "   make test"
	@echo ""
	@echo "4. Run integration tests:"
	@echo "   make apply"
	@echo "   make test-integration"
	@echo "   make destroy"
	@echo ""
	@echo "5. Development cycle:"
	@echo "   make plan     # Review changes"
	@echo "   make apply    # Deploy"
	@echo "   make ssh      # Test manually"
	@echo "   make destroy  # Clean up"

monitor-cloud-init: ## Monitor cloud-init progress in real-time
	@echo "Monitoring cloud-init progress..."
	@./infrastructure/scripts/monitor-cloud-init.sh

vm-restart: ## Restart the VM
	@echo "Restarting VM..."
	virsh shutdown $(VM_NAME)
	@echo "Waiting for shutdown..."
	@sleep 5
	virsh start $(VM_NAME)
	@echo "VM restarted"

# CI/CD specific targets
ci-test-syntax: ## Test syntax for CI (with dummy values)
	@echo "Testing syntax for CI environment..."
	@echo "Creating temporary config with dummy values..."
	@cd $(TERRAFORM_DIR) && \
		echo 'ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC dummy-key-for-ci-testing"' > ci-test.tfvars && \
		tofu init && \
		tofu validate && \
		rm ci-test.tfvars
	@echo "Testing cloud-init templates..."
	@CI=true $(TESTS_DIR)/test-local-setup.sh syntax
	@echo "Testing cloud-init YAML syntax with yamllint..."
	@if command -v yamllint >/dev/null 2>&1; then \
		yamllint -c .yamllint-ci.yml infrastructure/cloud-init/network-config.yaml && \
		yamllint -c .yamllint-ci.yml infrastructure/cloud-init/meta-data.yaml && \
		cd infrastructure/cloud-init && \
		sed 's/$${ssh_public_key}/ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/' user-data.yaml.tpl > /tmp/user-data-test.yaml && \
		sed 's/$${ssh_public_key}/ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/' user-data-minimal.yaml.tpl > /tmp/user-data-minimal-test.yaml && \
		yamllint -c ../../.yamllint-ci.yml /tmp/user-data-test.yaml && \
		yamllint -c ../../.yamllint-ci.yml /tmp/user-data-minimal-test.yaml && \
		rm -f /tmp/user-data-test.yaml /tmp/user-data-minimal-test.yaml; \
	else \
		echo "yamllint not available, skipping additional YAML validation"; \
	fi

vm-ip: ## Show VM IP address
	@echo "Getting VM IP address..."
	@VM_IP=$$(virsh domifaddr $(VM_NAME) | grep ipv4 | awk '{print $$4}' | cut -d'/' -f1); \
	if [ -n "$$VM_IP" ]; then \
		echo "VM IP: $$VM_IP"; \
	else \
		echo "VM IP not assigned yet or VM not running"; \
		echo "VM status:"; \
		virsh list --all | grep $(VM_NAME) || echo "VM not found"; \
	fi

vm-info: ## Show detailed VM network information
	@echo "VM Network Information:"
	@echo "======================"
	@virsh list --all | grep $(VM_NAME) | head -1 || echo "VM not found"
	@echo ""
	@echo "Network interfaces:"
	@virsh domifaddr $(VM_NAME) 2>/dev/null || echo "No network information available"
	@echo ""
	@echo "DHCP leases:"
	@virsh net-dhcp-leases default 2>/dev/null | grep $(VM_NAME) || echo "No DHCP lease found"

console: ## Access VM console (text-based)
	@echo "Connecting to VM console..."
	@echo "Use Ctrl+] to exit console"
	@virsh console $(VM_NAME)

vm-console: ## Access VM graphical console (GUI)
	@echo "Opening VM graphical console..."
	@if command -v virt-viewer >/dev/null 2>&1; then \
		virt-viewer $(VM_NAME) || virt-viewer spice://127.0.0.1:5900; \
	else \
		echo "virt-viewer not found. Please install it:"; \
		echo "  sudo apt install virt-viewer"; \
	fi
