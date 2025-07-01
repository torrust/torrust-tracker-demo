# Torrust Tracker Demo - Contributor Guide

## 🎯 Project Overview

**Torrust Tracker Demo** is the complete production deployment configuration for running a live [Torrust Tracker](https://github.com/torrust/torrust-tracker) instance. This repository provides:

- **Production deployment** configurations for Hetzner cloud infrastructure
- **Local testing environment** using KVM/libvirt virtualization
- **Infrastructure as Code** approach using OpenTofu/Terraform and cloud-init
- **Monitoring setup** with Grafana dashboards and Prometheus metrics
- **Automated deployment** scripts and Docker Compose configurations

### Current Major Initiative

We are migrating the tracker to a new infrastructure on Hetzner, involving:

- Running the tracker binary directly on the host for performance
- Using Docker for supporting services (Nginx, Prometheus, Grafana, MySQL)
- Migrating the database from SQLite to MySQL
- Implementing Infrastructure as Code for reproducible deployments

## 📁 Repository Structure

```text
torrust-tracker-demo/
├── .github/
│   ├── workflows/           # GitHub Actions CI/CD pipelines
│   └── copilot-instructions.md  # This contributor guide
├── docs/
│   ├── infrastructure/      # Local testing documentation
│   │   ├── quick-start.md   # Fast setup guide
│   │   ├── local-testing-setup.md  # Detailed setup
│   │   └── libvirt-setup.md # Troubleshooting guide
│   ├── setup.md            # Production deployment docs
│   ├── deployment.md       # Deployment procedures
│   ├── firewall.md         # Security configuration
│   └── *.md                # Additional operational docs
├── infrastructure/         # Infrastructure as Code
│   ├── terraform/          # OpenTofu/Terraform configurations
│   │   ├── main.tf         # VM and infrastructure definition
│   │   └── local.tfvars    # Local configuration (git-ignored)
│   ├── cloud-init/         # VM provisioning templates
│   │   ├── user-data.yaml.tpl     # Main system configuration
│   │   ├── user-data-minimal.yaml.tpl  # Debug configuration
│   │   ├── meta-data.yaml  # VM metadata
│   │   └── network-config.yaml    # Network setup
│   └── scripts/           # Infrastructure automation scripts
├── share/
│   ├── bin/               # Deployment and utility scripts
│   └── container/default/config/  # Docker service configurations
├── tests/infrastructure/  # Infrastructure validation tests
├── compose.yaml           # Docker Compose for services
├── Makefile              # Main automation interface
└── *.md                  # Project documentation
```

### Key Components

#### 🏗️ Infrastructure (`infrastructure/`)

- **OpenTofu/Terraform**: Declarative infrastructure configuration
- **Cloud-init**: Automated VM provisioning and setup
- **Scripts**: Automation helpers for libvirt, monitoring, etc.

#### 🐳 Docker Services (`compose.yaml`, `share/container/`)

- **Nginx**: Reverse proxy and SSL termination
- **Grafana**: Metrics visualization and dashboards
- **Prometheus**: Metrics collection and storage
- **Certbot**: Automated SSL certificate management

#### 🧪 Testing (`tests/infrastructure/`)

- **Validation scripts**: Ensure infrastructure works correctly
- **Integration tests**: End-to-end deployment verification
- **CI/CD pipelines**: Automated testing in GitHub Actions

#### 📚 Documentation (`docs/`)

- **Production**: Setup, deployment, and operational guides
- **Local testing**: Development and testing instructions
- **Troubleshooting**: Common issues and solutions

## 🛠️ Development Workflow

### Quick Start for Contributors

```bash
# 1. Clone and setup
git clone https://github.com/torrust/torrust-tracker-demo.git
cd torrust-tracker-demo

# 2. Install dependencies (Ubuntu/Debian)
make install-deps

# 3. Setup SSH key for VMs
make setup-ssh-key

# 4. Test infrastructure locally
make apply        # Deploy test VM
make ssh         # Connect to VM
make destroy     # Cleanup

# 5. Run tests
make test        # Full infrastructure test
make test-syntax # Syntax validation only
```

### Main Commands

| Command                   | Purpose                           |
| ------------------------- | --------------------------------- |
| `make help`               | Show all available commands       |
| `make install-deps`       | Install OpenTofu, libvirt, KVM    |
| `make test`               | Run complete infrastructure tests |
| `make apply`              | Deploy VM with full configuration |
| `make apply-minimal`      | Deploy VM with minimal config     |
| `make ssh`                | Connect to deployed VM            |
| `make destroy`            | Remove deployed VM                |
| `make monitor-cloud-init` | Watch VM provisioning progress    |

## 📋 Conventions and Standards

### Git Workflow

#### Branch Naming

- **Format**: `{issue-number}-{short-description}`
- **Examples**: `42-add-mysql-support`, `15-fix-ssl-renewal`
- Always start with the GitHub issue number

#### Commit Messages

- **Format**: Conventional Commits with issue references
- **Structure**: `{type}: [#{issue}] {description}`
- **Examples**:
  ```
  feat: [#42] add MySQL database support
  fix: [#15] resolve SSL certificate renewal issue
  docs: [#8] update deployment guide
  ci: [#23] add infrastructure validation tests
  ```

#### Commit Types

- `feat`: New features
- `fix`: Bug fixes
- `docs`: Documentation changes
- `ci`: CI/CD pipeline changes
- `refactor`: Code refactoring
- `test`: Test additions/changes
- `chore`: Maintenance tasks

### Code Quality Standards

#### Shell Scripts

- **POSIX Compliance**: All shell scripts must be POSIX-compliant
- **Linting**: Use [ShellCheck](https://github.com/koalaman/shellcheck)
- **Error Handling**: Use `set -euo pipefail` for strict error handling
- **Documentation**: Include help functions and clear comments

#### YAML Files

- **Linting**: Use [yamllint](https://yamllint.readthedocs.io/en/stable/)
- **Configuration**: Follow `.yamllint-ci.yml` rules
- **Formatting**: 2-space indentation, 120-character line limit
- **Comments**: Use `# ` (space after hash) for comments

#### Markdown Documentation

- **Linting**: Follow [markdownlint](https://github.com/DavidAnson/markdownlint) conventions
- **Structure**: Use consistent heading hierarchy
- **Links**: Prefer relative links for internal documentation
- **Code blocks**: Always specify language for syntax highlighting

#### Infrastructure as Code

- **Validation**: All Terraform/OpenTofu must pass `tofu validate`
- **Planning**: Test with `tofu plan` before applying
- **Variables**: Use `local.tfvars` for sensitive/local config (git-ignored)
- **Templates**: Use `.tpl` extension for templated files

### Testing Requirements

#### Infrastructure Tests

- **Syntax validation**: All configurations must pass linting
- **Local deployment**: Must successfully deploy and provision VMs
- **Service validation**: All services must start and be accessible
- **Network testing**: Ports and firewall rules must be correct

#### CI/CD Requirements

- **GitHub Actions**: All PRs must pass CI validation
- **No secrets**: Never commit SSH keys, passwords, or tokens
- **Documentation**: Update docs for any infrastructure changes

### Security Guidelines

#### Secrets Management

- **SSH Keys**: Use template variables, store in `local.tfvars`
- **Git Ignore**: All sensitive files must be in `.gitignore`
- **Environment Variables**: Use environment variables for CI/CD secrets
- **Review**: All security-related changes require review

#### Infrastructure Security

- **UFW Firewall**: Only open required ports
- **SSH Access**: Key-based authentication only
- **Updates**: Enable automatic security updates
- **Monitoring**: Log security events and access

## 🚀 Getting Started

### For New Contributors

1. **Read the documentation**:

   - [Quick Start Guide](../docs/infrastructure/quick-start.md)
   - [Complete Setup Guide](../docs/infrastructure/local-testing-setup.md)

2. **Set up your environment**:

   ```bash
   make install-deps  # Install dependencies
   make setup-ssh-key # Configure SSH access
   make test-prereq   # Verify setup
   ```

3. **Test a simple change**:

   ```bash
   make apply        # Deploy test VM
   make ssh          # Verify access
   make destroy      # Clean up
   ```

4. **Review existing issues**: Check [GitHub Issues](https://github.com/torrust/torrust-tracker-demo/issues) for good first contributions

### For Infrastructure Changes

1. **Local testing first**: Always test infrastructure changes locally
2. **Validate syntax**: Run `make test-syntax` before committing
3. **Document changes**: Update relevant documentation
4. **Test end-to-end**: Ensure the full deployment pipeline works

### For AI Assistants

When providing assistance:

- Act as an experienced open-source developer and system administrator
- Follow all conventions listed above
- Prioritize security and best practices
- Test infrastructure changes locally before suggesting them
- Provide clear explanations and documentation
- Consider the migration to Hetzner infrastructure in suggestions

## 📖 Additional Resources

- **Torrust Tracker**: <https://github.com/torrust/torrust-tracker>
- **OpenTofu Documentation**: <https://opentofu.org/docs/>
- **Cloud-init Documentation**: <https://cloud-init.io/>
- **libvirt Documentation**: <https://libvirt.org/>
- **Repomix Tool**: <https://repomix.com/> (for generating project summaries)
