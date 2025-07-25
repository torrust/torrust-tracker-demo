# Test Organization Guide

This document establishes the organization principles for tests in the Torrust Tracker Demo
repository to prevent future misorganization and ensure clear separation of concerns.

## Three-Layer Test Architecture

The repository follows a **three-layer testing architecture** that mirrors the project's structure:

```text
torrust-tracker-demo/
├── infrastructure/tests/     # Layer 1: Infrastructure Provisioning
├── application/tests/        # Layer 2: Application Deployment
└── tests/                   # Layer 3: Project-wide Integration
```

### Layer 1: Infrastructure Tests (`infrastructure/tests/`)

**Purpose**: Validate infrastructure provisioning components

**Scope**: Infrastructure-as-Code validation, VM provisioning, cloud-init templates

**What belongs here**:

- ✅ Terraform/OpenTofu configuration validation
- ✅ Cloud-init template syntax and structure
- ✅ Infrastructure provisioning scripts
- ✅ Infrastructure configuration templates
- ✅ Infrastructure directory structure
- ✅ VM-level configurations and networking

**Examples**:

```bash
# Good - Infrastructure layer tests
test_terraform_syntax()           # Validates Terraform/OpenTofu configs
test_cloud_init_templates()       # Validates cloud-init templates
test_infrastructure_scripts()     # Validates provisioning scripts
test_infrastructure_structure()   # Validates infrastructure directory layout
```

### Layer 2: Application Tests (`application/tests/`)

**Purpose**: Validate application deployment components

**Scope**: Application services, Docker Compose, service configurations

**What belongs here**:

- ✅ Docker Compose file validation
- ✅ Application configuration files (`.env`, service configs)
- ✅ Application deployment scripts
- ✅ Service-specific configurations (Grafana, Prometheus configs)
- ✅ Application directory structure
- ✅ Container orchestration validation

**Examples**:

```bash
# Good - Application layer tests
test_docker_compose_syntax()      # Validates Docker Compose configuration
test_application_config()         # Validates application config files
test_deployment_scripts()         # Validates app deployment scripts
test_grafana_config()             # Validates service configurations
```

### Layer 3: Project Tests (`tests/`)

**Purpose**: Validate project-wide concerns and cross-cutting functionality

**Scope**: Project structure, tooling, end-to-end integration

**What belongs here**:

- ✅ Root-level Makefile validation
- ✅ Project structure spanning multiple layers
- ✅ Tool availability and requirements checks
- ✅ Cross-cutting documentation validation
- ✅ End-to-end integration tests
- ✅ Overall project organization validation

**Examples**:

```bash
# Good - Project-wide tests
test_makefile_syntax()            # Validates root Makefile
test_project_structure()          # Validates overall project organization
test_required_tools()             # Validates tool availability
test_documentation_structure()    # Validates cross-cutting docs
```

## Decision Framework

When adding a new test, ask these questions to determine the correct layer:

### 1. What does this test validate?

- **Infrastructure provisioning component** → `infrastructure/tests/`
- **Application deployment component** → `application/tests/`
- **Project-wide or cross-cutting concern** → `tests/`

### 2. Which layer owns the component being tested?

- **Component in `infrastructure/` directory** → `infrastructure/tests/`
- **Component in `application/` directory** → `application/tests/`
- **Component at project root or spanning multiple layers** → `tests/`

### 3. What would break if this component failed?

- **Infrastructure provisioning would fail** → `infrastructure/tests/`
- **Application deployment would fail** → `application/tests/`
- **Overall project workflow would fail** → `tests/`

## Common Misorganization Patterns

### Anti-Pattern 1: Mixing Layers in One Test File

❌ **Bad Example**: One test file testing infrastructure, application, and project concerns

```bash
# BAD: Mixed concerns in one file
test_terraform_syntax()           # Infrastructure concern
test_docker_compose_syntax()      # Application concern
test_makefile_syntax()            # Project concern
test_required_tools()             # Project concern
```

✅ **Good Example**: Separate test files for each layer

