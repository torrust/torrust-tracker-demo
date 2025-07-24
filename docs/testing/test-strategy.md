# Testing Strategy - Automated Tests

This document describes the automated testing strategy for the Torrust Tracker Demo project.

## Overview

The project follows a layered testing approach that separates concerns and provides different
levels of validation.

## Test Types

### 1. End-to-End Tests (E2E)

**Purpose**: Validate the complete twelve-factor deployment workflow  
**Location**: `tests/test-e2e.sh`  
**Command**: `make test`

**What it tests**:

- Complete infrastructure provisioning (`make infra-apply`)
- Application deployment (`make app-deploy`)
- Health validation (`make health-check`)
- **Mandatory smoke testing** (tracker functionality validation)
- Cleanup (`make infra-destroy`)

**Follows**: Exactly mirrors `docs/guides/integration-testing-guide.md`

**Duration**: ~5-8 minutes  
**Cost**: High (deploys real infrastructure)  
**Value**: High (validates entire system)

```bash
# Run E2E test
make test ENVIRONMENT=local

# Run E2E test without cleanup (for debugging)
SKIP_CLEANUP=true make test ENVIRONMENT=local
```

### 2. Unit Tests

**Purpose**: Validate individual components without infrastructure deployment  
**Location**: `infrastructure/tests/test-unit-*.sh`  
**Command**: `make test-unit`

#### Configuration and Syntax Tests

**Script**: `test-unit-config.sh`

**What it tests**:

- Terraform/OpenTofu configuration validation
- Docker Compose syntax validation
- Makefile syntax validation
- Project structure validation
- Required tools availability
- Configuration template processing

**Note**: YAML and shell script syntax validation is handled by `./scripts/lint.sh`

```bash
# Run all unit tests
make test-unit

# Run only configuration tests
infrastructure/tests/test-unit-config.sh

# Run specific syntax tests
infrastructure/tests/test-unit-config.sh terraform
infrastructure/tests/test-unit-config.sh docker
```

#### Script Unit Tests

**Script**: `test-unit-scripts.sh`

**What it tests**:

- Script existence and permissions
- Script help functionality
- Parameter validation
- Coding standards compliance
- Directory structure

```bash
# Run script unit tests
infrastructure/tests/test-unit-scripts.sh

# Test specific script
infrastructure/tests/test-unit-scripts.sh provision
infrastructure/tests/test-unit-scripts.sh deploy
```

**Duration**: ~1-2 minutes  
**Cost**: Low (no infrastructure deployment)  
**Value**: Medium (catches syntax and configuration errors early)

### 3. Syntax Validation

**Purpose**: Fast feedback on code quality  
**Command**: `make test-syntax` or `make lint`

**What it tests**:

- All file syntax using `scripts/lint.sh`
- YAML, Shell, Markdown validation
- Code quality standards

```bash
# Run syntax validation
make test-syntax

# Or using alias
make lint
```

**Duration**: ~30 seconds  
**Cost**: Very low  
**Value**: High (prevents broken commits)

### 4. Manual Integration Tests

**Purpose**: Human validation and exploratory testing  
**Location**: `docs/guides/integration-testing-guide.md`

**When to use**:

- Testing new features manually
- Validating complex user workflows
- Debugging deployment issues
- Training and documentation

## Test Workflow

### Development Workflow

```bash
# 1. Fast feedback during development
make test-syntax

# 2. Validate changes without deployment
make test-unit

# 3. Full validation before commit/PR
make test ENVIRONMENT=local
```

## Benefits

### 1. Reliability

- E2E tests use the exact same commands as the integration guide
- No duplication of deployment logic
- Tests what users actually do

### 2. Speed

- Unit tests provide fast feedback without infrastructure
- Syntax tests catch errors in seconds
- Developers can test locally without waiting

### 3. Maintainability

- Tests use existing scripts and commands
- Changes to deployment automatically reflected in tests
- Clear separation of concerns

### 4. Cost Efficiency

- Unit tests run without infrastructure costs
- E2E tests only when needed (PRs, releases)
- Syntax tests run on every commit

## Migration from Legacy Tests

### Legacy Test Files (Deprecated)

- `test-integration.sh` - **DEPRECATED**: Use `test-e2e.sh`
- `test-local-setup.sh` - **DEPRECATED**: Use `test-unit-config.sh` + `test-unit-scripts.sh`

### Migration Commands

```bash
# OLD: Complex integration test
infrastructure/tests/test-integration.sh

# NEW: E2E test following integration guide
make test

# OLD: Mixed infrastructure/syntax test
infrastructure/tests/test-local-setup.sh

# NEW: Focused unit tests
make test-unit
```

### Backward Compatibility

Legacy tests are maintained for compatibility but marked as deprecated:

```bash
# Still works but shows deprecation warning
make test-legacy
```

## Troubleshooting

### Common Issues

**E2E test fails with infrastructure errors**:

```bash
# Check prerequisites
make test-syntax

# Check VM status
make infra-status

# Clean up and retry
make infra-destroy && make test
```

**Unit tests fail with tool missing**:

```bash
# Install missing tools
make install-deps

# Check tool availability
infrastructure/tests/test-unit-config.sh tools
```

**Syntax tests fail**:

```bash
# Run specific linting
./scripts/lint.sh --yaml
./scripts/lint.sh --shell
./scripts/lint.sh --markdown
```

### Test Logs

All tests generate detailed logs:

- E2E: `/tmp/torrust-e2e-test.log`
- Unit Config: `/tmp/torrust-unit-config-test.log`
- Unit Scripts: `/tmp/torrust-unit-scripts-test.log`

## Contributing

When adding new functionality:

1. **Add unit tests first** - Test configuration and scripts
2. **Update E2E test if needed** - Usually automatic if using make commands
3. **Update documentation** - Keep integration guide current
4. **Test all levels** - Syntax → Unit → E2E

This layered approach ensures fast feedback during development while maintaining
comprehensive validation of the complete system.
