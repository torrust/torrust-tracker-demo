# ADR-001: Keep Makefile at Repository Root Level

## Status

Accepted

## Date

2025-07-01

## Context

During the repository reorganization to separate infrastructure and application
concerns, we considered whether the main `Makefile` should be moved to the
`infrastructure/` directory since it contains primarily infrastructure-related
commands (95% of commands are for VM management, OpenTofu operations, libvirt
setup, etc.).

The repository was reorganized into:

- `infrastructure/` - VMs, cloud-init, system setup, networking
- `application/` - Docker services, app deployment, configuration
- `docs/` - Cross-cutting documentation

### Makefile Content Analysis

The current Makefile contains:

**Infrastructure Commands (95%):**

- `install-deps` - Installs KVM, libvirt, OpenTofu
- `init`, `plan`, `apply`, `destroy` - OpenTofu/Terraform operations
- `ssh`, `status` - VM management
- `test-prereq`, `test-syntax`, `test-integration` - Infrastructure testing
- `fix-libvirt`, `check-libvirt` - libvirt troubleshooting
- `monitor-cloud-init` - VM provisioning monitoring
- `setup-ssh-key` - SSH configuration for VMs

**Cross-cutting Commands (5%):**

- `help`, `workflow-help` - General project help
- `clean` - Cleanup operations
- `dev-setup` - Complete environment setup

**Application Commands:**

- None directly (no Docker Compose, service management commands)

## Decision

**Keep the Makefile at the repository root level.**

## Rationale

### Arguments for keeping at root:

1. **Project Entry Point**: The Makefile serves as the main interface for the
   entire project. Users expect to run `make help` from the project root to
   understand available operations.

2. **Cross-cutting Nature**: While most commands are infrastructure-focused,
   key commands like `dev-setup`, `help`, and `workflow-help` span both
   infrastructure and application concerns.

3. **User Experience**: Moving the Makefile would break the common expectation
   that `make help` works from the project root directory.

4. **Documentation Consistency**: All current documentation (README files,
   quick-start guides, GitHub Actions) references root-level `make` commands.
   Moving would require extensive documentation updates.

5. **CI/CD Integration**: GitHub Actions workflows reference the Makefile from
   the root. Moving it would require updating CI/CD configurations.

6. **Discoverability**: Users cloning the repository expect to find the main
   build/deployment interface at the root level.

### Arguments against moving to infrastructure/:

1. **Breaks Existing Workflows**: All documentation and established user
   workflows would need updating.

2. **Reduces Discoverability**: The Makefile would be less obvious to new
   contributors.

3. **Path Complexity**: Users would need to run `make -C infrastructure help`
   or `cd infrastructure && make help` instead of simply `make help`.

4. **Convention Breaking**: Most projects keep their main Makefile at the root,
   even when it primarily serves one subsystem.

## Consequences

### Positive:

- Maintains familiar user experience and established workflows
- Keeps documentation and CI/CD configurations unchanged
- Preserves the Makefile as the main project interface
- Allows for future expansion with application-specific commands

### Negative:

- The root Makefile contains primarily infrastructure commands, which may seem
  inconsistent with the infrastructure/application separation
- Could be confusing for contributors who expect clear separation of concerns

### Mitigating Actions:

1. **Clear Documentation**: Document in the Makefile header that it primarily
   contains infrastructure commands but serves as the project-wide interface.

2. **Future Enhancement**: Consider adding application-specific commands to the
   root Makefile or creating a delegation system to application-specific
   Makefiles as needed.

3. **Consistent Commenting**: Use clear section comments in the Makefile to
   group related commands and explain their purpose.

## Alternatives Considered

### Alternative 1: Move to infrastructure/

- **Pros**: Better alignment with infrastructure focus
- **Cons**: Breaks user experience, requires extensive documentation updates

### Alternative 2: Split Makefile

- Create `infrastructure/Makefile` for infrastructure-specific commands
- Create `application/Makefile` for application-specific commands
- Keep root Makefile with high-level commands that delegate to specific ones
- **Pros**: Clear separation of concerns
- **Cons**: Added complexity, potential for confusion about which Makefile to use

### Alternative 3: Rename and Move

- Move to `infrastructure/Makefile` and create root-level convenience script
- **Pros**: Clear location for infrastructure commands
- **Cons**: Non-standard approach, added maintenance burden

## References

- Repository reorganization discussion
- Analysis of Makefile content and usage patterns
- User workflow documentation in `infrastructure/docs/quick-start.md`
- CI/CD configuration in `.github/workflows/infrastructure.yml`
