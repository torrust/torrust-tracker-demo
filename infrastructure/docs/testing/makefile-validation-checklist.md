# Makefile Validation Checklist

This document tracks the comprehensive testing of all Makefile targets to ensure
they work correctly and provide the expected output.

## Epic Overview

**Goal**: Test all 27 Makefile targets systematically, ensuring each works as
expected and handles edge cases appropriately.

**Status**: 🟡 In Progress

---

## Phase 1: Prerequisites and Basic Setup

### 1.1 Environment Validation

- [x] Test `make help` - Verify help message displays correctly ✅
- [x] Test `make workflow-help` - Verify workflow guidance is clear ✅
- [x] Check current system state - Document starting conditions ✅

### 1.2 Dependency Management

- [ ] Test `make install-deps` (if not already installed)
  - [ ] Verify OpenTofu installation
  - [ ] Verify libvirt/KVM installation
  - [ ] Verify user group membership
  - [ ] Check service status
- [ ] Test `make check-libvirt` - Verify libvirt status check
- [ ] Test `make fix-libvirt` - Verify permission fixes work
- [ ] Test `make test-prereq` - Verify prerequisite validation

### 1.3 Development Setup

- [ ] Test `make dev-setup` - Complete development environment setup
- [ ] Test `make setup-ssh-key` - SSH key configuration
- [ ] Verify SSH key configuration is properly created

---

## Phase 2: Syntax and Configuration Testing

### 2.1 Configuration Validation

- [ ] Test `make test-syntax` - Validate all configuration files
- [ ] Test `make ci-test-syntax` - CI-specific syntax validation
- [ ] Test `make quick-test` - Quick validation without deployment

### 2.2 OpenTofu/Terraform Operations

- [ ] Test `make init` - Initialize OpenTofu
- [ ] Test `make plan` - Verify infrastructure planning
  - [ ] Test with valid SSH key configuration
  - [ ] Test without SSH key configuration (should fail gracefully)

---

## Phase 3: VM Lifecycle Management

### 3.1 VM Deployment

- [ ] Test `make apply-minimal` - Deploy VM with minimal configuration
  - [ ] Verify VM starts successfully
  - [ ] Verify SSH access works
  - [ ] Document VM status and capabilities
- [ ] Test `make apply` - Deploy VM with full configuration
  - [ ] Verify cloud-init completes successfully
  - [ ] Verify all services are installed and running
  - [ ] Document differences from minimal deployment

### 3.2 VM Management

- [ ] Test `make status` - Check infrastructure status
- [ ] Test `make ssh` - SSH connectivity
  - [ ] Test successful connection
  - [ ] Test failure when VM not deployed
- [ ] Test `make vm-restart` - VM restart functionality
- [ ] Test `make monitor-cloud-init` - Real-time monitoring

### 3.3 VM Cleanup

- [ ] Test `make destroy` - VM destruction
  - [ ] Verify complete cleanup
  - [ ] Verify state files are properly managed
- [ ] Test `make clean` - Temporary file cleanup
- [ ] Test `make clean-and-fix` - Complete cleanup and reset

---

## Phase 4: Testing and Validation

### 4.1 Test Suite Execution

- [ ] Test `make test` - Full test suite
  - [ ] Document test execution time
  - [ ] Verify all test components run
  - [ ] Check test output and logs
- [ ] Test `make test-integration` - Integration tests with deployed VM
- [ ] Test `make deploy-test` - Test deployment for validation

### 4.2 Workflow Testing

- [ ] Test `make restart-and-monitor` - Complete restart workflow
- [ ] Test `make fresh-start` - Alias verification

---

## Phase 5: Edge Cases and Error Handling

### 5.1 Error Conditions

- [ ] Test targets without prerequisites
  - [ ] SSH without deployed VM
  - [ ] Plan without SSH key configuration
  - [ ] Integration tests without VM
- [ ] Test with corrupted state files
- [ ] Test with permission issues
- [ ] Test with missing dependencies

### 5.2 Recovery Scenarios

- [ ] Test recovery from failed deployments
- [ ] Test multiple VM cleanup scenarios
- [ ] Test permission recovery

---

## Phase 6: Documentation and Validation

### 6.1 Output Validation

- [ ] Verify all help messages are accurate
- [ ] Verify error messages are helpful
- [ ] Document expected vs actual behavior for each target

### 6.2 Performance Testing

- [ ] Measure deployment times for different configurations
- [ ] Test concurrent operations (if applicable)
- [ ] Document resource usage

---

## Testing Notes and Observations

### System State at Start

- **OS**: Linux (detected from environment)
- **Date**: Jul 1, 2025 16:15:36 WEST
- **User**: josecelano
- **Groups**: josecelano adm cdrom sudo dip plugdev users lpadmin vboxusers
  libvirt docker kvm
- **Current Branch**: `10-provision-new-hetzner-vm`
- **Working Directory**:
  `/home/josecelano/Documents/git/committer/me/github/torrust/torrust-tracker-demo`
- **Git Status**: Clean working tree

### Dependencies Status

- **OpenTofu**: Yes (installed)
- **libvirtd**: active
- **KVM**: Available
- **User Groups**: Already in libvirt, kvm, and docker groups

### Test Results Log

#### Phase 1 Results

To be filled during testing

#### Phase 2 Results

To be filled during testing

#### Phase 3 Results

To be filled during testing

#### Phase 4 Results

To be filled during testing

#### Phase 5 Results

To be filled during testing

#### Phase 6 Results

To be filled during testing

---

## Issues Found

### Critical Issues

List any critical issues that prevent normal operation

### Minor Issues

List any minor issues or improvements needed

### Documentation Issues

List any documentation that needs updates

---

## Final Summary

To be completed at the end of testing

- **Total Targets Tested**: 3/27
- **Successful**: 3
- **Failed**: 0
- **Needs Investigation**: 0
- **Documentation Updates Needed**: 0

---

## Next Steps

After completing this testing:

1. Fix any identified issues
2. Update documentation based on findings
3. Create issues for improvements
4. Update Makefile help text if needed
5. Consider adding additional targets based on gaps found
