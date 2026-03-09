# Post-Mortem: UDP Tracker Down on newTrackon After Nightly Restart

**Date**: 2026-03-09
**Issue**: [#2](https://github.com/torrust/torrust-tracker-demo/issues/2)
**Issue doc**: [issues/ISSUE-2-udp-tracker-down-on-newtrackon.md](../issues/ISSUE-2-udp-tracker-down-on-newtrackon.md)
**Server**: `udp1.torrust-tracker-demo.com` / `2a01:4f8:1c0c:828e::1`

---

## Investigation

### Step 1 — Check live ip6tables INPUT chain

Note: `ufw reload` had NOT been run manually since the last nightly restart when these
commands were executed.

Command:

```bash
sudo ip6tables -L INPUT -n --line-numbers | grep -E "6969|ACCEPT|Chain"
```

Output:

```text
Chain INPUT (policy DROP)
```

**Finding**: No ACCEPT rule for port 6969 in the live ip6tables. Policy is DROP.
The bug was already active — IPv6 UDP 6969 was being dropped without needing to
simulate a restart.

---

### Step 2 — Check ufw status (stored rules vs live rules)

Command:

```bash
sudo ufw status verbose
```

Output:

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere                   # SSH access (configured port 22)
6969/udp                   ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)              # SSH access (configured port 22)
6969/udp (v6)              ALLOW IN    Anywhere (v6)
```

**Finding**: ufw has the 6969/udp (v6) rule stored on disk but it is absent from the live
ip6tables. Docker's chain rewrite after the nightly container restart wiped ufw's live
ip6tables rules and ufw did not reload them. Root cause confirmed.

---

### Step 3 — Check Docker daemon.json (ip6tables setting)

Command:

```bash
cat /etc/docker/daemon.json 2>/dev/null || echo "(no daemon.json)"
```

Output:

```text
(no daemon.json)
```

**Finding**: Docker is using all defaults. `ip6tables` is disabled by default in Docker,
so Docker never inserts ip6tables rules for published ports. IPv6 UDP traffic on port 6969
must pass through the ufw INPUT chain, but Docker's chain rewrite after each container
start wipes ufw's live ip6tables rules.

---

### Step 4 — Verify fix survives a container restart

After adding `/etc/docker/daemon.json` with `{"ip6tables": true}` and restarting the
Docker daemon, the container restart was simulated to confirm the fix:

Command:

```bash
cd /opt/torrust && docker compose stop tracker && docker compose up -d tracker && sudo ip6tables -L ufw6-user-input -n
```

Output:

```text
[+] Stopping 1/1
 ✔ Container tracker  Stopped
[+] Running 2/2
 ✔ Container mysql    Healthy
 ✔ Container tracker  Started
Chain ufw6-user-input (1 references)
target     prot opt source               destination
ACCEPT     6    --  ::/0                 ::/0                 tcp dpt:22
ACCEPT     17   --  ::/0                 ::/0                 udp dpt:6969
```

**Finding**: The `ACCEPT udp dpt:6969` rule survived the container restart. Fix confirmed.

---

## Root Cause

1. ufw has `6969/udp (v6) ALLOW IN` stored on disk in `/etc/ufw/` ✅
2. The live ip6tables INPUT chain had **no rule** for 6969 and policy is DROP ❌
3. Docker has no `daemon.json` → `ip6tables` is disabled by default
4. When Docker starts/restarts the tracker container it rewrites its chains, flushing
   ufw's live ip6tables rules. ufw does not automatically reload after this.
5. For IPv4, Docker inserts its own DNAT rules that bypass ufw INPUT entirely → unaffected.
   For IPv6, no equivalent DNAT rules are inserted → traffic must go through ufw INPUT →
   silently dropped.

**Root cause**: Docker's default `ip6tables: false` combined with Docker chain rewrites on
container restart — ufw's ip6tables rules are wiped and never restored.

---

## Fix Decision

Options considered:

1. **`ufw reload` in backup script** — targeted, but only covers the nightly cron restart.
   Any other container restart (manual, OOM, redeploy) would re-expose the bug.

2. **Enable `ip6tables: true` in `/etc/docker/daemon.json`** — Docker manages ip6tables
   rules the same way it does for IPv4. Published port 6969/udp gets proper FORWARD chain
   rules that survive Docker chain rewrites. No changes to the backup script needed.
   Requires one-time Docker daemon restart; containers restart automatically via
   `restart: unless-stopped`.

**Chosen fix: Option 2.** It is the systemic fix — Docker becomes responsible for its own
ip6tables rules for published ports, exactly mirroring the IPv4 behaviour. The fix applies
globally to all Docker-published ports on all containers without any per-port or
per-container configuration.

See [docs/docker-ipv6.md](../docker-ipv6.md) for the full configuration reference.
