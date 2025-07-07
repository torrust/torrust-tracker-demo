<!-- markdownlint-disable MD013 -->

# SSH Authentication Bug Analysis Summary

**Date:** July 4, 2025  
**Status:** ✅ RESOLVED - ROOT CAUSE CONFIRMED

## Problem Description

The full cloud-init configuration (`user-data.yaml.tpl`) for the Torrust Tracker
Demo VM causes SSH authentication failures for both SSH key and password
authentication. The issue manifests as:

- SSH connection attempts time out or are rejected
- Both SSH key authentication and password authentication fail
- VM appears to be running normally (gets IP, port 22 is open, SSH daemon is
  running)
- UFW firewall shows SSH is allowed

## ROOT CAUSE IDENTIFIED AND CONFIRMED ✅

**CONFIRMED**: The YAML document start marker ("---") was causing cloud-init to
process the configuration incorrectly, leading to SSH authentication failures.

**EVIDENCE**:

- **user-data.yaml.tpl** (BROKEN): Uses "---" as the first line → SSH
  authentication fails
- **user-data-test-header.yaml.tpl** (FIXED): Uses "#cloud-config" as the first
  line → SSH authentication works perfectly

**VALIDATION RESULTS**:

- ✅ SSH Key Authentication: Works perfectly
- ✅ Password Authentication: Works perfectly (password: torrust123)
- ✅ All cloud-init features: Applied correctly (Docker, UFW, packages, etc.)

**CONCLUSION**: The cloud-init parser requires "#cloud-config" as the first
line, not the YAML document start marker "---". Using "---" causes the entire
configuration to be misprocessed, breaking SSH setup while other features may
still work partially.

## Current Knowledge

### Working Components (Confirmed through incremental testing)

1. **Basic user setup** (`user-data-minimal.yaml.tpl`) - SSH ✅
2. **torrust user creation** (`user-data-test-1.1.yaml.tpl`) - SSH ✅
3. **Basic packages installation** (`user-data-test-2.1.yaml.tpl`) - SSH ✅
4. **SSH configuration and restart** (`user-data-test-3.1.yaml.tpl`,
   `user-data-test-3.2.yaml.tpl`) - SSH ✅
5. **UFW firewall configuration** (`user-data-test-5.1.yaml.tpl`) - SSH ✅
6. **System reboot** (`user-data-test-7.1.yaml.tpl`) - SSH ✅
7. **Fail2ban** (`user-data-test-8.1.yaml.tpl`) - SSH ✅
8. **Docker installation and configuration** (`user-data-test-9.1.yaml.tpl`) - SSH ✅
9. **Sysctl network optimizations** (`user-data-test-10.1.yaml.tpl`) - SSH ✅
10. **Unattended-upgrades** (`user-data-test-11.1.yaml.tpl`) - SSH ✅
11. **Torrust packages** (`user-data-test-12.1.yaml.tpl`) - SSH ✅
12. **Docker Compose V2** (`user-data-test-13.1.yaml.tpl`) - SSH ✅
13. **UFW additional rules** (`user-data-test-14.1.yaml.tpl`) - SSH ✅
14. **Docker restart** (`user-data-test-15.1.yaml.tpl`) - SSH ✅

### Suspect Components (Not yet isolated)

Based on the difference between the last working config
(`user-data-test-7.1.yaml.tpl`) and the full config (`user-data.yaml.tpl`),
the following components are suspects:

1. **fail2ban** - Could be blocking SSH connections
2. **Docker installation and configuration** - Could interfere with networking
3. **sysctl network optimizations** - Could affect SSH connections
4. **unattended-upgrades** - Could interfere during setup
5. **Docker daemon restart** - Could cause timing issues

## Testing Methodology

Using incremental testing approach:

- Start with last known working config (`user-data-test-7.1.yaml.tpl`)
- Add one suspect component at a time
- Test SSH after each addition
- Identify the exact component that breaks SSH

## Test Results So Far

