# Research Low UDP Tracker Uptime on newTrackon

**Issue**: [#19](https://github.com/torrust/torrust-tracker-demo/issues/19)
**Related**:
[torrust/torrust-demo#26](https://github.com/torrust/torrust-demo/issues/26),
[ISSUE-2](ISSUE-2-udp-tracker-down-on-newtrackon.md),
[ISSUE-5](ISSUE-5-external-monitoring.md)

## Overview

Current public uptime shown by [newTrackon](https://newtrackon.com/):

- HTTP tracker: `https://http1.torrust-tracker-demo.com:443/announce` -> 99.90 %
- UDP tracker: `udp://udp1.torrust-tracker-demo.com:6969/announce` -> 92.20 %

The HTTP endpoint is stable, but UDP uptime is significantly lower. This is not
the first time this pattern appears. A similar intermittent issue was previously
observed in the old demo setup:

- [torrust/torrust-demo#26](https://github.com/torrust/torrust-demo/issues/26)

At the time of writing, the old tracker demo UDP endpoint is healthy:

- `udp://tracker.torrust-demo.com:6969/announce` -> 99.70 %

This issue tracks a focused investigation to identify why the new demo has lower
UDP uptime and whether the root cause is resource saturation, network path
instability, runtime errors, or another operational bottleneck.

## Working Hypotheses

1. The server is occasionally resource-constrained (CPU, memory, network, disk
   I/O), and UDP handling degrades during load spikes.
2. UDP packet handling on the host or Docker path is intermittently affected by
   firewall/routing/NAT behavior.
3. Tracker runtime behavior under load (request bursts, database pressure,
   socket pressure, queueing) causes transient failures that are visible in
   external probes.
4. The issue is probe-specific or path-specific (newTrackon source paths,
   IPv4/IPv6 asymmetry), while internal checks may still look healthy.

## Investigation Plan

### 1) Grafana and Prometheus evidence (current and historical load)

- [ ] Review Grafana dashboards and Prometheus metrics around periods where
      newTrackon UDP uptime dropped.
- [ ] Extract relevant time windows and values for:
      CPU, memory, network throughput, packet drops/errors, disk I/O,
      container restart counts, tracker request rates, and response latency.
- [ ] Correlate metric spikes with observed external UDP failures.

### 2) Server usage and host telemetry

- [ ] Capture host-level usage snapshots during normal load and peak load:
      CPU, memory, swap, load average, open files, socket usage, network
      interface stats, and bandwidth utilization.
- [ ] Check kernel/network counters for UDP drops and receive/send buffer
      pressure.
- [ ] Record whether host limits (file descriptors, conntrack, buffers) are near
      saturation.

### 3) Network bottleneck analysis

- [ ] Use network troubleshooting tools to inspect UDP flow behavior and packet
      loss indicators.
- [ ] Validate firewall/routing/NAT behavior for UDP 6969 on both IPv4 and IPv6.
- [ ] Confirm there is no asymmetric routing or path-specific filtering.

### 4) Docker Compose and tracker logs

- [ ] Review Docker Compose service logs, focusing on the tracker service, for
      warnings/errors during suspected failure windows.
- [ ] Check for container restarts, OOM kills, health-check flaps, and
      dependency failures (database/cache/network).
- [ ] Look for tracker log patterns indicating overloaded sockets, timeout
      spikes, or request-processing backlogs.

### 5) Additional evidence collection

- [ ] Compare behavior with the old demo endpoint to identify differences in
      infrastructure, network setup, and load profile.
- [ ] Verify whether failures correlate with specific times of day or expected
      traffic bursts.
- [ ] If feasible, run controlled announce load tests to reproduce degradation
      and identify capacity boundaries.

## Deliverables

- [ ] A short incident-style report in `docs/post-mortems/` or
      `docs/issues/` summarizing findings, timeline, and likely root cause(s).
- [ ] A prioritized action list with immediate mitigations and longer-term
      fixes.
- [ ] If capacity is the bottleneck, a scaling plan (vertical sizing and/or
      horizontal strategy) with expected impact.
- [ ] If observability is insufficient, a proposal for additional metrics,
      dashboards, and alerts specific to UDP reliability.

## Acceptance Criteria

- [ ] Evidence from metrics, host telemetry, network diagnostics, and logs is
      collected and documented.
- [ ] At least one probable root cause (or narrowed set of causes) is
      identified with supporting data.
- [ ] Concrete remediation steps are defined and tracked in follow-up issues.
- [ ] A verification plan is defined to confirm improvement in newTrackon UDP
      uptime after changes.

## Notes

Given recurring behavior and the difference between HTTP and UDP availability,
do not assume a single static configuration issue. Treat this as an
intermittent reliability investigation and prioritize correlation across data
sources over one-off spot checks.
