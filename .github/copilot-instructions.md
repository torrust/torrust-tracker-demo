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
│   ├── prompts/             # AI assistant prompts and templates
│   └── copilot-instructions.md  # This contributor guide
├── docs/
│   ├── adr/                # Architecture Decision Records
│   │   └── 001-makefile-location.md  # Makefile location decision
│   ├── guides/             # User and developer guides
│   │   ├── integration-testing-guide.md  # Testing guide
│   │   ├── quick-start.md  # Fast setup guide
│   │   └── smoke-testing-guide.md  # End-to-end testing
│   ├── infrastructure/     # Infrastructure-specific documentation
│   ├── issues/             # Issue documentation and analysis
│   ├── plans/              # Project planning documentation
│   ├── refactoring/        # Refactoring documentation
│   ├── testing/            # Testing documentation
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
│   ├── config/             # Infrastructure configuration templates
│   │   ├── environments/   # Environment-specific configs
│   │   └── templates/      # Configuration templates
│   ├── scripts/            # Infrastructure automation scripts
│   │   ├── deploy-app.sh   # Application deployment script
│   │   ├── provision-infrastructure.sh  # Infrastructure provisioning
│   │   └── health-check.sh # Health validation script
│   ├── tests/              # Infrastructure validation tests
│   ├── docs/               # Infrastructure documentation
│   │   ├── quick-start.md  # Fast setup guide
│   │   ├── local-testing-setup.md  # Detailed setup
│   │   ├── infrastructure-overview.md  # Architecture overview
│   │   ├── refactoring/    # Refactoring documentation
│   │   ├── testing/        # Testing documentation
│   │   ├── third-party/    # Third-party setup guides
│   │   └── bugs/           # Bug documentation
│   ├── .gitignore          # Infrastructure-specific ignores
│   └── README.md           # Infrastructure overview
├── application/            # Application deployment and services
│   ├── config/             # Application configuration
│   │   └── templates/      # Configuration templates
│   ├── share/
│   │   ├── bin/            # Deployment and utility scripts
│   │   ├── container/      # Docker service configurations
│   │   ├── dev/            # Development configs
│   │   └── grafana/        # Grafana dashboards
│   ├── storage/            # Persistent data storage
│   │   ├── certbot/        # SSL certificate storage
│   │   ├── dhparam/        # DH parameters
│   │   ├── prometheus/     # Prometheus data
│   │   ├── proxy/          # Nginx proxy configs
│   │   └── tracker/        # Tracker data
│   ├── docs/               # Application documentation
│   │   ├── production-setup.md    # Production deployment docs
│   │   ├── deployment.md          # Deployment procedures
│   │   ├── firewall-requirements.md # Application firewall requirements
│   │   ├── useful-commands.md     # Operational commands
│   │   └── media/          # Screenshots and diagrams
│   ├── compose.yaml        # Docker Compose for services
│   ├── .env                # Local environment configuration
│   ├── .gitignore          # Application-specific ignores
│   └── README.md           # Application overview
├── scripts/                # Project-wide utility scripts
│   └── lint.sh             # Linting script for all file types
├── Makefile                # Main automation interface
└── *.md                    # Project root documentation
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

# 4. Test twelve-factor deployment workflow locally
make infra-apply  # Provision infrastructure (platform setup)
make app-deploy   # Deploy application (Build + Release + Run stages)
make health-check # Validate deployment
make ssh          # Connect to VM
make infra-destroy # Cleanup

