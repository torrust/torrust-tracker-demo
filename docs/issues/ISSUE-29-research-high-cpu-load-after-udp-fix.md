# Research high CPU load after UDP uptime recovery

**Issue**: [#29](https://github.com/torrust/torrust-tracker-demo/issues/29)
**Related**:
[#21](https://github.com/torrust/torrust-tracker-demo/issues/21),
[#19](https://github.com/torrust/torrust-tracker-demo/issues/19)

## Overview

The UDP uptime problem tracked in [#21](https://github.com/torrust/torrust-tracker-demo/issues/21)
appears resolved: newTrackon is now healthy again after the conntrack fix and server resize.
However, the live server is still running at a high CPU load, which leaves limited headroom for
future traffic growth and may become the next reliability risk even before external uptime drops.

This issue tracks a controlled investigation and remediation plan for the remaining CPU pressure.
The work should change only one variable at a time, with an observation period after each change,
so the impact of each action is measurable and attributable.

## Current Baseline (2026-05-04)

Live snapshot collected from the demo server on 2026-05-04:

- Host load average: `8.50 / 8.27 / 8.20`
- Host CPU summary (`mpstat -P ALL 1 1`):
  - all CPUs: `%usr=35.33`, `%sys=15.38`, `%soft=19.69`, `%idle=29.20`
  - CPU2: `%soft=100.00`, `%idle=0.00`
- Top CPU consumers:
  - `caddy`: about `279%`
  - `torrust-tracker`: about `88%`
  - `ksoftirqd/2`: visible in top CPU list
- Docker container CPU snapshot:
  - `caddy`: `295.60%`
  - `tracker`: `91.84%`
  - `mysql`: `2.63%`
  - `grafana`: `0.29%`
  - `prometheus`: `0.00%`
- Current request rates from Prometheus:
  - HTTP1: about `1982.32 req/s`
  - UDP1: about `2124.28 req/s`
  - Combined: about `4106.60 req/s`
- Conntrack state:
  - `nf_conntrack_count`: `423120`
  - `nf_conntrack_max`: `1048576`
  - utilization: about `40.35%`
- RX steering state:
  - `/sys/class/net/eth0/queues/rx-0/rps_cpus`: `00`
  - `/sys/class/net/eth0/queues/rx-0/rps_flow_cnt`: `0`
  - `net.core.rps_sock_flow_entries`: `0`

## What We Know So Far

### Conntrack is no longer the immediate bottleneck

The live conntrack table is well below the configured limit, so this does not look like a repeat
of the overflow problem fixed in [#21](https://github.com/torrust/torrust-tracker-demo/issues/21).

### The packet path is still imbalanced on one CPU

One CPU is saturated in softirq while the host still has idle capacity overall. That strongly
suggests packet processing is concentrated on one RX path instead of being distributed across
cores.

The current live configuration confirms that RPS/RFS are disabled.

### Caddy is also consuming several CPU cores

This is not just a tracker-only problem. The HTTPS front-end is currently one of the largest CPU
consumers on the host.

The current Compose file exposes UDP 443 for Caddy:

```yaml
- "443:443/udp"
```

This is used for HTTP/3 over QUIC. It is not required for normal HTTPS over TCP. Standard HTTPS
would continue to work without it; removing it would only disable HTTP/3.

The deployed server currently mirrors the repository on this point: the live
`/opt/torrust/docker-compose.yml` also exposes `443:443/udp`, and the host is listening on UDP 443.

## Controlled Action Plan

Important constraint: apply only one production change at a time and wait before taking the next
step.

### Phase 1 — Preserve a reproducible baseline

- [x] Record a baseline evidence snapshot under `docs/issues/evidence/ISSUE-29/` before making
      any changes. See `00-baseline-live-snapshot.md` and `2026-05-04-htop-snapshot.png`.
- [x] Capture host load, per-CPU usage, top processes, docker stats, conntrack state, and RX
      steering state.
- [x] Record at minimum the live HTTP1 and UDP1 request rates from Prometheus.
- [x] Record current newTrackon status for UDP1 and HTTP1.

### Phase 2 — First isolated experiment: disable HTTP/3

- [x] Remove `"443:443/udp"` from the Caddy service in `server/opt/torrust/docker-compose.yml`.
- [x] Apply only that change on the live server and restart only Caddy.
- [x] Observe CPU, request rates, and external service health at T+1 h (≈ 2026-05-04 16:31 UTC).
      **Result: no improvement. CPU2 still 100% softirq; Caddy ~321%; load ~8.5. HTTP/3 is not
      the cause.** See `01-phase2-disable-http3-execution.md` T+1 h section.
- [x] Observe the following day (2026-05-05) to confirm no delayed effect.
      **Result: no improvement. CPU2 still ~98% softirq; Caddy ~309%; load ~8.5. No delayed
      effect.** See `01-phase2-disable-http3-execution.md` T+next-day section.
- [x] Decide whether Caddy CPU dropped materially enough to keep HTTP/3 disabled.
      **Historical decision (2026-05-05): keep HTTP/3 disabled (hygiene). The change caused no
      regression and removed an unused port mapping, but it did not reduce CPU load.**
      **Update (2026-05-07): superseded by [#31](https://github.com/torrust/torrust-tracker-demo/issues/31),
      which re-enables edge HTTP/3 as a product-capability choice with rollback triggers.**

Execution and immediate post-change checks are recorded in
`docs/issues/evidence/ISSUE-29/01-phase2-disable-http3-execution.md`.

Rationale: this is a small, isolated change that affects only HTTP/3/QUIC support and does not
change normal HTTPS or the tracker's UDP listener on port 6969.

### Phase 3 — Second isolated experiment: enable RPS/RFS

- [x] If CPU pressure remains high after Phase 2, enable RPS and RFS as documented in
      `docs/udp-conntrack-runbook.md`.
- [x] Persist the configuration in the tracked server config.
- [x] Re-check whether softirq is still concentrated on one CPU.
      **Immediate result: improved.** CPU2 `%soft` dropped from `100%` to `48.51%`
      and softirq work spread across all 8 CPUs. See
      `docs/issues/evidence/ISSUE-29/02-phase3-enable-rps-rfs-execution.md`.
- [x] Observe for an agreed window before taking further action.
      **T+1h (2026-05-05T09:13Z): distribution pattern stable. CPU2 %soft=49.48%,
      no single-core saturation, both endpoints Working. T+next-day
      (2026-05-06T09:24Z): distribution remains stable, both endpoints still
      Working, but host load remains high (~11.83), indicating limited
      headroom. See
      `docs/issues/evidence/ISSUE-29/02-phase3-enable-rps-rfs-execution.md`.**

Rationale: this directly targets the observed one-core softirq saturation while leaving the
application stack unchanged.

### Phase 4 — Reassess architecture only after isolated tuning results exist

- [ ] If both isolated experiments fail to provide enough headroom, evaluate moving the HTTPS
      front-end or the UDP tracker onto separate hosts.
- [ ] Treat host separation as a later step, not the first response.

## Questions To Answer In This Issue

1. How much of the current CPU load is explained by higher traffic versus avoidable packet-path
   inefficiency?
2. Does disabling HTTP/3 reduce Caddy CPU materially without unacceptable product impact?
3. Does enabling RPS/RFS spread softirq work enough to restore headroom?
4. After isolated tuning, is a single-host deployment still acceptable at current traffic?

## Acceptance Criteria

- [ ] A baseline evidence snapshot exists for the pre-change state, including HTTP1 and UDP1
      request rates.
- [ ] The first production change is isolated to a single variable and its effect is documented.
- [ ] No follow-up production change is applied before the previous change has been observed.
- [x] A documented decision exists on whether `443:443/udp` should remain enabled for HTTP/3.
      **Historical decision: keep HTTP/3 disabled. Superseded by [#31](https://github.com/torrust/torrust-tracker-demo/issues/31)
      (re-enable with controlled observation and rollback criteria).**
- [x] A documented decision exists on whether RPS/RFS should be deployed permanently.
      **Decision: keep RPS/RFS enabled. It consistently removed the one-core
      softirq hotspot at immediate, T+1h, and T+next-day checkpoints.**
- [ ] The final issue conclusion states whether the current single-host design still has enough
      CPU headroom.
