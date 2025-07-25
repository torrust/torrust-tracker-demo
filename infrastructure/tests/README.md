# Infrastructure Tests

This directory contains tests specific to infrastructure provisioning and configuration validation.

## Purpose

Tests in this directory focus on:

- **Infrastructure configuration validation** (Terraform/OpenTofu, cloud-init)
- **Infrastructure directory structure verification**
- **Infrastructure script validation**
- **Infrastructure template processing**

## Test Scope

These tests validate infrastructure components **without performing actual deployment**.
They are static validation tests that ensure:

- Configuration files are syntactically correct
- Required infrastructure files and directories exist
- Scripts have proper permissions
- Templates are processable

## Test Organization

### Current Tests

- `test-unit-config.sh` - Main infrastructure configuration validation test suite
- `test-unit-infrastructure.sh` - Infrastructure components validation
- `test-unit-scripts.sh` - Infrastructure scripts validation

### Test Categories

1. **Terraform/OpenTofu Validation** - Ensures infrastructure code is valid
2. **Cloud-init Template Validation** - Checks provisioning templates
3. **Infrastructure Script Validation** - Verifies infrastructure automation scripts
4. **Configuration Template Processing** - Tests infrastructure config generation
5. **Infrastructure Structure Validation** - Verifies infrastructure directory layout

## Usage

```bash
# Run all infrastructure tests
./test-unit-config.sh

# Run specific test categories
./test-unit-config.sh terraform         # Terraform/OpenTofu only
./test-unit-config.sh templates         # Config templates only
./test-unit-config.sh structure         # Structure only
./test-unit-config.sh cloud-init        # Cloud-init templates only
./test-unit-config.sh scripts           # Infrastructure scripts only
```

## Test Organization Guidelines

### What Belongs Here

✅ **Infrastructure layer tests**:

- Terraform/OpenTofu configuration validation
- Cloud-init template validation
- Infrastructure provisioning scripts
- Infrastructure configuration templates
- Infrastructure directory structure
- VM-level configurations

### What Does NOT Belong Here

❌ **Application tests** (belong in `application/tests/`):

- Docker Compose file validation
- Application configuration files
- Application deployment scripts
- Service-specific configurations

❌ **Project-wide tests** (belong in `tests/` at project root):

- Root-level Makefile
- Project structure spanning multiple layers
- Tool availability checks
- Cross-cutting documentation

## Integration with Other Test Layers

This test suite is part of a three-layer testing architecture:

1. **Infrastructure Tests** (`infrastructure/tests/`) - Infrastructure provisioning (this directory)
2. **Application Tests** (`application/tests/`) - Application deployment
3. **Project Tests** (`tests/`) - Cross-cutting project validation

Each layer focuses on its specific concerns and can be run independently.

## Adding New Tests

When adding new infrastructure tests:

1. **Categorize correctly** - Ensure the test belongs to the infrastructure layer
2. **Follow naming conventions** - Use `test_function_name()` format
3. **Add to main suite** - Include in `run_infrastructure_tests()` function
4. **Update help** - Add command options if needed
5. **Document purpose** - Explain what the test validates

### Example Test Function

```bash
test_new_infrastructure_feature() {
    log_info "Testing new infrastructure feature..."

    local failed=0
    # Test implementation here

    if [[ ${failed} -eq 0 ]]; then
        log_success "New infrastructure feature validation passed"
    fi

    return ${failed}
}
```

## Related Documentation

- [Application Tests](../application/tests/README.md)
- [Project Tests](../tests/README.md)
- [Testing Strategy](../docs/testing/test-strategy.md)

## Test Logs

All tests generate detailed logs in `/tmp/`:

- E2E: `/tmp/torrust-e2e-test.log`
- Unit Config: `/tmp/torrust-unit-config-test.log`
- Unit Scripts: `/tmp/torrust-unit-scripts-test.log`

## Documentation

See `docs/testing/test-strategy.md` for complete testing strategy and documentation.
