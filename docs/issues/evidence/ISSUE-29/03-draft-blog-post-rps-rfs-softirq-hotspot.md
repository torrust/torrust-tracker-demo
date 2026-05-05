<!-- cspell:ignore ksoftirqd softirq rps rfs cpus cpupct mpstat Prometheus QUIC newtrackon conntrack udp urlencode -->

# Draft Blog Post: How We Fixed a One-Core Packet Processing Bottleneck in Torrust Tracker

> Draft status: work in progress from ISSUE-29.
>
> This draft is written for developers. Linux networking terms are explained as we
> use them.

## TL;DR

We found that one CPU core was saturated doing kernel packet work (`softirq`),
while other cores still had capacity. This caused persistent high load and
limited headroom.

We tested two isolated changes:

1. Disable HTTP/3 (QUIC) on Caddy by removing UDP 443.
2. Enable RPS/RFS to distribute packet processing across CPUs.

Result so far:

- Disabling HTTP/3 did **not** improve the bottleneck.
- Enabling RPS/RFS immediately reduced CPU2 softirq from `100%` to `48.51%`
  and spread packet work across all 8 CPUs.

## What Problem We Detected

We were seeing sustained high CPU pressure on a production tracker host.

Key symptoms:

- `mpstat` showed one core (CPU2) pinned by kernel soft interrupts.
- `ksoftirqd/2` kept showing up near the top CPU consumers.
- User-space processes (`caddy`, `torrust-tracker`) were busy, but the unusual
  pattern was the **single-core softirq hotspot**.

For developers: what is `softirq`?

- When packets arrive at the NIC, part of the work happens in kernel networking
  paths, not in your app process.
- Linux accounts part of this work as `softirq`.
- If this work stays concentrated on one core, that core can saturate even when
  other cores are available.

This was exactly our pattern.

## How We Analyzed the Problem and Found the Cause

### Method: one variable at a time

We deliberately avoided changing many things at once.

- Phase 2 changed only HTTP/3 exposure on Caddy.
- Phase 3 changed only RPS/RFS steering.

This lets us attribute effects to a specific change.

## Phase 2: Hypothesis "HTTP/3 is causing the bottleneck"

### Why this was a reasonable hypothesis

Caddy had UDP 443 configured for HTTP/3 (QUIC). If QUIC traffic or handling was
causing extra kernel pressure, removing it could reduce softirq load.

### Change applied

In `server/opt/torrust/docker-compose.yml`, we removed UDP 443 from Caddy:

```diff
  ports:
    - "80:80"
    - "443:443"
-   - "443:443/udp"
```

Then we restarted only Caddy on the live server:

```bash
docker compose up -d caddy
```

### Commands we used and what they mean

**1. `mpstat -P ALL 1 1`**

- Shows per-CPU usage split (`%usr`, `%sys`, `%soft`, `%idle`, etc.).
- We use this to detect whether packet work is concentrated on one CPU.

**2. `ps -eo pid,comm,%cpu,%mem,stat --sort=-%cpu | head -20`**

- Shows top CPU-consuming processes.
- We use this to check `ksoftirqd/<N>` and main containers.

**3. `docker stats --no-stream`**

- One-shot CPU/memory snapshot per container.
- We use this to compare `caddy` and `tracker` before/after changes.

**4. Prometheus HTTP/UDP rate queries:**

```bash
curl -sG "http://127.0.0.1:9090/api/v1/query" \
  --data-urlencode "query=sum(rate(http_tracker_core_requests_received_total[5m]))"

curl -sG "http://127.0.0.1:9090/api/v1/query" \
  --data-urlencode "query=sum(rate(udp_tracker_server_requests_received_total[5m]))"
```

- We use these to ensure traffic level is comparable across snapshots.

**5. External service check from `newtrackon.com/raw`**

- Confirms public tracker endpoints still behave as expected.

### Phase 2 outputs (selected)

Immediate and follow-up snapshots stayed in the same range:

- CPU2 `%soft`: `98-100%` (still saturated)
- Caddy CPU: about `309-321%`
- Tracker CPU: about `93-100%`
- HTTP1/UDP1 externally: `Working`

Example checkpoint output summary:

```text
T+next-day (2026-05-05T06:16:14Z)
CPU2 %soft=98.02, %idle=1.98
caddy=308.89%, tracker=93.22%
HTTP1 rate=1909.11 req/s, UDP1 rate=2178.98 req/s
```

### Phase 2 conclusion

Disabling HTTP/3 (QUIC) was good hygiene (removed unused UDP publish), but it
was **not** the cause of the one-core softirq bottleneck.

## Phase 3: Hypothesis "packet processing is not being distributed"

### Why this hypothesis fit the evidence

If all incoming packet handling is effectively funneled to one CPU, that CPU can
hit softirq saturation first.

RPS/RFS are kernel mechanisms that help distribute receive-side packet handling:

- RPS (Receive Packet Steering): allows packet processing to be steered to
  multiple CPUs.
- RFS (Receive Flow Steering): improves steering for flow-to-CPU locality.

