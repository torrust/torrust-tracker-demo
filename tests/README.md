# End-to-End Tests

This directory contains end-to-end tests that validate the complete Torrust Tracker Demo system.

## Test Structure

### `test-e2e.sh` - Complete Deployment Workflow

**Purpose**: Validates the entire twelve-factor deployment workflow

**What it tests**:

- Infrastructure provisioning (`make infra-apply`)
- Application deployment (`make app-deploy`)
- Health validation (`make health-check`)
- Complete system integration

**Command**: `make test`

**Duration**: ~5-8 minutes

**Environment**: Deploys real VMs and services

## Usage

```bash
# Run complete E2E test
make test

# Run E2E test for specific environment
make test ENVIRONMENT=local

# Run E2E test without cleanup (for debugging)
SKIP_CLEANUP=true make test
```

## Test Flow

1. **Prerequisites Validation** - Validates system requirements
2. **Infrastructure Provisioning** - Deploys VM using `make infra-apply`
3. **Application Deployment** - Deploys tracker using `make app-deploy`
4. **Health Validation** - Validates all services using `make health-check`
5. **Cleanup** - Destroys infrastructure using `make infra-destroy`

## Output

The test generates a detailed log file at `/tmp/torrust-e2e-test.log` with:

- Timing information for each step
- Success/failure status
- Detailed error messages if failures occur

## Integration with Manual Testing

This test exactly mirrors the manual integration testing guide at:
`docs/guides/integration-testing-guide.md`

The E2E test automates the same workflow that developers follow manually, ensuring
consistency between automated and manual testing procedures.

## Related Tests

- **Unit Tests**: `infrastructure/tests/test-unit-*.sh` - Component-level validation
- **Syntax Tests**: `make test-syntax` - Fast validation without deployment
- **Prerequisites**: `make test-prereq` - System requirements validation
