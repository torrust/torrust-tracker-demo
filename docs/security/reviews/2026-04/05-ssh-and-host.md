# SSH and Host - 2026-04

**Summary**: [README.md](README.md)
**Progress**: [progress.md](progress.md)

## Scope

- SSH exposure and authentication policy
- Reachable host services
- User and sudo access
- Firewall and host-level hardening
- Patch and package posture

## Hypotheses

- SSH is intentionally exposed on both IPv4 and IPv6, but the actual
  authentication policy and host-hardening posture cannot be confirmed from the
  repository alone.
- Host-level service exposure may differ from the UFW rule files because
  Docker-published ports bypass normal UFW filtering.

## Evidence Reviewed

- [../../../server/etc/ufw/user.rules](../../../server/etc/ufw/user.rules)
- [../../../server/etc/ufw/user6.rules](../../../server/etc/ufw/user6.rules)
- [../../../server/etc/ufw/before6.rules](../../../server/etc/ufw/before6.rules)
- [../../../server/opt/torrust/docker-compose.yml](../../../server/opt/torrust/docker-compose.yml)
- [../../../docs/infrastructure.md](../../../docs/infrastructure.md)

## Checks Performed

- Confirmed UFW explicitly allows inbound TCP `22` on both IPv4 and IPv6.
- Confirmed UFW explicitly allows inbound UDP `6969` on both IPv4 and IPv6.
- Confirmed the IPv6 rules include a manual SNAT rule for Docker UDP tracker
  replies on port `6969`.
- Confirmed the compose comments document that Docker-published ports bypass
  the usual UFW filtering model.
- Confirmed no repo-side evidence yet for `sshd_config`, SSH key policy,
  password-auth settings, host package updates, or other host service bindings.

## Findings or Non-Findings

- No confirmed finding yet from repository evidence alone. The repo confirms
  intended SSH exposure and special IPv6/Docker handling, but not the host's
  actual authentication, patch, or service-hardening posture.

## Open Questions

- Is password authentication disabled in SSH?
- Are root login and sudo access restricted as expected?
- Which host services are actually listening, beyond the repo's intended
  configuration?
- Is the host patched and current on security updates?

## Next Actions

- Collect `sshd_config`, `ss -tulpn`, and package update status from the live
  host.
- Compare the intended UFW rules with actual listening sockets and reachable
  services.
