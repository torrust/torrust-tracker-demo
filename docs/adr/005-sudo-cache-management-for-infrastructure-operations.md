# ADR-005: Sudo Cache Management for Infrastructure Operations

## Status

Accepted

## Context

During infrastructure testing, specifically when running `make test`, users experienced poor UX due to
sudo password prompts being mixed with other command output. This created several problems:

1. **Mixed Output**: The sudo password prompt appeared in the middle of verbose OpenTofu output,
   making it difficult to notice
2. **Test Hangs**: Users would miss the password prompt, causing tests to hang indefinitely
3. **Unclear Timing**: Users didn't know when sudo access would be needed during the test process
4. **Interrupted Flow**: Password prompts appeared at unpredictable times during infrastructure
   provisioning

### Technical Root Cause

The issue occurred during OpenTofu's `local-exec` provisioner execution in
`infrastructure/terraform/main.tf`:

```hcl
# Fix permissions after creation
provisioner "local-exec" {
  command = "${path.module}/../scripts/fix-volume-permissions.sh"
}
```

This script runs `sudo` commands for libvirt volume permission management, but the password prompt
was buried in OpenTofu's verbose output.

## Decision

We chose **Option 1: Pre-authorize sudo with timeout and clear user messaging**.

### Implemented Solution

1. **Sudo Cache Management Functions** in `scripts/shell-utils.sh`:

   - `is_sudo_cached()` - Check if sudo credentials are cached
   - `ensure_sudo_cached(description)` - Warn user and cache sudo credentials
   - `run_with_sudo(description, command)` - Run command with pre-cached sudo
   - `clear_sudo_cache()` - Clear sudo cache for testing

2. **Proactive Sudo Preparation**:

   - Cache sudo credentials before infrastructure operations begin
   - Clear user messaging about when and why sudo is needed
   - Use harmless `sudo -v` command to cache without executing privileged operations

3. **Integration Points**:
   - `tests/test-e2e.sh`: Prepare sudo cache before infrastructure provisioning
   - `infrastructure/scripts/provision-infrastructure.sh`: Cache sudo before `tofu apply`
   - `infrastructure/scripts/fix-volume-permissions.sh`: Use cached sudo for operations

### User Experience Improvement

**Before:**

```bash
make test
# ... lots of OpenTofu output ...
libvirt_volume.base_image (local-exec): Fixing libvirt volume permissions...
[sudo] password for user: # <- Hidden in output, easy to miss
```

**After:**

```bash
make test
⚠️  SUDO PREPARATION
Infrastructure provisioning requires administrator privileges
[sudo] password for user: # <- Clear, upfront prompt
✓ Administrator privileges confirmed and cached
# ... rest runs without interruption ...
```

## Alternatives Considered

### Option 1: Pre-authorize sudo with timeout ⭐ (CHOSEN)

- **Pros**: Safe, minimal changes, clear UX, leverages existing sudo timeout
- **Cons**: Still requires password entry once

### Option 2: Passwordless sudo configuration

- **Pros**: No password prompts during tests
- **Cons**: Security risk, requires system configuration changes, complex setup

### Option 3: Replace local-exec with null_resource

- **Pros**: Better output control
- **Cons**: Still needs sudo password, more complex Terraform

### Option 4: Move permission fixes to cloud-init

- **Pros**: No host sudo needed
- **Cons**: Complex implementation, may not solve all permission issues

### Option 5: Enhanced messaging only

- **Pros**: Simple implementation
- **Cons**: Doesn't solve the core mixing problem

### Option 6: Use polkit/pkexec

- **Pros**: GUI prompts, better UX
- **Cons**: Complex setup, environment dependencies

### Option 7: Automated passwordless sudo setup

- **Pros**: One-time setup eliminates problem
- **Cons**: Security implications, system configuration complexity

## Rationale

Option 1 was chosen because it:

1. **Maintains Security**: Uses standard sudo timeout without permanent passwordless access
2. **Minimal Risk**: Uses safe `sudo -v` command that doesn't execute privileged operations
3. **Clear UX**: Users know exactly when and why password is needed
4. **Simple Implementation**: Leverages existing sudo cache mechanism (~15 minutes)
5. **Backwards Compatible**: Doesn't require system configuration changes
6. **Universal**: Works across different Linux distributions and environments

## Implementation Details

### Core Functions (`scripts/shell-utils.sh`)

```bash
# Check if sudo credentials are cached
is_sudo_cached() {
    sudo -n true 2>/dev/null
}

# Warn user and ensure sudo is cached
ensure_sudo_cached() {
    local operation_description="${1:-the operation}"

    if is_sudo_cached; then
        return 0
    fi

    log_warning "The next step requires administrator privileges"
    log_info "You may be prompted for your password to ${operation_description}"

    # Use harmless sudo command to cache credentials
    if sudo -v; then
        log_success "Administrator privileges confirmed"
        return 0
    else
        log_error "Failed to obtain administrator privileges"
        return 1
    fi
}
```

### Integration Pattern

```bash
# Before any infrastructure operation that needs sudo
if ! ensure_sudo_cached "provision libvirt infrastructure"; then
    log_error "Cannot proceed without administrator privileges"
    exit 1
fi

# Now run operations that need sudo - no prompts expected
sudo chown -R libvirt-qemu:libvirt /var/lib/libvirt/images/
```

## Consequences

### Positive

- **Better UX**: Clear, predictable password prompts
- **No Mixed Output**: Password prompt happens before verbose operations
- **Faster Tests**: No hanging due to missed prompts
- **Security Maintained**: Uses standard sudo timeout mechanism
- **Universal**: Works in all environments without special setup

### Negative

- **Still Requires Password**: Users must enter password once per test session
- **Cache Dependency**: Relies on system sudo timeout (usually 15 minutes)
- **Additional Code**: Added complexity in shell utilities

### Neutral

- **Test Duration**: No impact on test execution time
- **Security Posture**: Maintains existing security model
- **Maintenance**: Minimal ongoing maintenance required

## Monitoring

Success of this decision can be measured by:

1. **Reduced Support Issues**: Fewer reports of hanging tests or missed prompts
2. **Contributor Feedback**: Improved developer experience feedback
3. **Test Reliability**: More consistent test execution without manual intervention

## Related Decisions

- [ADR-001: Makefile Location](001-makefile-location.md) - Central automation interface
- [ADR-002: Docker for All Services](002-docker-for-all-services.md) - Service architecture

## References

- Original issue discussion with password prompt mixing
- Shell utilities implementation in `scripts/shell-utils.sh`
- Integration testing guide documentation
- Sudo cache timeout documentation: `man sudo`
