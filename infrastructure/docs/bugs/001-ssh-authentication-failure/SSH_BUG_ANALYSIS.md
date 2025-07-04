<!-- markdownlint-disable MD013 -->

# SSH Authentication Bug Analysis - Cloud-Init Configuration

## Problem Summary

The full cloud-init configuration (`user-data.yaml.tpl`) for the Torrust Tracker Demo VM causes SSH authentication failures. Both SSH key and password authentication are denied, preventing access to the deployed VM.

## Current Status

- **Baseline**: Minimal config works perfectly (SSH key + password auth)
- **Problem**: Full config breaks SSH completely (connection refused/denied)
- **Goal**: Identify the exact component causing SSH failure

## Test Results Summary

### ✅ Working Configurations (SSH Access Confirmed)

| Test         | Description            | Config File                       | SSH Key | SSH Password | Notes              |
| ------------ | ---------------------- | --------------------------------- | ------- | ------------ | ------------------ |
| Baseline     | Minimal config         | `user-data-minimal.yaml.tpl`      | ✅      | ✅           | Perfect baseline   |
| Test 1.1     | Switch to torrust user | `user-data-test-1.1.yaml.tpl`     | ✅      | ✅           | User config OK     |
| Test 2.1     | Add basic packages     | `user-data-test-2.1.yaml.tpl`     | ✅      | ✅           | Package install OK |
| Test 3.1/3.2 | SSH config + restart   | `user-data-test-3.1/3.2.yaml.tpl` | ✅      | ✅           | SSH config OK      |
| Test 5.1     | Add UFW firewall       | `user-data-test-5.1.yaml.tpl`     | ✅      | ✅           | UFW rules OK       |
| Test 7.1     | Add reboot             | `user-data-test-7.1.yaml.tpl`     | ✅      | ✅           | Reboot OK          |

### ❌ Failing Configuration

| Test | Description     | Config File          | SSH Key | SSH Password | Notes                  |
| ---- | --------------- | -------------------- | ------- | ------------ | ---------------------- |
| Full | Complete config | `user-data.yaml.tpl` | ❌      | ❌           | Both auth methods fail |

## Technical Analysis

### Network Connectivity

- VM gets IP address via DHCP (confirmed)
- SSH port 22 is open (nmap confirms)
- UFW is not blocking SSH (rules allow port 22)
- SSH daemon is running (telnet connects to port 22)

### SSH Daemon Status

- SSH service is active and running
- Port 22 is listening
- However, authentication is denied for both methods
- Error: "Permission denied (publickey,password)"

### What We've Ruled Out

1. **Network/Firewall**: UFW allows SSH, port is open
2. **SSH Service**: Daemon is running and accepting connections
3. **User Configuration**: torrust user exists with proper groups
4. **Basic Packages**: Standard package installation doesn't break SSH
5. **Reboot**: System reboot doesn't affect SSH access

## Suspect Components (Not Yet Tested)

Based on the difference between working Test 7.1 and failing full config:

### 1. **fail2ban** (HIGH PRIORITY)

- **Risk**: Could be blocking SSH attempts
- **Mechanism**: Might ban localhost/initial connections
- **Test needed**: Add fail2ban to working config

### 2. **Docker Installation/Configuration** (HIGH PRIORITY)

- **Risk**: Docker daemon.json or service conflicts
- **Mechanism**: Could affect networking or SSH service
- **Test needed**: Add Docker components separately

### 3. **sysctl Network Tuning** (MEDIUM PRIORITY)

- **Risk**: Network parameter changes could affect SSH
- **Mechanism**: TCP/networking tweaks might break SSH
- **Test needed**: Add sysctl configuration

### 4. **unattended-upgrades** (LOW PRIORITY)

- **Risk**: Could trigger system changes during boot
- **Mechanism**: Background updates might conflict
- **Test needed**: Add unattended-upgrades config

### 5. **Service Restart Timing** (MEDIUM PRIORITY)

- **Risk**: Docker restart might affect SSH
- **Mechanism**: Service interdependencies
- **Test needed**: Add Docker restart commands

## Testing Strategy

### Phase 1: Individual Component Testing

1. Test 8.1: Add fail2ban to working config
2. Test 8.2: Add Docker daemon.json to working config
3. Test 8.3: Add sysctl settings to working config
4. Test 8.4: Add unattended-upgrades to working config
5. Test 8.5: Add Docker service restarts to working config

### Phase 2: Combination Testing

- If individual components work, test combinations
- Build up to full config systematically

### Phase 3: Detailed Investigation

- If issue persists, examine logs in detail
- Check cloud-init logs, SSH logs, system logs
- Use VM console access for debugging

## Next Steps

1. ✅ **Document findings** (this file)
2. 🔄 **Create incremental test configs** for suspect components
3. 🔄 **Test each component individually**
4. 🔄 **Identify the breaking component**
5. 🔄 **Fix or work around the issue**

## Expected Outcome

We expect to identify a single component (most likely fail2ban or Docker configuration) that breaks SSH authentication. Once identified, we can either:

- Fix the component's configuration
- Reorder the installation/configuration steps
- Work around the issue with alternative approaches

---

_Analysis Date: July 4, 2025_
_Last Updated: Initial analysis_
