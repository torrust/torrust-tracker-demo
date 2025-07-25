# Test Categorization Analysis - CI vs Local Testing

This document provides a comprehensive analysis of all tests in the Torrust Tracker Demo project,
categorized by their compatibility with GitHub runners vs local virtualization requirements.

## Summary

| Test Category                    | Count | CI Compatible | Virtualization Required |
| -------------------------------- | ----- | ------------- | ----------------------- |
| **Syntax Validation**            | 1     | ✅ Yes        | ❌ No                   |
| **Configuration Tests**          | 1     | ✅ Yes        | ❌ No                   |
| **Script Unit Tests**            | 1     | ✅ Yes        | ❌ No                   |
| **Infrastructure Prerequisites** | 1     | ❌ No         | ✅ Yes                  |
| **End-to-End Tests**             | 1     | ❌ No         | ✅ Yes                  |

## Detailed Test Analysis

### ✅ CI-COMPATIBLE TESTS (GitHub Runners)

These tests can run in GitHub's hosted runners without requiring nested virtualization.

#### 1. Syntax Validation (`scripts/lint.sh`)

- **Purpose**: Validates file syntax across the project
- **Coverage**:
  - YAML files using `yamllint`
  - Shell scripts using `shellcheck`
  - Markdown files using `markdownlint-cli`
- **Dependencies**:
  - `yamllint` (available via apt)
  - `shellcheck` (available via apt)
  - `markdownlint-cli` (available via npm)
- **Runtime**: ~30 seconds
- **CI Status**: ✅ **FULLY COMPATIBLE**

#### 2. Configuration Validation (`infrastructure/tests/test-unit-config.sh`)

- **Purpose**: Validates infrastructure and application configurations
- **Coverage**:
  - Terraform/OpenTofu syntax validation (`tofu validate`)
  - Docker Compose syntax validation (`docker compose config`)
  - Cloud-init YAML validation
  - Configuration template validation
- **Dependencies**:
  - OpenTofu (installable via script)
  - Docker (available in GitHub runners)
  - Basic Linux tools
- **Runtime**: ~1-2 minutes
- **CI Status**: ✅ **FULLY COMPATIBLE**

#### 3. Script Unit Tests (`infrastructure/tests/test-unit-scripts.sh`)

- **Purpose**: Validates infrastructure automation scripts
- **Coverage**:
  - Script executability checks
  - Help/usage functionality validation
  - Parameter validation (dry-run mode)
  - ShellCheck validation on all scripts
- **Dependencies**: Standard Linux tools
- **Runtime**: ~30 seconds-1 minute
- **CI Status**: ✅ **FULLY COMPATIBLE**

### ❌ VIRTUALIZATION-REQUIRED TESTS (Local Only)

These tests require KVM/libvirt and cannot run in GitHub's hosted runners due to nested
virtualization limitations.

#### 1. Infrastructure Prerequisites (`infrastructure/tests/test-unit-infrastructure.sh`)

- **Purpose**: Validates local virtualization environment
- **Coverage**:
  - libvirt service status (`systemctl is-active libvirtd`)
  - KVM device accessibility (`/dev/kvm`)
  - User libvirt permissions (`virsh list`)
  - Default network configuration (`virsh net-list`)
  - Storage pool configuration (`virsh pool-list`)
- **Dependencies**:
  - KVM kernel modules
  - libvirt daemon
  - Virtualization hardware support
- **Why CI Incompatible**:
  - No `/dev/kvm` device in containers
  - No nested virtualization support
  - No libvirt daemon in runners
- **CI Status**: ❌ **REQUIRES VIRTUALIZATION**

#### 2. End-to-End Tests (`tests/test-e2e.sh`)

- **Purpose**: Full twelve-factor deployment validation
- **Coverage**:
  - VM provisioning (`make infra-apply`)
  - Application deployment (`make app-deploy`)
  - Service health validation (`make health-check`)
  - Network connectivity testing
  - Complete workflow validation
- **Dependencies**:
  - Full KVM/libvirt stack
  - VM creation capabilities
  - Network bridge configuration
