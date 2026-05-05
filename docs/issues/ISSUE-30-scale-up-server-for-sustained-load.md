# Scale Up Demo Server for Sustained Load Growth

<!-- cspell:ignore CCX CCX13 CCX23 CCX33 CCX43 CCX53 CCX63 NVMe EX44 EX63 AX42 AX102 newtrackon -->

**Issue**: [#30](https://github.com/torrust/torrust-tracker-demo/issues/30)
**Related**:
[#21](https://github.com/torrust/torrust-tracker-demo/issues/21),
[#29](https://github.com/torrust/torrust-tracker-demo/issues/29),
[infrastructure-resize-history.md](../../infrastructure-resize-history.md)

## Overview

After the conntrack fix and server resize in
[#21](https://github.com/torrust/torrust-tracker-demo/issues/21), UDP uptime
recovered to 99.9%. A follow-on softirq hotspot (CPU2 at 100% soft) was
diagnosed and fixed in [#29](https://github.com/torrust/torrust-tracker-demo/issues/29)
Phase 3 (RPS/RFS enabled on 2026-05-04). The hotspot was immediately resolved —
CPU soft-IRQ spread across all 8 CPUs — but the host load average remained in
the 9–10 range on an 8-vCPU machine.

This means the server is running at or beyond its comfortable capacity even with
packet steering working correctly. If traffic continues to grow, or if the
softirq tuning is ever disrupted, uptime on newTrackon is likely to degrade
again. This issue tracks planning and execution of the next server scale-up.

## Current State (2026-05-05)

Post-RPS/RFS baseline collected at `2026-05-05T09:13:52Z` (T+1h after Phase 3):

- Host load average: `9.24 / 9.24 / 9.43` (8-vCPU machine)
- CPU distribution (`mpstat -P ALL 1 1`):
  - CPU2: `%soft=49.48` (was 100% before Phase 3)
  - All CPUs: `%soft` in the 26–41% range
  - Combined idle across all CPUs: low, indicating sustained saturation
- Docker container CPU (approximate):
  - `caddy`: ~300%
  - `tracker`: ~90%
- Request rates from Prometheus (5-minute rate):
  - HTTP1: ~1982 req/s
  - UDP1: ~2124 req/s
  - Combined: ~4107 req/s (~513 req/s per vCPU)
- newTrackon status: both endpoints `Working`

Load averages of 9–10 on an 8-vCPU host indicate the runqueue is consistently
overcommitted even after the softirq fix. There is very little headroom.

## Goal

Determine the right time and target plan to resize the server so that:

- Host load average stays comfortably below the vCPU count (target: < 0.7 per
  vCPU, i.e., < 5.6 on an 8-vCPU host or < 11.2 on a 16-vCPU host).
- Combined req/s per vCPU drops to a level that provides meaningful headroom.
- newTrackon uptime for both endpoints remains >= 99.0%.

## Trigger Conditions

**Do not resize until at least one of the following is true:**

1. T+next-day observation in ISSUE-29 shows the RPS/RFS fix is not holding
   (CPU2 `%soft` returns to 100% or overall soft-IRQ pressure re-concentrates).
2. newTrackon UDP uptime drops below 99.0% on the rolling 7-day window.
3. newTrackon HTTP uptime drops below 99.0%.
4. newTrackon response times for either endpoint increase materially (> 2×
   current baseline) for more than 24 hours.
5. Load average exceeds 12 sustained over a 24-hour period (1.5× vCPU count).

Track these signals in the **Observation Log** section below.

## newTrackon Tracking

Monitor both endpoints:

- HTTP: `https://http1.torrust-tracker-demo.com:443/announce`
- UDP: `udp://udp1.torrust-tracker-demo.com:6969/announce`

Check and record at each observation interval:

- Status (Working / Down)
- Rolling uptime %
- Response time (ms)

### Observation Log

| Date (UTC) | HTTP1 status | HTTP1 uptime % | HTTP1 resp (ms) | UDP1 status | UDP1 uptime % | UDP1 resp (ms) | Load avg (1m) | Notes                             |
| ---------- | ------------ | -------------- | --------------- | ----------- | ------------- | -------------- | ------------- | --------------------------------- |
| 2026-05-05 | Working      | —              | —               | Working     | —             | —              | 9.24          | Baseline after RPS/RFS (ISSUE-29) |

## Scope

- Evaluate and select the next server plan (cloud or dedicated).
- Execute resize at the appropriate trigger point.
- Keep all other configuration constant during the observation window.
- Record pre-resize and post-resize metrics.
- Update `infrastructure-resize-history.md`.

## Non-Goals

- Migrating to a multi-host or distributed architecture.
- Making tuning changes simultaneously with the resize.
- Changing the tracker or proxy configuration.

## Options Research

All prices are list prices in EUR (excl. VAT) as of May 2026.

### Hetzner Cloud — AMD Dedicated vCPU (CCX Series)

These are cloud VMs with dedicated AMD vCPUs, easy to resize online via the
Hetzner console (no migration required, brief reboot only).

| Plan  | vCPU | RAM    | NVMe SSD | Traffic | Price/month |
| ----- | ---- | ------ | -------- | ------- | ----------- |
| CCX13 | 2    | 8 GB   | 80 GB    | 20 TB   | €16.49      |
| CCX23 | 4    | 16 GB  | 160 GB   | 20 TB   | €31.99      |
| CCX33 | 8    | 32 GB  | 240 GB   | 30 TB   | €62.99      |
| CCX43 | 16   | 64 GB  | 360 GB   | 40 TB   | €125.49     |
| CCX53 | 32   | 128 GB | 600 GB   | 40 TB   | €250.49     |
| CCX63 | 48   | 192 GB | 960 GB   | 60 TB   | €374.99     |

**Current plan: CCX33** (8 vCPU / 32 GB / €62.99/mo)

**Next step up: CCX43** (16 vCPU / 64 GB / €125.49/mo — +€62.50/mo)

CCX43 would reduce normalized load from ~513 req/s/vCPU to ~257 req/s/vCPU at
current traffic, and load average headroom would double.

Advantages of cloud step-up:

- No setup fee; no data migration.
- Revert is possible if the resize is not justified.
- Consistent experience with previous resize (CCX23 → CCX33).

### Hetzner Dedicated Servers

Dedicated physical servers provide more cores and threads per EUR, but require
a manual server migration (data copy, DNS/IP cutover) and a one-time setup fee.

| Model   | Cores | Threads | RAM    | Storage         | Bandwidth | Price/month | Setup fee |
| ------- | ----- | ------- | ------ | --------------- | --------- | ----------- | --------- |
| EX44    | 14    | 20      | 64 GB  | 2 × 512 GB NVMe | 1000 Mbit | ~€44        | ~€109     |
| AX42-U  | 8     | 16      | 64 GB  | 2 × 512 GB NVMe | 1000 Mbit | ~€54        | ~€234     |
| EX63    | 20    | 20      | 64 GB  | 2 × 1 TB NVMe   | 1000 Mbit | ~€76        | ~€325     |
| AX102-U | 16    | 32      | 128 GB | varies          | 1000 Mbit | ~€119       | ~€500     |

**EX44 is the standout option** if we decide to go dedicated:

- 14 physical cores / 20 threads vs 8 vCPUs today.
- 64 GB RAM (2× current).
- Monthly cost (~€44) is actually _cheaper_ than the current CCX33 (~€62.99).
- One-time setup fee of ~€109 is recovered in roughly 2 months of savings.
- Break-even vs CCX43 (~€125.49/mo): in month 1 total spend is ~€153 vs €125;
  from month 2 onwards EX44 saves ~€82/mo over CCX43.

Disadvantages of dedicated:

- Manual migration required (bring-your-own IP, data copy, DNS update).
- No online resize; rollback is much harder.
- Bare-metal; OS and boot configuration is our responsibility.
- Physical hardware failure handling differs from cloud VMs.

### Decision Matrix

| Criterion               | CCX43 (cloud step-up)   | EX44 (dedicated)                     |
| ----------------------- | ----------------------- | ------------------------------------ |
| Monthly cost            | €125.49                 | ~€44 (saves ~€19/mo vs current)      |
| Setup friction          | Minimal (reboot only)   | High (full migration)                |
| Reversibility           | Easy                    | Hard                                 |
| CPU headroom at ~4k rps | 16 vCPU / ~257 rps/vCPU | 20 threads / ~205 rps/thread         |
| RAM headroom            | 64 GB                   | 64 GB                                |
| Long-term cost          | More expensive          | Cheaper after break-even (~2 months) |
| Risk                    | Low                     | Medium (migration complexity)        |

**Recommendation**: Start with CCX43 if the trigger is near-term and urgency
is high. Plan migration to EX44 if sustained long-term cost reduction is the
priority once the situation is stable.

## Implementation Plan

1. Monitor newTrackon and ISSUE-29 Phase 3 outcomes daily.
2. When a trigger condition is met, capture a pre-resize baseline snapshot
   (request rates, load averages, uptime).
3. Select target plan based on urgency and risk tolerance (see decision matrix).
4. Execute resize following the procedure documented for ISSUE-21.
5. Verify all services recover post-resize.
6. Observe for at least 7 days and record post-resize metrics.
7. Update `infrastructure-resize-history.md` with pre- and post-resize rows.
8. Close this issue with a conclusion referencing the evidence.

## Metrics and Evidence to Track

- External uptime:
  - newTrackon HTTP uptime for `http1`
  - newTrackon UDP uptime for `udp1`
  - newTrackon response times for both endpoints
- Traffic levels:
  - HTTP1 request rate (Grafana)
  - UDP1 request rate (Grafana)
  - Combined request rate (HTTP1 + UDP1)
  - Normalized load (combined req/s per vCPU)
- Capacity pressure:
  - Host load average (1m, 5m, 15m)
  - Container CPU usage (caddy, tracker)
  - `%soft` per CPU from `mpstat`

## Acceptance Criteria

- [ ] Trigger condition documented and agreed upon before resize starts.
- [ ] Pre-resize baseline captured.
- [ ] Resize executed and documented in resize history.
- [ ] No critical service regression immediately after resize.
- [ ] At least 7 days of post-resize observations recorded.
- [ ] Host load average stays below vCPU count sustained (< 1.0 per vCPU).
- [ ] newTrackon uptime for both endpoints remains >= 99.0%.
- [ ] Pre/post comparison documented with clear conclusion.

## Possible Outcomes

- **Success**: Load average drops below vCPU count, uptime stable at >= 99.0%.
- **Partial**: Uptime holds but load remains high; additional tuning needed.
- **No improvement**: Traffic growth outpaces resize; larger plan required.
- **Premature**: ISSUE-29 Phase 3 outcome fully resolves headroom concerns; resize
  deferred indefinitely.
