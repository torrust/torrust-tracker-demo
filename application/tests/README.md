# Application Tests

This directory contains tests specific to application deployment and configuration validation.

## Purpose

Tests in this directory focus on:

- **Application configuration validation** (Docker Compose, environment files)
- **Application directory structure verification**
- **Deployment script validation**
- **Service configuration testing** (Grafana, monitoring configs)

## Test Scope

These tests validate application components **without performing actual deployment**.
They are static validation tests that ensure:

- Configuration files are syntactically correct
- Required files and directories exist
- Scripts have proper permissions
- Service configurations are valid

## Test Organization

### Current Tests

- `test-unit-application.sh` - Main application validation test suite

### Test Categories

1. **Docker Compose Validation** - Ensures `compose.yaml` is valid
2. **Configuration Validation** - Checks `.env` templates and config files
3. **Structure Validation** - Verifies application directory structure
4. **Script Validation** - Checks deployment scripts exist and are executable
5. **Service Configuration** - Validates Grafana dashboards and other service configs

## Usage

```bash
# Run all application tests
./test-unit-application.sh

# Run specific test categories
./test-unit-application.sh docker          # Docker Compose only
./test-unit-application.sh config          # Configuration only
./test-unit-application.sh structure       # Structure only
./test-unit-application.sh scripts         # Scripts only
./test-unit-application.sh grafana         # Grafana config only
```

## Test Organization Guidelines

### What Belongs Here

✅ **Application layer tests**:

- Docker Compose file validation
- Application configuration files (`.env`, service configs)
- Application deployment scripts
- Service-specific configurations (Grafana, Prometheus configs)
- Application directory structure

### What Does NOT Belong Here

❌ **Infrastructure tests** (belong in `infrastructure/tests/`):

- Terraform/OpenTofu configurations
- Cloud-init templates
- Infrastructure provisioning scripts
- VM-level configurations

❌ **Project-wide tests** (belong in `tests/` at project root):

- Root-level Makefile
- Project structure spanning multiple layers
- Tool availability checks
- Cross-cutting documentation

## Integration with Other Test Layers

This test suite is part of a three-layer testing architecture:

1. **Infrastructure Tests** (`infrastructure/tests/`) - Infrastructure provisioning
2. **Application Tests** (`application/tests/`) - Application deployment (this directory)
3. **Project Tests** (`tests/`) - Cross-cutting project validation

Each layer focuses on its specific concerns and can be run independently.

## Adding New Tests

When adding new application tests:

1. **Categorize correctly** - Ensure the test belongs to the application layer
2. **Follow naming conventions** - Use `test_function_name()` format
3. **Add to main suite** - Include in `run_application_tests()` function
4. **Update help** - Add command options if needed
5. **Document purpose** - Explain what the test validates

### Example Test Function

```bash
test_new_application_feature() {
    log_info "Testing new application feature..."

    local failed=0
    # Test implementation here

    if [[ ${failed} -eq 0 ]]; then
        log_success "New application feature validation passed"
    fi

    return ${failed}
}
```

## Related Documentation

- [Infrastructure Tests](../infrastructure/tests/README.md)
- [Project Tests](../tests/README.md)
- [Testing Strategy](../docs/testing/test-strategy.md)
