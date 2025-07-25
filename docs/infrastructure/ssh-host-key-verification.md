# SSH Host Key Verification Issues

This document explains the SSH host key verification warnings that occur during VM
development and how to resolve them.

## Problem Description

When running `make test` or redeploying VMs, you may see this SSH warning:

```text
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
Someone could be eavesdropping on you right now (man-in-the-middle attack)!
It is also possible that a host key has just been changed.
The fingerprint for the ED25519 key sent by the remote host is
SHA256:+Nz297ofVtHngVzqvoWG+2uimLW4xtjVCf9BPVw8uQg.
Please contact your system administrator.
Add correct host key in /home/user/.ssh/known_hosts to get rid of this message.
Offending ECDSA key in /home/user/.ssh/known_hosts:198
  remove with:
  ssh-keygen -f '/home/user/.ssh/known_hosts' -R '192.168.122.25'
Password authentication is disabled to avoid man-in-the-middle attacks.
```

## Why This Happens

This is **normal behavior** in VM development environments because:

1. **VMs get destroyed and recreated** with new SSH host keys
2. **IP addresses get reused** by the DHCP server (libvirt assigns IPs like `192.168.122.25`)
3. **SSH remembers old host keys** in `~/.ssh/known_hosts` for security
4. **New VM has different host key** for the same IP, triggering the security warning

## Solutions

### Option 1: Automatic Cleanup (Recommended)

The project includes automatic SSH known_hosts cleanup:

```bash
# Clean SSH known_hosts for current VM
make ssh-clean

# Clean and test SSH connectivity
make ssh-prepare

# Clean all libvirt network entries
./infrastructure/scripts/ssh-utils.sh clean-all
```

### Option 2: Manual Cleanup

If you encounter the warning, follow the SSH suggestion:

```bash
# Remove the specific IP from known_hosts (replace with your VM's IP)
ssh-keygen -f ~/.ssh/known_hosts -R 192.168.122.25
```

### Option 3: One-Time Manual Connection

Connect once with StrictHostKeyChecking disabled to accept the new key:

```bash
# Replace with your VM's IP address
ssh -o StrictHostKeyChecking=no torrust@192.168.122.25
```

## Automatic Prevention

The infrastructure scripts now automatically clean SSH known_hosts during deployment:

- **During `make infra-apply`**: Cleans libvirt network range before deployment
- **After VM creation**: Cleans specific VM IP from known_hosts
- **SSH utilities**: Available via `make ssh-clean` and `make ssh-prepare`

## Understanding the Security Implications

### Why SSH Shows This Warning

SSH host key verification protects against:

- Man-in-the-middle attacks
- Server impersonation
- Connection hijacking

### Why It's Safe to Ignore in Development

For local VM development, this warning can be safely ignored because:

1. **Local network**: VMs run on isolated libvirt network (`192.168.122.0/24`)
2. **Development environment**: Not production traffic
3. **Known behavior**: Expected when VMs are recreated
4. **Controlled environment**: You control the VM creation process

### Production Considerations

In production environments:

- **Keep host key verification enabled**
- **Investigate unexpected key changes**
- **Use static IP assignments when possible**
- **Consider certificate-based authentication**

## Technical Implementation

The SSH utilities script (`infrastructure/scripts/ssh-utils.sh`) provides:

- **`clean_vm_known_hosts()`**: Remove entries for specific VM IP
- **`clean_libvirt_known_hosts()`**: Clean entire libvirt network range
- **`prepare_vm_ssh()`**: Automated cleanup and connectivity testing
- **`get_vm_ip()`**: VM IP detection from Terraform/libvirt

## Related Documentation

- [ADR-005: Sudo Cache Management](../adr/005-sudo-cache-management-for-infrastructure-operations.md)  
  Related infrastructure UX improvements
- [Local Testing Setup](../infrastructure/local-testing-setup.md) -
  Complete development environment setup
- [Integration Testing Guide](../guides/integration-testing-guide.md) - Full testing procedures

## Quick Reference

| Command                   | Purpose                                     |
| ------------------------- | ------------------------------------------- |
| `make ssh-clean`          | Clean known_hosts for current VM            |
| `make ssh-prepare`        | Clean known_hosts and test SSH connectivity |
| `ssh-utils.sh clean-all`  | Clean entire libvirt network range          |
| `ssh-utils.sh clean [IP]` | Clean specific IP address                   |
| `ssh-utils.sh get-ip`     | Get current VM IP address                   |