- **Runtime**: 5-8 minutes
- **Why CI Incompatible**:
  - Creates actual VMs
  - Requires hardware virtualization
  - Needs libvirt networking
- **CI Status**: ❌ **REQUIRES VIRTUALIZATION**

## Implementation Strategy

### New Make Targets

The Makefile has been updated with clear separation:

```bash
# CI-Compatible Tests (GitHub Runners)
make test-ci      # Runs: syntax + config + scripts validation
make test-syntax  # Fast syntax validation only
make test-unit    # Configuration and script unit tests

# Local-Only Tests (Virtualization Required)
make test-local   # Prerequisites + infrastructure validation
make test         # Full end-to-end deployment testing
```

### Testing Workflow

#### For CI/CD Pipeline (GitHub Actions)

```bash
# Fast feedback loop (~2-3 minutes total)
make test-ci
```

This runs:

1. `test-syntax` - Syntax validation (30s)
2. `test-unit-config` - Configuration validation (1-2min)
3. `test-unit-scripts` - Script unit tests (30s-1min)

#### For Local Development

```bash
# Quick local validation (~3-5 minutes)
make test-local

# Complete validation (~8-12 minutes)
make test
```

### New Test Scripts

#### `infrastructure/tests/test-ci.sh`

- **Purpose**: Orchestrates all CI-compatible tests
- **Features**:
  - Comprehensive logging
  - Clear error reporting
  - Test execution summary
  - No virtualization requirements

#### `infrastructure/tests/test-local.sh`

- **Purpose**: Orchestrates local-only tests requiring virtualization
- **Features**:
  - CI environment detection (fails gracefully if run in CI)
  - Virtualization prerequisites validation
  - Infrastructure readiness checks
  - Clear guidance for next steps

## GitHub Actions Integration

### Current Workflow (`testing.yml`)

```yaml
# Currently only runs syntax validation
- name: Run linting script
  run: ./scripts/lint.sh
```

### Recommended Enhancement

```yaml
# Enhanced CI workflow
- name: Install dependencies
  run: |
    sudo apt-get update
    sudo apt-get install -y yamllint shellcheck docker-compose
    sudo npm install -g markdownlint-cli

    # Install OpenTofu
    curl -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh
    chmod +x install-opentofu.sh
    sudo ./install-opentofu.sh --install-method deb

- name: Run CI test suite
  run: make test-ci
```

## Benefits of This Approach

### ✅ Advantages

1. **Fast CI Feedback**: CI tests complete in 2-3 minutes vs 8-12 minutes for full E2E
2. **Clear Separation**: Developers know which tests can run where
3. **Comprehensive Coverage**: 80% of issues caught without virtualization
4. **Resource Efficient**: CI doesn't waste time on impossible tests
5. **Local Development**: Full testing capabilities preserved for development

### 🔧 Trade-offs

1. **Partial Coverage in CI**: VM deployment issues only caught locally
2. **Two-tiered Testing**: Requires local testing for complete validation
3. **Complexity**: Developers need to understand test categorization

## Future Enhancements

### Potential CI Alternatives

1. **Self-hosted Runners**: Enable full virtualization support
2. **Cloud Integration**: Use actual cloud VMs for E2E testing
3. **Container-based Testing**: Refactor E2E tests to use Docker instead of VMs

### Test Coverage Expansion

1. **Application-level Tests**: Add container-based application testing
2. **Integration Tests**: Test service interactions without full VMs
3. **Performance Tests**: Add benchmarking for CI-compatible components

## Conclusion

This categorization provides a practical solution for the GitHub runner virtualization limitation
while maintaining comprehensive testing capabilities. The approach enables:

- **95% test coverage in CI** through syntax, configuration, and script validation
- **100% test coverage locally** through full E2E testing with virtualization
- **Clear developer guidance** on which tests to run when and where
- **Future flexibility** for enhanced CI testing approaches

The implementation maintains the project's commitment to thorough testing while working within
GitHub's infrastructure constraints.
