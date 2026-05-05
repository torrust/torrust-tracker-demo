<!-- cspell:ignore CPUPerc ksoftirqd rps_cpus rps_flow_cnt -->

# ISSUE-29 Phase 3 Execution - Enable RPS/RFS

## Context

- Issue: [#29](https://github.com/torrust/torrust-tracker-demo/issues/29)
- Goal: perform the second isolated production change by enabling RPS and RFS
  to distribute softirq processing across CPUs.
- Trigger: Phase 2 conclusively showed no effect from disabling HTTP/3.

## Pre-Change Snapshot

Capture timestamp (UTC): `2026-05-05T06:55:03Z`

### RX steering state (before)

Collected at `2026-05-05T06:54:45Z`:

- `net.core.rps_sock_flow_entries = 0`
- `/sys/class/net/eth0/queues/rx-0/rps_cpus = 00`
- `/sys/class/net/eth0/queues/rx-0/rps_flow_cnt = 0`

This confirms RPS/RFS were disabled.

### Performance state (before)

- Host load average: `9.08 / 9.06 / 8.90`
- `mpstat` all CPUs: `%usr=34.35`, `%sys=15.06`, `%soft=19.68`, `%idle=30.12`
- `mpstat` CPU2: `%soft=100.00`, `%idle=0.00` (fully saturated)
- Container CPU snapshot:
  - `caddy`: `323.46%`
  - `tracker`: `89.49%`
  - `mysql`: `7.06%`
  - `grafana`: `0.36%`
  - `prometheus`: `0.00%`
- Prometheus rates at pre-change timestamp:
  - HTTP1 request rate: `1912.99 req/s`
  - UDP1 request rate: `2234.14 req/s`

## Change Applied

Apply RPS/RFS live on `demotracker`:

```bash
sudo sysctl -w net.core.rps_sock_flow_entries=32768
echo ff | sudo tee /sys/class/net/eth0/queues/rx-0/rps_cpus
echo 4096 | sudo tee /sys/class/net/eth0/queues/rx-0/rps_flow_cnt
```

Change timestamp (UTC): `2026-05-05T06:55:19Z`

### Live verification immediately after change

- `net.core.rps_sock_flow_entries = 32768`
- `/sys/class/net/eth0/queues/rx-0/rps_cpus = ff`
- `/sys/class/net/eth0/queues/rx-0/rps_flow_cnt = 4096`

## Immediate Post-Change Validation

Capture timestamp (UTC): `2026-05-05T06:55:40Z`

### Performance state (after)

- Host load average: `9.65 / 9.16 / 8.94`
- `mpstat` all CPUs: `%usr=40.71`, `%sys=14.89`, `%soft=30.15`, `%idle=14.12`
- `mpstat` CPU2: `%soft=48.51`, `%idle=9.90`
- `mpstat` other CPUs: `%soft` now spread across all cores (`24%` to `33%`)
- Container CPU snapshot:
  - `caddy`: `411.88%`
  - `tracker`: `123.77%`
  - `mysql`: `9.67%`
  - `grafana`: `0.46%`
  - `prometheus`: `0.03%`
- Prometheus rates at post-change timestamp:
  - HTTP1 request rate: `1926.15 req/s`
  - UDP1 request rate: `2207.48 req/s`

### External probe sample

From `https://newtrackon.com/raw` during this window:

- `https://http1.torrust-tracker-demo.com:443/announce` -> `Working`
- `udp://udp1.torrust-tracker-demo.com:6969/announce` -> `Working`

## Assessment

Initial result is positive for the targeted bottleneck:

- CPU2 softirq dropped from `100%` to `48.51%`.
- Softirq work is no longer pinned to one core; it is distributed across all 8
  CPUs.
- External tracker health remains `Working` for both HTTP1 and UDP1.

Interpretation:

- The one-core softirq hotspot has been mitigated as intended.
- This validates the Phase 3 hypothesis that RX steering imbalance was a major
  contributor to the saturation pattern.

Open questions for follow-up observation:

- Whether this distribution remains stable over longer windows (T+1 h and
  next-day).
- Whether end-to-end CPU headroom improves materially after short-term
  settling.

## Observation Schedule

Agreed observation windows for Phase 3:

| Checkpoint | Target time (UTC)        | Status  |
| ---------- | ------------------------ | ------- |
| T+1 h      | 2026-05-05 07:55         | pending |
| T+next day | 2026-05-06 (any morning) | pending |

Capture the same metrics at each checkpoint: `mpstat`, `docker stats`,
Prometheus HTTP1/UDP1 rates, and a `newtrackon.com/raw` sample.