# 5. Run tests
make test         # Full infrastructure test
make test-syntax  # Syntax validation only
```

### Main Commands

#### Twelve-Factor Workflow (Recommended)

| Command             | Purpose                                           |
| ------------------- | ------------------------------------------------- |
| `make infra-apply`  | Provision infrastructure (platform setup)         |
| `make app-deploy`   | Deploy application (Build + Release + Run stages) |
| `make app-redeploy` | Redeploy application (Release + Run stages only)  |
| `make health-check` | Validate deployment health                        |

#### Infrastructure Management

| Command                    | Purpose                                      |
| -------------------------- | -------------------------------------------- |
| `make help`                | Show all available commands                  |
| `make install-deps`        | Install OpenTofu, libvirt, KVM, virt-viewer  |
| `make infra-init`          | Initialize infrastructure (Terraform init)   |
| `make infra-plan`          | Plan infrastructure changes                  |
| `make infra-destroy`       | Destroy infrastructure                       |
| `make infra-status`        | Show infrastructure status                   |
| `make infra-refresh-state` | Refresh Terraform state to detect IP changes |

#### VM Access and Debugging

| Command           | Purpose                           |
| ----------------- | --------------------------------- |
| `make ssh`        | Connect to deployed VM            |
| `make console`    | Access VM console (text-based)    |
| `make vm-console` | Access VM graphical console (GUI) |

#### Testing and Validation

| Command            | Purpose                                 |
| ------------------ | --------------------------------------- |
| `make test`        | Run complete infrastructure tests       |
| `make test-syntax` | Run syntax validation only              |
| `make lint`        | Run all linting (alias for test-syntax) |

#### Legacy Commands (Deprecated)

| Command        | New Equivalent                         |
| -------------- | -------------------------------------- |
| `make apply`   | `make infra-apply` + `make app-deploy` |
| `make destroy` | `make infra-destroy`                   |
| `make status`  | `make infra-status`                    |

## 📋 Conventions and Standards

### Twelve-Factor App Principles

This project implements [twelve-factor app](https://12factor.net/) methodology for application deployment, with a clear separation between infrastructure provisioning and application deployment:

#### Infrastructure vs Application Deployment

**Important Distinction**: The twelve-factor methodology applies specifically to **application deployment**, not infrastructure provisioning.

- **Infrastructure Provisioning** (`make infra-apply`): Separate step that provisions the platform/environment
  - Creates VMs, networks, firewall rules using Infrastructure as Code
  - Applies cloud-init configuration
  - Sets up the foundation where the application will run
  - **This is NOT part of the twelve-factor Build stage**

#### Twelve-Factor Application Deployment Stages

The twelve-factor **Build, Release, Run** stages apply to the application deployment process (`make app-deploy`):

- **Build Stage**: Transform application code into executable artifacts

  - Compile source code for production
  - Create container images (Docker)
  - Package application dependencies
  - Generate static assets

- **Release Stage**: Combine built application with environment-specific configuration

  - Apply environment variables and configuration files
  - Combine application artifacts with runtime configuration
  - Prepare deployment-ready releases

- **Run Stage**: Execute the application in the runtime environment
  - Start application processes (tracker binary, background jobs)
  - Start supporting services (MySQL, Nginx, Prometheus, Grafana)
  - Enable health checks and monitoring
  - Make the application accessible to clients

#### Benefits of This Approach

- **Separation of Concerns**: Infrastructure changes don't require application redeployment
- **Faster Iteration**: Use `make app-redeploy` to update only the application (Release + Run stages)
- **Environment Consistency**: Same application deployment workflow for local testing and production
- **Rollback Capability**: Infrastructure and application can be rolled back independently
- **Testing Isolation**: Test infrastructure provisioning separately from application deployment

#### Typical Development Workflow

1. **Initial Setup**: `make infra-apply` → `make app-deploy`
2. **Code Changes**: `make app-redeploy` (skips infrastructure)
3. **Infrastructure Changes**: `make infra-apply` → `make app-redeploy`
4. **Validation**: `make health-check`
5. **Cleanup**: `make infra-destroy`

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
- **Tables**: Tables automatically ignore line length limits (configured globally in
  `.markdownlint.json`). No special formatting required for table line lengths.

#### Automated Linting

The project includes a comprehensive linting script that validates all file types:

```bash
./scripts/lint.sh              # Run all linters
./scripts/lint.sh --yaml       # Run only yamllint
./scripts/lint.sh --shell      # Run only ShellCheck
./scripts/lint.sh --markdown   # Run only markdownlint
```

**IMPORTANT**: Always run `./scripts/lint.sh` before committing to ensure code quality standards are met.

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

#### End-to-End Smoke Testing

For verifying the functionality of the tracker from an end-user's perspective (e.g., simulating announce/scrape requests), refer to the **Smoke Testing Guide**. This guide explains how to use the official `torrust-tracker-client` tools to perform black-box testing against a running tracker instance without needing a full BitTorrent client.

- **Guide**: [Smoke Testing Guide](../docs/guides/smoke-testing-guide.md)
- **When to use**: After a deployment (`make infra-apply` + `make app-deploy`) or to validate that all services are working together correctly.

#### Sudo Cache Management

The project implements intelligent sudo cache management to improve the user experience during infrastructure provisioning:

- **Automatic prompting**: Scripts will warn users before operations requiring sudo
- **Cache preparation**: Sudo credentials are cached upfront to prevent interruptions
- **Clean output**: Password prompts occur before main operations, not mixed with output
- **Safe commands**: Uses `sudo -v` to cache credentials without executing privileged operations

**Implementation details:**

- Functions in `scripts/shell-utils.sh`: `ensure_sudo_cached()`, `is_sudo_cached()`, `run_with_sudo()`
- Used in: `infrastructure/scripts/fix-volume-permissions.sh`, `infrastructure/scripts/provision-infrastructure.sh`, `tests/test-e2e.sh`
- Cache duration: ~15 minutes (system default)

**Testing the sudo cache:**

```bash
# Test sudo cache management functions
./test-sudo-cache.sh
```

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
   make infra-apply  # Deploy test VM
   make app-deploy   # Deploy application
   make ssh          # Verify access
   make infra-destroy # Clean up
   ```

