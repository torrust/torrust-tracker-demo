# Project-wide Tests

This directory contains tests that span both infrastructure and application layers,
validating project-wide concerns and cross-cutting functionality.

## Purpose

Tests in this directory focus on:

- **Project-wide configuration validation** (root-level Makefile, project structure)
- **Tool availability and requirements verification**
- **Cross-cutting documentation validation**
- **End-to-end integration testing**

## Test Scope

These tests validate project-wide components and integration between infrastructure
and application layers.

## Test Organization

### Current Tests

- `test-e2e.sh` - Complete deployment workflow test (infrastructure + application)
- `test-unit-project.sh` - Project-wide configuration and structure validation

### Test Categories

#### End-to-End Tests

1. **Complete Deployment Workflow** (`test-e2e.sh`)
   - Infrastructure provisioning (`make infra-apply`)
   - Application deployment (`make app-deploy`)
   - Health validation (`make app-health-check`)
   - Complete system integration
   - Duration: ~5-8 minutes

#### Project-wide Unit Tests

1. **Makefile Validation** - Tests root-level Makefile syntax
2. **Tool Requirements** - Verifies required and optional tools are available
3. **Project Structure** - Validates overall project organization
4. **Documentation Structure** - Checks cross-cutting documentation
5. **Test Organization** - Validates test directory structure

## Usage

```bash
# Run complete E2E test
make test

# Run project-wide unit tests
./test-unit-project.sh

# Run specific project-wide test categories
./test-unit-project.sh makefile         # Makefile only
./test-unit-project.sh tools           # Tool requirements only
./test-unit-project.sh structure       # Project structure only
./test-unit-project.sh docs            # Documentation structure only
./test-unit-project.sh tests           # Test organization only
```

## Test Organization Guidelines

### What Belongs Here

✅ **Project-wide tests**:

- Root-level Makefile validation
- Project structure spanning multiple layers
- Tool availability checks
- Cross-cutting documentation validation
- End-to-end integration tests
- Overall project organization validation

### What Does NOT Belong Here

❌ **Infrastructure tests** (belong in `infrastructure/tests/`):

- Terraform/OpenTofu configurations
- Cloud-init templates
- Infrastructure provisioning scripts
- VM-level configurations

❌ **Application tests** (belong in `application/tests/`):

- Docker Compose file validation
- Application configuration files
- Application deployment scripts
- Service-specific configurations

## Integration with Other Test Layers

This test suite is part of a three-layer testing architecture:

1. **Infrastructure Tests** (`infrastructure/tests/`) - Infrastructure provisioning
2. **Application Tests** (`application/tests/`) - Application deployment
3. **Project Tests** (`tests/`) - Cross-cutting project validation (this directory)

The project tests orchestrate and validate the integration between the other layers.

## End-to-End Test Details

### `test-e2e.sh` - Complete Deployment Workflow

**Command**: `make test`
**Duration**: ~5-8 minutes
**Environment**: Deploys real VMs and services

**Test Flow**:

1. **Prerequisites Validation** - Validates system requirements
2. **Infrastructure Provisioning** - Deploys VM using `make infra-apply`
3. **Application Deployment** - Deploys tracker using `make app-deploy`
4. **Health Validation** - Validates all services using `make app-health-check`
5. **Cleanup** - Destroys infrastructure using `make infra-destroy`

**Output**: Generates detailed log at `/tmp/torrust-e2e-test.log`

### Integration with Manual Testing

The E2E test exactly mirrors the manual integration testing guide at:
`docs/guides/integration-testing-guide.md`

It automates the same workflow that developers follow manually, ensuring
consistency between automated and manual testing procedures.

## Adding New Tests

When adding new project-wide tests:

1. **Categorize correctly** - Ensure the test spans multiple layers or addresses project-wide concerns
2. **Follow naming conventions** - Use `test_function_name()` format
3. **Add to main suite** - Include in appropriate test function
4. **Update help** - Add command options if needed
5. **Document purpose** - Explain what the test validates

### Example Test Function

```bash
test_new_project_feature() {
    log_info "Testing new project-wide feature..."

    local failed=0
    # Test implementation here

    if [[ ${failed} -eq 0 ]]; then
        log_success "New project feature validation passed"
    fi

    return ${failed}
}
```

## Related Documentation

- [Infrastructure Tests](../infrastructure/tests/README.md)
- [Application Tests](../application/tests/README.md)
- [Testing Strategy](../docs/testing/test-strategy.md)