| Config       | Components Added          | SSH Key | SSH Password | Status     |
| ------------ | ------------------------- | ------- | ------------ | ---------- |
| minimal      | ubuntu user only          | ✅      | ✅           | Working    |
| test-1.1     | + torrust user            | ✅      | ✅           | Working    |
| test-2.1     | + basic packages          | ✅      | ✅           | Working    |
| test-3.1/3.2 | + SSH config/restart      | ✅      | ✅           | Working    |
| test-5.1     | + UFW firewall            | ✅      | ✅           | Working    |
| test-7.1     | + reboot                  | ✅      | ✅           | Working    |
| test-8.1     | + fail2ban                | ✅      | ✅           | Working    |
| test-9.1     | + Docker                  | ✅      | ✅           | Working    |
| test-10.1    | + sysctl optimizations    | ✅      | ✅           | Working    |
| test-11.1    | + unattended-upgrades     | ✅      | ✅           | Working    |
| test-12.1    | + Torrust packages        | ✅      | ✅           | Working    |
| test-13.1    | + Docker Compose V2       | ✅      | ✅           | Working    |
| test-14.1    | + UFW additional rules    | ✅      | ✅           | Working    |
| test-15.1    | + Docker restart          | ✅      | ✅           | Working    |
| **full**     | + ALL COMPONENTS COMBINED | ❌      | ❌           | **BROKEN** |

## CRITICAL DISCOVERY - CONFIRMED!

🚨 **ALL INDIVIDUAL COMPONENTS WORK!** 🚨  
✅ **FULL CONFIGURATION FAILS!** ✅

**CONFIRMATION TEST RESULTS:**

- **Full Config VM IP:** 192.168.122.6
- **SSH Key Authentication:** ❌ Permission denied (publickey)
- **SSH Password Authentication:** ❌ Permission denied (publickey)
- **Port 22 Status:** ✅ Open and listening
- **SSH Daemon:** ✅ Running

This **confirms our hypothesis** that the SSH failure is NOT caused by any  
individual component, but rather by the combination of all components together.

We have systematically tested **EVERY SINGLE COMPONENT** from the full configuration  
individually, and they all work perfectly. This means the SSH failure is NOT caused by  
any individual component, but rather by:

1. **Component interactions** - Multiple components interfering with each other
2. **Timing issues** - Race conditions between services during startup
3. **Configuration ordering** - The sequence of operations matters
4. **Cumulative effects** - The combination of all components together

## Next Steps

1. **Test fail2ban** - Add fail2ban package and default config to test-7.1 ✅ **PASSED**
2. **Test Docker** - Add Docker installation and configuration ✅ **PASSED**
3. **Test sysctl** - Add network optimizations ✅ **PASSED**
4. **Test unattended-upgrades** - Add automatic updates configuration ✅ **PASSED**
5. **Test Torrust packages** - Add pkg-config, libssl-dev, make, build-essential,  
   libsqlite3-dev, sqlite3 ✅ **PASSED**
6. **Test Docker Compose installation** - Add Docker Compose V2 plugin installation ✅ **PASSED**
7. **Test additional UFW rules** - Add Torrust-specific firewall rules ✅ **PASSED**
8. **Test Docker restart** - Add Docker daemon restart command ✅ **PASSED**

## NEW INVESTIGATION STRATEGY

Since all individual components work, we need to investigate:

1. **Test exact full configuration** - Deploy the exact full config and debug
2. **Compare configurations** - Find subtle differences between working incremental tests and full config
3. **Timing analysis** - Investigate service startup timing and dependencies
4. **Component interaction analysis** - Test combinations of components

## Hypotheses - UPDATED AFTER DISCOVERY

**ALL INDIVIDUAL COMPONENTS HAVE BEEN RULED OUT!**

1. **fail2ban blocking SSH** - ❌ **RULED OUT** - Test 8.1 passed
2. **Docker network interference** - ❌ **RULED OUT** - Test 9.1 passed
3. **sysctl optimizations** - ❌ **RULED OUT** - Test 10.1 passed
4. **unattended-upgrades** - ❌ **RULED OUT** - Test 11.1 passed
5. **Additional Torrust packages** - ❌ **RULED OUT** - Test 12.1 passed
6. **Docker Compose installation** - ❌ **RULED OUT** - Test 13.1 passed
7. **Additional UFW rules** - ❌ **RULED OUT** - Test 14.1 passed
8. **Docker restart command** - ❌ **RULED OUT** - Test 15.1 passed

