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
│   ├── adr/                # Architecture Decision Records
│   │   └── 001-makefile-location.md  # Makefile location decision
│   └── README.md           # Cross-cutting documentation index
├── infrastructure/         # Infrastructure as Code
│   ├── terraform/          # OpenTofu/Terraform configurations
│   │   ├── main.tf         # VM and infrastructure definition
│   │   └── terraform.tfvars.example  # Example configuration
│   ├── cloud-init/         # VM provisioning templates
│   │   ├── user-data.yaml.tpl     # Main system configuration
│   │   ├── user-data-minimal.yaml.tpl  # Debug configuration
│   │   ├── meta-data.yaml  # VM metadata
│   │   └── network-config.yaml    # Network setup
│   ├── scripts/           # Infrastructure automation scripts
│   ├── tests/             # Infrastructure validation tests
│   ├── docs/              # Infrastructure documentation
│   │   ├── quick-start.md  # Fast setup guide
│   │   ├── local-testing-setup.md  # Detailed setup
│   │   ├── infrastructure-overview.md  # Architecture overview
│   │   ├── testing/        # Testing documentation
│   │   └── third-party/    # Third-party setup guides
│   ├── .gitignore         # Infrastructure-specific ignores
│   └── README.md          # Infrastructure overview
├── application/           # Application deployment and services
│   ├── share/
│   │   ├── bin/           # Deployment and utility scripts
│   │   ├── container/     # Docker service configurations
│   │   ├── dev/           # Development configs
│   │   └── grafana/       # Grafana dashboards
│   ├── docs/              # Application documentation
│   │   ├── production-setup.md    # Production deployment docs
│   │   ├── deployment.md          # Deployment procedures
│   │   ├── firewall-requirements.md # Application firewall requirements
│   │   ├── useful-commands.md     # Operational commands
│   │   └── media/         # Screenshots and diagrams
│   ├── compose.yaml       # Docker Compose for services
│   ├── .env.production    # Production environment template
│   ├── .gitignore         # Application-specific ignores
│   └── README.md          # Application overview
├── Makefile              # Main automation interface
└── *.md                  # Project root documentation
```

### Key Components

#### 🏗️ Infrastructure (`infrastructure/`)

- **OpenTofu/Terraform**: Declarative infrastructure configuration
- **Cloud-init**: Automated VM provisioning and setup
- **Scripts**: Automation helpers for libvirt, monitoring, etc.
- **Tests**: Infrastructure validation and integration tests
- **Documentation**: Infrastructure-specific guides and references

#### 🐳 Application Services (`application/`)

- **Docker Compose**: Service orchestration configuration
- **Service Configs**: Nginx, Grafana, Prometheus configurations
- **Deployment Scripts**: Application deployment and utility scripts
- **Documentation**: Production setup, deployment, and operational guides

#### 📚 Documentation (`docs/`)

- **Cross-cutting**: Project-wide documentation and ADRs
- **Architecture Decisions**: Documented design choices and rationale

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
| `make install-deps`       | Install OpenTofu, libvirt, KVM, virt-viewer |
| `make test`               | Run complete infrastructure tests |
| `make apply`              | Deploy VM with full configuration |
| `make apply-minimal`      | Deploy VM with minimal config     |
| `make ssh`                | Connect to deployed VM            |
| `make console`            | Access VM console (text-based)    |
| `make vm-console`         | Access VM graphical console (GUI) |
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

#### TOML Configuration Files

- **Formatting**: Use [Even Better TOML](https://marketplace.visualstudio.com/items?itemName=tamasfe.even-better-toml) extension for VS Code
- **Style**: Blank lines between sections, 2-space indentation, preserve comments
- **Configuration**: Project includes `.taplo.toml` and `.vscode/settings.json` for consistent formatting
- **Key conventions**:
  - Blank line before each `[section]` and `[[array]]`
  - Detailed comments for port configurations
  - Preserve logical grouping and order
  - No automatic key reordering

#### Infrastructure as Code

- **Validation**: All Terraform/OpenTofu must pass `tofu validate`
- **Planning**: Test with `tofu plan` before applying
- **Variables**: Use `terraform.tfvars` for sensitive/local config (git-ignored)
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

- **SSH Keys**: Use template variables, store in `terraform.tfvars`
- **Git Ignore**: Distributed `.gitignore` files in each component (root, infrastructure, application)
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

   - [Quick Start Guide](../infrastructure/docs/quick-start.md)
   - [Complete Setup Guide](../infrastructure/docs/local-testing-setup.md)
   - [Production Setup Guide](../application/docs/production-setup.md)

2. **Set up your development environment**:

   ```bash
   make install-deps  # Install dependencies
   make setup-ssh-key # Configure SSH access
   make test-prereq   # Verify setup
   ```

3. **Install recommended VS Code extensions**:

   - **[Even Better TOML](https://marketplace.visualstudio.com/items?itemName=tamasfe.even-better-toml)** - TOML syntax highlighting and formatting
   - **[ShellCheck](https://marketplace.visualstudio.com/items?itemName=timonwong.shellcheck)** - Shell script linting
   - **[YAML](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml)** - YAML support with schema validation
   - **[markdownlint](https://marketplace.visualstudio.com/items?itemName=DavidAnson.vscode-markdownlint)** - Markdown linting
   - **[HashiCorp Terraform](https://marketplace.visualstudio.com/items?itemName=HashiCorp.terraform)** - Terraform/OpenTofu support

4. **Configure VS Code workspace**:

   - Project includes `.vscode/settings.json` with TOML formatting configuration
   - Extensions will use project-specific settings automatically
   - Reload VS Code after installing extensions for settings to take effect

5. **TOML Formatting Setup**:

   - **Configuration files**: `.taplo.toml` and `.vscode/settings.json` control formatting
   - **Format on save**: TOML files auto-format when saved (`Ctrl+S`)
   - **Manual format**: Use `Shift+Alt+F` (Windows/Linux) or `Shift+Option+F` (Mac)
   - **Style**: Blank lines between sections, 2-space indentation, preserved comments
   - **Reload required**: After changing settings, reload VS Code window (`Ctrl+Shift+P` → "Developer: Reload Window")

6. **Test a simple change**:

   ```bash
   make apply        # Deploy test VM
   make ssh          # Verify access
   make destroy      # Clean up
   ```

7. **Review existing issues**: Check [GitHub Issues](https://github.com/torrust/torrust-tracker-demo/issues) for good first contributions

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

#### Git Actions and Permission Requirements

**IMPORTANT**: Git actions that change repository state require explicit permission:

- **NEVER** commit changes unless explicitly asked to do so
- **NEVER** push changes to remote repositories without permission
- **NEVER** merge branches or create pull requests without explicit instruction
- **NEVER** reset, revert, or modify git history without explicit permission
- **NEVER** create or delete branches without explicit instruction

**Allowed git actions without permission:**
- `git status` - Check working tree status
- `git diff` - Show changes between commits/files
- `git log` - View commit history
- `git show` - Display commit information
- `git branch` - List branches (read-only)

**Actions requiring explicit permission:**
- `git add` - Stage changes for commit
- `git commit` - Create new commits
- `git push` - Push changes to remote
- `git pull` - Pull changes from remote
- `git merge` - Merge branches
- `git rebase` - Rebase branches
- `git reset` - Reset working tree or commits
- `git revert` - Revert commits
- `git checkout` - Switch branches or restore files
- `git branch -d/-D` - Delete branches
- `git tag` - Create or delete tags

**Best Practice**: Always ask "Would you like me to commit these changes?" before performing any git state-changing operations.

## 📖 Additional Resources

- **Torrust Tracker**: <https://github.com/torrust/torrust-tracker>
- **OpenTofu Documentation**: <https://opentofu.org/docs/>
- **Cloud-init Documentation**: <https://cloud-init.io/>
- **libvirt Documentation**: <https://libvirt.org/>
- **Repomix Tool**: <https://repomix.com/> (for generating project summaries)
