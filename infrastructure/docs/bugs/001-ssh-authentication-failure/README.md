# SSH Authentication Failure Bug - #001

**Date Resolved:** July 4, 2025  
**Status:** ✅ Resolved  
**Impact:** High - Blocked VM access completely  
**Root Cause:** YAML document start marker (`---`) breaking cloud-init parsing

## Problem Summary

The full cloud-init configuration (`user-data.yaml.tpl`) for the Torrust Tracker
Demo VM was causing SSH authentication failures for both SSH key and password
authentication, preventing users from accessing deployed VMs.

## Root Cause

The issue was caused by using the YAML document start marker (`---`) at the
beginning of the cloud-init configuration file instead of the required
`#cloud-config` header. This caused cloud-init to misprocess the entire
configuration, resulting in:

- Empty SSH authorized_keys (SSH key variable not templated)
- Broken password authentication setup
- Schema validation errors in cloud-init

## The Fix

**Simple but Critical Change:**

```yaml
# BEFORE (BROKEN):
---
# cloud-config

# AFTER (FIXED):
#cloud-config
```

**File Changed:** `infrastructure/cloud-init/user-data.yaml.tpl`

## Investigation Process

This bug was resolved through systematic incremental testing:

1. **Incremental Testing**: Created 15+ test configurations, adding features one by one
2. **Root Cause Isolation**: Compared working vs. broken configurations using diff analysis
3. **Hypothesis Formation**: Identified YAML header as the key difference
4. **Validation**: Deployed fresh VM with corrected header and confirmed fix

## Validation Results

After applying the fix:

- ✅ SSH Key Authentication: Works perfectly
- ✅ Password Authentication: Works perfectly
- ✅ All Cloud-Init Features: Docker, UFW, packages, etc. - ALL WORKING
- ✅ Integration Tests: Complete test suite passes
- ✅ Make Commands: Standard workflow (`make init`, `make plan`, `make apply`) works

## Files in This Directory

### Core Documentation

- `SSH_BUG_ANALYSIS.md` - Initial analysis and hypothesis formation
- `SSH_BUG_SUMMARY.md` - Complete investigation summary with detailed timeline

### Test Artifacts

- `test-configs/` - All 16 test configurations used during incremental testing
  - `user-data-test-1.1.yaml.tpl` through `user-data-test-15.1.yaml.tpl`
  - `user-data-test-header.yaml.tpl` - Final test that confirmed the fix

### Validation

- `validation/` - (Currently empty, reserved for future validation scripts)

## Lessons Learned

1. **Cloud-init requires specific headers**: `#cloud-config` is mandatory, not `---`
2. **Incremental testing is powerful**: Systematic approach isolated the issue effectively
3. **Template variable validation**: Always verify that template variables are being substituted correctly
4. **Integration testing is crucial**: End-to-end testing revealed the full scope of the issue

## Prevention

To prevent similar issues:

- Always use `#cloud-config` as the first line in cloud-init files
- Test template variable substitution in terraform plans
- Run integration tests after any cloud-init configuration changes
- Use the documented make workflow for deployments

## Related Issues

This fix resolves SSH access problems that were preventing users from following
the integration testing guide and deploying the Torrust Tracker Demo
successfully.

## Technical Details

For complete technical details, debugging methodology, and step-by-step
investigation process, see:

- [SSH_BUG_ANALYSIS.md](SSH_BUG_ANALYSIS.md) - Initial investigation
- [SSH_BUG_SUMMARY.md](SSH_BUG_SUMMARY.md) - Comprehensive analysis with timeline
