# Infrastructure Tests

This directory contains unit tests for infrastructure components.

## Test Structure

### End-to-End Tests (Project Root)

- **`tests/test-e2e.sh`** - Complete deployment workflow test
  - Follows `docs/guides/integration-testing-guide.md` exactly
  - Tests both infrastructure and application deployment
  - Uses actual make commands (`infra-apply`, `app-deploy`, `health-check`)
  - Duration: ~5-8 minutes
  - Command: `make test`

### Infrastructure Unit Tests (This Directory)

- **`test-unit-config.sh`** - Configuration and syntax validation

  - Terraform/OpenTofu, Docker Compose syntax validation
  - Project structure and Makefile validation
  - Configuration template processing tests
  - **Note**: YAML and shell validation is handled by `./scripts/lint.sh`
  - Duration: ~1-2 minutes
  - Command: `infrastructure/tests/test-unit-config.sh`

- **`test-unit-scripts.sh`** - Infrastructure scripts validation
  - Script existence, permissions, help functionality
  - Parameter validation, coding standards
  - Duration: ~30 seconds
  - Command: `infrastructure/tests/test-unit-scripts.sh`

### Legacy Tests (Deprecated)

- **`test-integration.sh`** - **DEPRECATED** - Use `test-e2e.sh`
- **`test-local-setup.sh`** - **DEPRECATED** - Use unit tests

## Quick Commands

```bash
# Run all tests
make test                    # E2E test (infrastructure + app deployment)
make test-unit              # Unit tests (config + scripts)
make test-syntax            # Syntax validation (./scripts/lint.sh)

# Run specific tests
tests/test-e2e.sh local
infrastructure/tests/test-unit-config.sh terraform
infrastructure/tests/test-unit-scripts.sh provision
```

## Test Logs

All tests generate detailed logs in `/tmp/`:

- E2E: `/tmp/torrust-e2e-test.log`
- Unit Config: `/tmp/torrust-unit-config-test.log`
- Unit Scripts: `/tmp/torrust-unit-scripts-test.log`

## Documentation

See `docs/testing/test-strategy.md` for complete testing strategy and documentation.
