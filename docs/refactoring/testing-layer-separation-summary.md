# Testing Layer Separation - Summary

## Problem

The original `make infra-test-ci` command (which ran `infrastructure/tests/test-ci.sh`) was
mixing concerns across the three project layers:

1. **Infrastructure layer** - `infrastructure/` folder
2. **Application layer** - `application/` folder
3. **Project/Global layer** - Cross-cutting concerns

The `infrastructure/tests/test-ci.sh` script was calling `make lint` (a global command) and
performing other project-wide validations, violating the separation of concerns.

## Solution

Implemented proper three-layer separation for CI testing:

### 1. Project-Wide CI Tests (`make test-ci`)

- **Script**: `tests/test-ci.sh`
- **Purpose**: Global/cross-cutting concerns that span all layers
- **Responsibilities**:
  - Global syntax validation (`./scripts/lint.sh`)
  - Project structure validation
  - Makefile validation
  - Orchestrates infrastructure and application layer tests

### 2. Infrastructure-Only CI Tests (`make infra-test-ci`)

- **Script**: `infrastructure/tests/test-ci.sh` (refactored)
- **Purpose**: Infrastructure-specific validation only
- **Responsibilities**:
  - Terraform/OpenTofu syntax validation
  - Cloud-init template validation
  - Infrastructure script validation
  - Infrastructure configuration validation

### 3. Application-Only CI Tests (`make app-test-ci`)

- **Script**: `application/tests/test-ci.sh` (new)
- **Purpose**: Application-specific validation only
- **Responsibilities**:
  - Docker Compose syntax validation
  - Application configuration validation
  - Deployment script validation
  - Grafana dashboard validation

## Testing Hierarchy

```text
make test-ci (Project-wide orchestrator)
├── Global concerns (syntax, structure, Makefile)
├── make infra-test-ci (Infrastructure layer only)
└── make app-test-ci (Application layer only)
```

## GitHub Actions Integration

Updated `.github/workflows/testing.yml` to use `make test-ci` instead of `make infra-test-ci`,
ensuring all three layers are properly tested in the correct order.

## Benefits

1. **Clear separation of concerns** - Each layer only tests its own responsibilities
2. **Parallel development** - Teams can work on different layers independently
3. **Focused testing** - Developers can test specific layers without running global tests
4. **Maintainable** - Changes to one layer don't affect tests for other layers
5. **CI efficiency** - Better organization of test output and failure isolation

## Commands

| Command              | Purpose                        | Scope                     |
| -------------------- | ------------------------------ | ------------------------- |
| `make test-ci`       | Complete CI validation         | All layers (orchestrator) |
| `make infra-test-ci` | Infrastructure validation only | Infrastructure layer      |
| `make app-test-ci`   | Application validation only    | Application layer         |
| `make lint`          | Global syntax validation       | Project-wide              |

This change ensures that GitHub runners (which don't support virtualization) can properly
validate all project concerns without attempting infrastructure deployment while maintaining
clear architectural boundaries.
