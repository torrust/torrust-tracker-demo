# UDP Tracker Down on newTrackon After Nightly Restart

**Issue**: [#2](https://github.com/torrust/torrust-tracker-demo/issues/2)
**Related**:
[torrust-tracker-deployer#407](https://github.com/torrust/torrust-tracker-deployer/issues/407),
[torrust-tracker-deployer#405](https://github.com/torrust/torrust-tracker-deployer/issues/405)

## Overview

The UDP tracker (`udp://udp1.torrust-tracker-demo.com:6969/announce`) was accepted by
[newTrackon](https://newtrackon.com/) shortly after the demo server was provisioned on
March 3, 2026. As of March 8, 2026 it shows as **down** and has been failing for approximately
one day.

The tracker itself is working — UDP announces succeed from external clients. The failure is
specific to the newTrackon probe, which tests via the **IPv6 floating IP**
(`2a01:4f8:1c0c:828e::1`). This is the same class of failure that was investigated and fixed
in [torrust-tracker-deployer#407](https://github.com/torrust/torrust-tracker-deployer/issues/407).

## Background

The demo server runs the Docker Compose stack produced by
[torrust-tracker-deployer](https://github.com/torrust/torrust-tracker-deployer). A `backups`
service in the stack stops and restarts the tracker container every night so that a consistent
database snapshot can be taken.

The previous investigation
([deployer#407 — ipv6-udp-tracker-issue.md](https://github.com/torrust/torrust-tracker-deployer/blob/407-submit-udp1-tracker-to-newtrackon/docs/deployments/hetzner-demo-tracker/post-provision/ipv6-udp-tracker-issue.md))
identified two root causes for the same symptom and documented the fixes:

| #   | Root Cause                                                                                     | Fix Applied                                                                | Persistent?                                                                  |
| --- | ---------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| 1   | `ufw` was blocking IPv6 UDP 6969 (Docker does not create `ip6tables` INPUT rules, unlike IPv4) | `sudo ufw allow 6969/udp`                                                  | ✅ Yes — `ufw` stores rules in `/etc/ufw/`                                   |
| 2   | Asymmetric routing: replies from the floating IP were leaving via the primary server IP        | Policy routing tables 100 (IPv4) and 200 (IPv6) via `ip rule` / `ip route` | ✅ Yes — persisted in `/etc/netplan/60-floating-ip.yaml` via `netplan apply` |

Both fixes were confirmed working and persisted before the tracker was accepted by newTrackon.
The server has **not been fully rebooted** since those fixes were applied. However, the Docker
Compose stack (including the tracker container) is **restarted every night** by the backups
service.

## Symptom

- `udp://udp1.torrust-tracker-demo.com:6969/announce` shows as ❌ on newTrackon (as of ~March 8, 2026).
- Manual UDP announces from external clients succeed (tracker is functional).
- HTTP tracker (`https://http1.torrust-tracker-demo.com:443/announce`) is unaffected.

## Hypothesis

The most likely cause is that the **nightly Docker Compose restart is interfering with the
`ip6tables` rules** that allow IPv6 UDP traffic on port 6969 through to the container.

When Docker starts or restarts containers, it rewrites its own `iptables`/`ip6tables` chain rules
(`DOCKER`, `DOCKER-FORWARD`, `DOCKER-USER`). There is a known interaction between Docker and ufw
where Docker's chain rewriting can flush or conflict with ufw's `ip6tables INPUT` rules. Specifically:

- For **IPv4**: Docker writes DNAT rules directly into `iptables` that bypass the ufw `INPUT`
  chain entirely → IPv4 UDP 6969 is not affected by the nightly restart.
- For **IPv6**: Docker does not write equivalent DNAT rules into `ip6tables`. Packets must pass
  through the ufw `INPUT` chain to reach the container. If that chain loses the `6969/udp` rule
  after a Docker chain flush, IPv6 UDP packets are silently dropped again.

A secondary (less likely) possibility is that the `netplan`-persisted policy routing rules were
somehow not re-applied, causing asymmetric routing.

## Investigation Steps

### Step 1 — Check current ufw status on the server

```bash
sudo ufw status verbose
```

Expected output should include:

```text
6969/udp                   ALLOW IN    Anywhere
6969/udp (v6)              ALLOW IN    Anywhere (v6)
```

If these lines are **missing**, ufw has lost the rules (or they were never reloaded by ufw after
a Docker chain flush). Fix: `sudo ufw allow 6969/udp` and investigate why rules were lost.

### Step 2 — Check ip6tables INPUT chain directly

Even if ufw reports the rule, verify it is actually present in the live `ip6tables`:

```bash
sudo ip6tables -L INPUT -n --line-numbers
```

Look for a rule accepting UDP port `6969`. If ufw shows the rule but `ip6tables` does not, Docker
has flushed and rewritten chains without ufw reloading its rules.

### Step 3 — Check policy routing rules are still active

```bash
ip rule list
ip route show table 100
ip -6 rule list
ip -6 route show table 200
```

Expected output includes:

```text
# ip rule list
32765:  from 116.202.177.184 lookup 100 proto static

# ip route show table 100
default via 172.31.1.1 dev eth0

# ip -6 rule list
32765:  from 2a01:4f8:1c0c:828e::1 lookup 200

# ip -6 route show table 200
default via fe80::1 dev eth0
```

If these are **missing**, `netplan apply` may need to be re-run, or there is an issue with the
netplan configuration.

### Step 4 — Capture a newTrackon probe with tcpdump

Resubmit the tracker to newTrackon and simultaneously capture traffic on the server:

```bash
sudo tcpdump -i eth0 -n udp port 6969 -v
```

- If only **incoming** packets appear (no replies) → packets are reaching `eth0` but being
  dropped before the container. Most likely ufw/ip6tables issue (see Steps 1–2).
- If both **incoming and outgoing** packets appear → the container is processing the request and
  replying. The reply source address should be `2a01:4f8:1c0c:828e::1`. If it is a different
  address → asymmetric routing issue (see Step 3).
- If **no packets** appear → packets are not arriving. Check Hetzner Cloud Firewall and DNS.

### Step 5 — Check tracker container logs during a probe

```bash
docker compose logs tracker --tail=50 --follow
```

Submit to newTrackon while this is running. If **no log entries** appear for the IPv6 probe, the
packet never reached the container (Steps 1–2 apply). If log entries appear with a successful
response, the issue is in routing (Step 3) or at the network level.

## Fix Plan

Based on investigation results:

### Fix A — If ufw ip6tables rules are missing after Docker restarts

The `ufw allow 6969/udp` rule is stored persistently in `/etc/ufw/` but ufw may not automatically
reload its `ip6tables` rules when Docker flushes and rewrites its chains.

Options (in order of preference):

1. **Use a ufw + Docker workaround** — configure Docker to not manage `iptables` for the relevant
   interfaces, or use the `DOCKER-USER` chain to allow the traffic. This keeps both ufw and Docker
   working without conflicts.
2. **Add a post-restart hook** — add a systemd oneshot unit or Docker Compose `post-start` hook
   that runs `ufw reload` after the tracker container starts each night.
3. **Re-apply manually** — `sudo ufw reload` restores ufw's ip6tables rules without changing any
   configuration.

### Fix B — If policy routing rules are missing

Re-apply netplan:

```bash
sudo netplan apply
```

Then verify rules are restored (Step 3). If netplan apply does not restore the rules, review
`/etc/netplan/60-floating-ip.yaml` for correctness.

### Permanent fix for root cause

Regardless of which specific failure occurred, the underlying issue is that the **nightly Docker
Compose restart is not safe with respect to ufw ip6tables rules**. The permanent fix should ensure
IPv6 UDP 6969 is allowed through to the container in a way that survives Docker chain rewrites —
either by patching the Docker/ufw interaction or by ensuring ufw rules are reloaded as part of the
nightly restart procedure.

Document the root cause and fix in
`docs/deployments/hetzner-demo-tracker/post-provision/ipv6-udp-tracker-issue.md` in the
[torrust-tracker-deployer](https://github.com/torrust/torrust-tracker-deployer) repository
(the canonical home for the deployment investigation docs for this server).

## Acceptance Criteria

- [ ] Root cause confirmed (which of the hypotheses applies)
- [ ] `udp://udp1.torrust-tracker-demo.com:6969/announce` accepted by newTrackon ✅
- [ ] The fix survives a nightly Docker Compose restart (verified by waiting 24 h or simulating
      with `docker compose restart tracker`)
- [ ] Root cause and fix documented in the deployer repo's deployment journal
- [ ] If a deployer-level fix is needed, a follow-up issue is opened in
      [torrust-tracker-deployer](https://github.com/torrust/torrust-tracker-deployer)