7. **Review existing issues**: Check [GitHub Issues](https://github.com/torrust/torrust-tracker-demo/issues) for good first contributions

### For Infrastructure Changes

1. **Local testing first**: Always test infrastructure changes locally
2. **Validate syntax**: Run `make test-syntax` before committing
3. **Document changes**: Update relevant documentation
4. **Test twelve-factor workflow**: Ensure both infrastructure provisioning and application deployment work
   ```bash
   make infra-apply   # Test infrastructure provisioning
   make app-deploy    # Test application deployment
   make health-check  # Validate services
   ```

### For AI Assistants

When providing assistance:

- Act as an experienced open-source developer and system administrator
- Follow all conventions listed above
- Prioritize security and best practices
- Test infrastructure changes locally before suggesting them
- Provide clear explanations and documentation
- Consider the migration to Hetzner infrastructure in suggestions

#### Command Execution Context

Be mindful of the execution context for different types of commands. The project uses several command-line tools that must be run from specific directories:

- **`make` commands**: (e.g., `make help`, `make infra-status`) must be run from the project root directory.
- **OpenTofu commands**: (e.g., `tofu init`, `tofu plan`, `tofu apply`) must be run from the `infrastructure/terraform/` directory.
- **Docker Compose commands**: (e.g., `docker compose up -d`, `docker compose ps`) are intended to be run _inside the deployed virtual machine_, typically from the `/home/torrust/github/torrust/torrust-tracker-demo/application` directory.

**IMPORTANT**: Always be aware of the current working directory. The repository location `~/Documents/git/committer/me/github/torrust/torrust-tracker-demo` is used in documentation as an example, but contributors may have the project cloned elsewhere. Verify the current location before executing commands.

#### Working with Remote Terminals

When executing commands on the remote VM, be aware of limitations with interactive sessions.

- **Problem**: The VS Code integrated terminal may not correctly handle commands that initiate a new interactive shell, such as `ssh torrust@<VM_IP>` or `make ssh`. The connection may succeed, but subsequent commands sent to that shell may not execute as expected, and their output may not be captured.

- **Solution**: Prefer executing commands non-interactively whenever possible. Instead of opening a persistent SSH session, pass the command directly to `ssh`.

  - **Don't do this**:

    ```bash
    # 1. Log in
    make ssh
    # 2. Run command (this might fail or output won't be seen)
    df -H
    ```

  - **Do this instead**:
    ```bash
    # Execute the command directly via ssh
    ssh torrust@<VM_IP> 'df -H'
    ```

This ensures that the command is executed and its output is returned to the primary terminal session.

#### Preferred Working Methodology

**Work in Small Steps:**

- Break down complex tasks into small, manageable increments
- Each step should be independently testable and reviewable
- Prefer multiple small commits over large monolithic changes

**Parallel Changes When Possible:**

- Identify changes that can be made independently
- Suggest parallel work streams for unrelated modifications
- Separate concerns to enable concurrent development

**Separate Refactors from Features:**

- **Refactoring commits**: Focus solely on code structure, organization, or cleanup
- **Feature commits**: Focus on adding new functionality or enabling features
- Never mix refactoring with feature addition in the same commit
- Always complete refactoring first, then add features in subsequent commits

**Complex Tasks and Bug Fixes:**

- For any task that requires multiple intermediary steps, always present a plan first
- Break down the approach into numbered steps with clear objectives
- Ask for confirmation before implementing the plan
- Include rollback strategies for critical changes
- Identify potential risks and mitigation strategies upfront

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

**Commit Signing Requirement**: All commits MUST be signed with GPG. When performing git commits, always use the default git commit behavior (which will trigger GPG signing) rather than `--no-gpg-sign`.

**Pre-commit Testing Requirement**: ALWAYS run the CI test suite before committing any changes:

```bash
make test-ci
```

This command runs all unit tests that don't require a virtual machine, including:

- **Linting validation**: YAML files (yamllint), shell scripts (ShellCheck), markdown files (markdownlint)
- **Infrastructure tests**: Terraform/OpenTofu syntax, cloud-init templates, infrastructure scripts
- **Application tests**: Docker Compose syntax, application configuration, deployment scripts
- **Project tests**: Makefile syntax, project structure, tool requirements, documentation structure

Only commit if all CI tests pass. If any tests fail, fix the issues before committing.

**Note**: End-to-end tests (`make test`) are excluded from pre-commit requirements due to their longer execution time (~5-8 minutes), but running them before pushing is strongly recommended for comprehensive validation.

**Best Practice**: Always ask "Would you like me to commit these changes?" before performing any git state-changing operations.

## 📖 Additional Resources

- **Torrust Tracker**: <https://github.com/torrust/torrust-tracker>
- **OpenTofu Documentation**: <https://opentofu.org/docs/>
- **Cloud-init Documentation**: <https://cloud-init.io/>
- **libvirt Documentation**: <https://libvirt.org/>
- **Repomix Tool**: <https://repomix.com/> (for generating project summaries)