**NEW HYPOTHESES - ROOT CAUSE ANALYSIS:**

1. **Component interactions** - ⚠️ **LIKELY** - Multiple components interfering
2. **Timing issues** - ⚠️ **LIKELY** - Race conditions during startup
3. **Service dependencies** - ⚠️ **LIKELY** - Services starting in wrong order
4. **Cumulative resource usage** - ⚠️ **POSSIBLE** - Memory/CPU constraints
5. **Configuration file conflicts** - ⚠️ **POSSIBLE** - Overlapping configs
6. **SSH service restart timing** - ⚠️ **POSSIBLE** - SSH restart conflicts with other services

## Technical Details

- **VM Environment**: libvirt/KVM with Ubuntu 24.04 cloud image
- **SSH Configuration**: Both key and password authentication enabled
- **Network**: UFW firewall with SSH explicitly allowed
- **Testing Tools**: ssh, sshpass, nc, virsh net-dhcp-leases

## Files Created

- `user-data-minimal.yaml.tpl` - Baseline working config
- `user-data-test-1.1.yaml.tpl` - + torrust user
- `user-data-test-2.1.yaml.tpl` - + basic packages
- `user-data-test-3.1.yaml.tpl` - + SSH config
- `user-data-test-3.2.yaml.tpl` - + SSH restart
- `user-data-test-5.1.yaml.tpl` - + UFW firewall
- `user-data-test-7.1.yaml.tpl` - + reboot
- `user-data.yaml.tpl` - Full config (broken)

## Current Action

Creating incremental tests to isolate the exact component causing SSH failure.

## 🎉 FINAL RESOLUTION AND SUCCESS ✅

**DATE:** July 4, 2025  
**STATUS:** ✅ COMPLETELY RESOLVED

### Root Cause Confirmed

The SSH authentication failure in the Torrust Tracker Demo VM was caused by **the YAML document start marker (`---`) at the beginning of the cloud-init configuration file**.

### The Fix

**Simple but Critical Change:**

```yaml
# BEFORE (BROKEN):
---
# cloud-config

# AFTER (FIXED):
#cloud-config
```

### Validation Results

**Fresh deployment using make commands:**

1. `make destroy` - Clean slate
2. `make init` - Initialize OpenTofu
3. `make plan` - Verified SSH key templating is correct
4. `make apply` - Deployed fresh VM

**Authentication Test Results:**

- ✅ **SSH Key Authentication**: `ssh torrust@192.168.122.172` - SUCCESS
- ✅ **Password Authentication**: `sshpass -p 'torrust123' ssh torrust@192.168.122.172` - SUCCESS
- ✅ **All Cloud-Init Features**: Docker, UFW, packages, etc. - ALL WORKING

### Technical Details

**The Problem:**

- Cloud-init parser expects `#cloud-config` as the first line
- Using YAML document start marker `---` causes the entire configuration to be misprocessed
- This breaks SSH key templating (`${ssh_public_key}` becomes `None`)
- Results in empty `ssh_authorized_keys` and authentication failures

**The Solution:**

- Replace `---` with `#cloud-config` at the beginning of `user-data.yaml.tpl`
- This ensures proper cloud-init parsing and SSH key templating
- All other cloud-init features continue to work correctly

### Impact

This fix resolves the SSH authentication issue that was preventing users from accessing the Torrust Tracker Demo VM. The infrastructure is now working as designed with both SSH key and password authentication enabled.

**Files Fixed:**

- `infrastructure/cloud-init/user-data.yaml.tpl` - Header changed from `---` to `#cloud-config`

**Deployment Method:**

- Standard make commands work perfectly: `make init`, `make plan`, `make apply`
- Integration testing workflow is fully operational

## ROOT CAUSE IDENTIFIED AND CONFIRMED ✅
