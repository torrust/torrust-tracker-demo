# Scale Up Demo Server Capacity to Improve UDP Tracker Uptime

<!-- cspell:ignore Rcvbuf -->

**Issue**: [#21](https://github.com/torrust/torrust-tracker-demo/issues/21)
**Related**:
[#19](https://github.com/torrust/torrust-tracker-demo/issues/19),
[infrastructure-resize-history.md](../../infrastructure-resize-history.md),
[2026-04-13-progress-and-temporary-conclusions.md](../evidence/ISSUE-19/2026-04-13-progress-and-temporary-conclusions.md)

## Overview

Observed traffic and evidence suggest the current server size (CCX23, 4 vCPU,
16 GB RAM) is likely under pressure for current request volume (roughly
1300 HTTP req/s + 1500 UDP req/s).

Current public uptime observed in newTrackon for UDP is below target:

- `udp://udp1.torrust-tracker-demo.com:6969/announce` -> ~92%

This issue tracks a controlled resize experiment to determine whether capacity
is the main bottleneck and to restore/maintain UDP uptime at or above 99%.

## Goal

Increase UDP tracker uptime to at least 99.0% over a rolling 7-day window while
keeping service behavior stable.

## Current Throughput Baseline (Pre-Resize)

Observed request rates (Grafana, recent 3h window):

- HTTP1: ~1300 req/s
- UDP1: ~1500 req/s
- Combined: ~2800 req/s

On the current CCX23 (4 vCPU), this is approximately:

- ~700 req/s per vCPU (combined)

This baseline must be preserved in the resize history so future sizing
decisions can be based on both absolute load and normalized load per vCPU.

## Scope

- Resize the demo server to a larger plan.
- Keep all other major changes constant during the observation window.
- Compare pre-resize and post-resize metrics and uptime.
- Record evidence in issue-scoped resize tracking files.

## Selected Target Plan

The next available option selected for this experiment is:

| Property | Value                |
| -------- | -------------------- |
| Plan     | CCX33                |
| vCPUs    | 8 (AMD)              |
| RAM      | 32 GB                |
| SSD      | 160 GB               |
| Traffic  | 30 TB                |
| Price    | €0.100/h - €62.49/mo |

## Non-Goals

- Redesigning the full architecture.
- Migrating services to multiple hosts.
- Making multiple tuning changes at the same time as resizing.

## Implementation Plan

1. Capture pre-resize baseline (request rates, UDP errors, host load, uptime).
2. Resize server from CCX23 to CCX33.
3. Verify service health after resize (docker services, tracker endpoints,
   prometheus/grafana availability).
4. Observe and collect post-resize data for at least 7 days.
5. Compare before/after and decide whether resize is sufficient.
6. As part of this issue implementation, add a dedicated skill documenting the
   server resize workflow and validation steps for future reuse.

## Metrics and Evidence to Track

- External uptime:
  - newTrackon UDP uptime for `udp1`
- Traffic levels:
  - HTTP1 request rate (Grafana)
  - UDP1 request rate (Grafana)
  - Combined request rate (HTTP1 + UDP1)
  - Normalized load (combined req/s per vCPU)
- Reliability:
  - `udp_tracker_server_errors_total`
  - `udp_tracker_server_requests_aborted_total`
  - `udp_tracker_server_responses_sent_total{result="error"}`
- Capacity pressure:
  - Host load average
  - Container CPU usage (tracker, caddy)
  - UDP receive buffer errors (`UdpRcvbufErrors`, `Udp6RcvbufErrors`)

## Acceptance Criteria

- [ ] Resize executed and documented in resize history.
- [ ] No critical service regression immediately after resize.
- [ ] At least 7 days of post-resize observations recorded.
- [ ] UDP newTrackon uptime reaches and stays >= 99.0% during evaluation window.
- [ ] Pre/post comparison documented with clear conclusion.
- [ ] Resize workflow skill added and referenced.

## Possible Outcomes

- **Success**: Uptime >= 99% and error pressure decreases materially.
- **Partial**: Uptime improves but remains < 99%; continue with targeted tuning.
- **No improvement**: Capacity is not primary bottleneck; continue with
  network/path/protocol-focused investigation.