```bash
# infrastructure/tests/test-unit-infrastructure.sh
test_terraform_syntax()           # Infrastructure only

# application/tests/test-unit-application.sh
test_docker_compose_syntax()      # Application only

# tests/test-unit-project.sh
test_makefile_syntax()            # Project-wide only
test_required_tools()             # Project-wide only
```

### Anti-Pattern 2: Wrong Layer Assignment

❌ **Bad Examples**:

```bash
# BAD: Docker Compose in infrastructure tests
# infrastructure/tests/test-unit-config.sh
test_docker_compose_syntax()      # Should be in application/tests/

# BAD: Makefile in infrastructure tests
# infrastructure/tests/test-unit-config.sh
test_makefile_syntax()            # Should be in tests/

# BAD: Terraform in project tests
# tests/test-unit-project.sh
test_terraform_syntax()           # Should be in infrastructure/tests/
```

### Anti-Pattern 3: Unclear Naming

❌ **Bad Examples**:

```bash
test_config()                     # Too vague - what kind of config?
test_syntax()                     # Too vague - syntax of what?
test_all_files()                  # Too broad
```

✅ **Good Examples**:

```bash
test_terraform_syntax()           # Clear: Terraform configuration syntax
test_docker_compose_syntax()      # Clear: Docker Compose syntax
test_application_structure()      # Clear: Application directory structure
```

## Test File Naming Conventions

### Infrastructure Tests

```bash
infrastructure/tests/
├── test-unit-infrastructure.sh   # Main infrastructure validation
├── test-unit-scripts.sh          # Infrastructure scripts validation
└── README.md                     # Infrastructure test documentation
```

### Application Tests

```bash
application/tests/
├── test-unit-application.sh      # Main application validation
└── README.md                     # Application test documentation
```

### Project Tests

```bash
tests/
├── test-e2e.sh                   # End-to-end integration tests
├── test-unit-project.sh          # Project-wide unit tests
└── README.md                     # Project test documentation
```

## Test Function Naming Conventions

Use descriptive, layer-specific naming:

```bash
# Infrastructure layer
test_terraform_syntax()
test_cloud_init_templates()
test_infrastructure_scripts()
test_infrastructure_structure()

# Application layer
test_docker_compose_syntax()
test_application_config()
test_deployment_scripts()
test_grafana_config()

# Project layer
test_makefile_syntax()
test_project_structure()
test_required_tools()
test_documentation_structure()
```

## Validation Checklist

Before adding a new test, verify:

- [ ] Test belongs to correct layer based on component ownership
- [ ] Test file is in the appropriate directory
- [ ] Test function has clear, descriptive naming
- [ ] Test is added to the correct main test function
- [ ] Help text is updated if adding new command options
- [ ] Related documentation is updated

## Directory Structure Validation

Each test layer should validate its own directory structure:

```bash
# Infrastructure tests validate infrastructure structure
test_infrastructure_structure() {
    local required_paths=(
        "terraform"
        "scripts"
        "cloud-init"
        "tests"
        "docs"
    )
    # ... validation logic
}

# Application tests validate application structure
test_application_structure() {
    local required_paths=(
        "compose.yaml"
        "config"
        "share"
        "storage"
        "docs"
        "tests"
    )
    # ... validation logic
}

# Project tests validate overall project structure
test_project_structure() {
    local required_paths=(
        "Makefile"
        "infrastructure/terraform"
        "application/compose.yaml"
        "tests"
        "docs"
    )
    # ... validation logic
}
```

## Documentation Requirements

Each test layer must maintain:

1. **README.md** - Explains the layer's purpose, scope, and usage
2. **Clear categorization** - What belongs and what doesn't
3. **Usage examples** - How to run tests
4. **Integration documentation** - How layers work together

## Enforcement

This organization is enforced through:

1. **Code review guidelines** - All new tests must follow these principles
2. **Documentation validation** - Tests verify proper organization
3. **CI/CD validation** - Automated checks ensure compliance
4. **Developer guidelines** - Clear contributor instructions

## Related Documentation

- [Infrastructure Tests README](../infrastructure/tests/README.md)
- [Application Tests README](../application/tests/README.md)
- [Project Tests README](../tests/README.md)
- [Testing Strategy](testing/test-strategy.md)