### Pre-change state (important)

Before Phase 3, steering features were disabled:

```text
net.core.rps_sock_flow_entries = 0
/sys/class/net/eth0/queues/rx-0/rps_cpus = 00
/sys/class/net/eth0/queues/rx-0/rps_flow_cnt = 0
```

Interpretation:

- `00` means no CPU mask configured for RPS.
- `0` flow values mean RFS is effectively off.

### Change applied (live)

```bash
sudo sysctl -w net.core.rps_sock_flow_entries=32768
echo ff | sudo tee /sys/class/net/eth0/queues/rx-0/rps_cpus
echo 4096 | sudo tee /sys/class/net/eth0/queues/rx-0/rps_flow_cnt
```

What each line does:

**1. `rps_sock_flow_entries=32768`**

- Creates a global flow table used by RFS.

**2. `rps_cpus=ff`**

- CPU bitmask `ff` (`0xff`) enables CPUs 0-7 as packet-processing targets.

**3. `rps_flow_cnt=4096`**

- Per-RX-queue flow count used for RFS decisions.

### Immediate post-change output (selected)

```text
Post-change (2026-05-05T06:55:40Z)
all CPUs: %soft=30.15
CPU2: %soft=48.51, %idle=9.90
other CPUs: %soft distributed across ~24-33%
```

Container snapshot around same time:

```text
caddy=411.88%
tracker=123.77%
mysql=9.67%
```

Traffic remained comparable:

```text
pre  HTTP=1912.99 req/s, UDP=2234.14 req/s
post HTTP=1926.15 req/s, UDP=2207.48 req/s
```

External endpoint sample remained healthy:

```text
https://http1.torrust-tracker-demo.com:443/announce -> Working
udp://udp1.torrust-tracker-demo.com:6969/announce -> Working
```

### Phase 3 interim conclusion

The specific bottleneck we targeted improved immediately:

- CPU2 stopped being hard-pinned at 100% softirq.
- Softirq work spread across all cores.

This is strong evidence that receive-side steering imbalance was a major cause.

## What We Changed in Configuration Files

This section is explicit so readers can reproduce the patch.

### 1) Caddy compose change (Phase 2 hygiene)

File: `server/opt/torrust/docker-compose.yml`

Relevant final section:

```yaml
ports:
  - "80:80"
  - "443:443"
  # HTTP/3 (QUIC) intentionally disabled during ISSUE-29 Phase 2 experiment
```

Change made:

```diff
- - "443:443/udp"
```

### 2) Persistent kernel setting for RFS

File: `server/etc/sysctl.d/98-rps-rfs.conf`

Final file content:

```conf
# RPS/RFS tuning to distribute NIC RX softirq work across CPUs.
# See: docs/udp-conntrack-runbook.md and ISSUE-29.

# Global socket flow table size used by RFS.
net.core.rps_sock_flow_entries = 32768
```

### 3) Persistent boot-time sysfs writes for RPS/RFS

File: `server/etc/cron.d/rps-rfs`

Final file content:

```cron
# Persist RPS/RFS sysfs settings across reboot.
# See: docs/udp-conntrack-runbook.md and ISSUE-29.

SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

@reboot root echo ff > /sys/class/net/eth0/queues/rx-0/rps_cpus && echo 4096 > /sys/class/net/eth0/queues/rx-0/rps_flow_cnt
```

## Why We Use Both Live Changes and Repo Mirror

This repository mirrors deployed server config under `server/`.

Operational rule we followed:

- If a live config file changes, the same final file content must be committed
  under `server/...`.

This keeps production reproducible and reviewable.

## Remaining Work Before Publishing Final Results

At this draft stage, we still need:

1. Phase 3 T+next-day checkpoint.
2. Final decision: keep RPS/RFS permanently (likely) or adjust values.
3. Final conclusion on long-term headroom under sustained load.

## Suggested Blog Structure (for torrust.com/blog)

1. Problem statement and user-visible symptoms.
2. Why one-core softirq saturation matters for UDP/TCP tracker traffic.
3. Phase 2 experiment (HTTP/3) and why it was ruled out.
4. Phase 3 experiment (RPS/RFS) and immediate improvements.
5. Exact patch files and deployment commands.
6. Follow-up checkpoints and final production decision.

## References

- Issue plan: `docs/issues/ISSUE-29-research-high-cpu-load-after-udp-fix.md`
- Phase 2 evidence: `docs/issues/evidence/ISSUE-29/01-phase2-disable-http3-execution.md`
- Phase 3 evidence: `docs/issues/evidence/ISSUE-29/02-phase3-enable-rps-rfs-execution.md`
- Htop snapshots:
  - `docs/issues/evidence/ISSUE-29/2026-05-04-htop-snapshot.png`
  - `docs/issues/evidence/ISSUE-29/2026-05-05-htop-snapshot.png`
- Background runbook: `docs/udp-conntrack-runbook.md`
- Previous related blog post:
  - https://torrust.com/blog/nf-conntrack-overflow-docker-udp-tracker
