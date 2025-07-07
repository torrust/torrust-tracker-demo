# Infrastructure

This directory contains the infrastructure-as-code configuration for the
Torrust Tracker Demo project.

## Directory Structure

```text
infrastructure/
├── terraform/           # OpenTofu/Terraform configuration
│   ├── main.tf         # Main configuration
│   └── terraform.tfvars.example  # Example variables
└── cloud-init/         # Cloud-init configuration
    ├── user-data.yaml  # Main cloud-init config
    ├── meta-data.yaml  # VM metadata
    └── network-config.yaml  # Network configuration
```

## Purpose

This infrastructure setup provides:

1. **Local Testing Environment** - Test deployments locally using KVM/libvirt
2. **Hetzner Preparation** - Validate configurations before cloud deployment
3. **Consistent Environments** - Reproducible infrastructure across environments
4. **Automated Testing** - Validate changes through automated tests

## Quick Start

See the [Quick Start Guide](docs/quick-start.md) for the fastest way to get started.

### Infrastructure Testing Commands

```bash
# Setup infrastructure dependencies
make dev-setup
# Log out and log back in for group permissions

# Configure SSH key
make setup-ssh-key
# Edit terraform/local.tfvars with your SSH public key

# Test infrastructure layer
make test-prereq     # Check prerequisites
make test-syntax     # Validate configurations
make apply          # Deploy VM
make ssh            # Test access
make destroy        # Clean up

# Run full infrastructure test suite
make test
```

### Infrastructure Only Workflow

```bash
# 1. Install dependencies
make dev-setup

# 2. Configure SSH access
make setup-ssh-key

# 3. Test everything
make test

# 4. Deploy for development
make apply
make ssh

# 5. Clean up
make destroy
```

## Components

### OpenTofu Configuration (`terraform/`)

- **main.tf** - Defines the VM, storage, and networking configuration
- **terraform.tfvars.example** - Template for customizing VM specifications

Key features:

- Uses KVM/libvirt provider for local virtualization
- Downloads Ubuntu 24.04 cloud image automatically
- Configures VM with appropriate resources
- Applies cloud-init configuration during boot

### Cloud-Init Configuration (`cloud-init/`)

- **user-data.yaml** - System configuration, packages, users, and setup scripts
- **meta-data.yaml** - VM metadata (hostname, instance ID)
- **network-config.yaml** - Network configuration (DHCP by default)

The cloud-init configuration:

- Creates `torrust` user with sudo privileges
- Installs Docker and development tools
- Configures UFW firewall with tracker ports
- Applies network performance optimizations
- Sets up automatic security updates

## Usage

### Basic Operations

```bash
# Initialize (first time only)
make init

# Deploy VM
make apply

# Connect to VM
make ssh

# Clean up
make destroy
```

### Testing

```bash
# Run all tests
make test

# Test prerequisites only
make test-prereq

# Test configuration syntax
make test-syntax
```

### Customization

1. Copy the example variables file:

   ```bash
   cp infrastructure/terraform/terraform.tfvars.example infrastructure/terraform/terraform.tfvars
   ```

2. Edit to customize VM specifications:

   ```hcl
   vm_memory = 4096    # 4GB RAM
   vm_vcpus  = 4       # 4 CPU cores
   vm_disk_size = 30   # 30GB disk
   ```

3. Add your SSH public key to `infrastructure/cloud-init/user-data.yaml`

## VM Specifications

### Default Configuration

- **OS**: Ubuntu 24.04 LTS
- **RAM**: 2GB
- **CPU**: 2 cores
- **Disk**: 20GB
- **Network**: DHCP on default libvirt network

### Installed Software

- Docker and Docker Compose
- Git, curl, vim, htop
- UFW firewall
- Fail2ban for SSH protection
- Automatic security updates

### Network Ports

- 22/tcp - SSH
- 80/tcp, 443/tcp - HTTP/HTTPS
- 6868/udp, 6969/udp - Tracker UDP (see [Port Documentation](../application/docs/firewall-requirements.md#torrust-tracker-ports))
- 7070/tcp - Tracker HTTP API (see [Port Documentation](../application/docs/firewall-requirements.md#torrust-tracker-ports))
- 1212/tcp - Metrics (see [Port Documentation](../application/docs/firewall-requirements.md#torrust-tracker-ports))

## Security

The VM is configured with security best practices:

- SSH key authentication only (no passwords)
- UFW firewall with minimal required ports
- Automatic security updates
- Fail2ban protection against brute force attacks
- Docker daemon with log rotation

## Troubleshooting

### Common Issues

1. **libvirt permissions**: Ensure you're in the `libvirt` and `kvm` groups
2. **VM boot issues**: Check `make vm-console` for boot messages
3. **SSH connection**: VM may take 2-3 minutes to fully initialize

### Debugging Commands

```bash
# Check VM status
make vm-info

# Access VM console
make vm-console

# View test logs
make logs

# Check libvirt status
sudo systemctl status libvirtd
```

## Next Steps

After the VM is running:

1. Deploy Torrust Tracker services
2. Run integration tests
3. Test monitoring and metrics
4. Validate backup/restore procedures

## Contributing

When modifying the infrastructure:

1. Test locally with `make test`
2. Update documentation as needed
3. Follow the project's commit conventions
4. Ensure backward compatibility

### Documentation Guidelines

When adding infrastructure documentation:

- **Infrastructure docs**: VMs, cloud-init, system setup, networking, OpenTofu/Terraform
- **Keep it actionable**: Guides should be step-by-step
- **Include troubleshooting**: Document common issues and solutions
- **Cross-reference**: Link to related infrastructure documentation
- **Test instructions**: Always include commands to verify setup

### Infrastructure vs Application Separation

Infrastructure = "Where and how the application runs"

Infrastructure documentation should cover:

- VM provisioning and configuration
- Operating system setup and networking
- System-level security and firewall implementation
- Infrastructure testing and validation
- Cloud provider specific configurations

See [`../application/`](../application/) for application-specific documentation.
