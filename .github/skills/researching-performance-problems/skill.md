---
name: researching-performance-problems
description: Workflow for investigating server and service performance bottlenecks in the torrust-tracker-demo repository. Use when debugging uptime degradation, high load, latency spikes, dropped packets, or suspected capacity limits. Triggers on "performance issue", "high load", "uptime drop", "bottleneck", "capacity", "scaling", "degraded service", "newTrackon uptime".
metadata:
  author: torrust
  version: "1.0"
---

<!-- cspell:ignore snmp nstat -->

# Researching Performance Problems

## Overview

This skill provides a practical workflow to investigate performance and uptime
problems without jumping to conclusions too early.

Use it to gather reproducible evidence, separate signal from noise, and decide
whether the root cause is load, network path issues, application behavior, or
infrastructure sizing.

## When To Use

Use this workflow when any of these symptoms appear:

- Uptime drops (for example external probes below expected SLA)
- High load average or CPU saturation
- Increased request errors, timeouts, or dropped UDP traffic
- Suspected bottlenecks requiring tuning or scale-up decisions

## Core Principles

1. Capture evidence before changing infrastructure.
2. Keep raw artifacts in issue-scoped evidence folders.
3. Separate temporary conclusions from confirmed root cause.
4. Treat monitoring source differences explicitly (for example `tracker_stats`
   vs `tracker_metrics`).
5. Avoid exposing secrets or client-identifying payloads in stored evidence.

## Recommended Workflow

### 1) Create Issue-Scoped Evidence Folder

Use:

- `docs/issues/evidence/ISSUE-<N>/`

Add one file per capture with:

1. Context
2. Exact commands
3. Raw output (sanitized if needed)
4. Short notes/findings

### 2) Collect Baseline Host Snapshot

Capture at minimum:

- `date -u`, `uptime`, `free -h`, `df -h`, `ss -u -s`
- `docker compose ps`
- top CPU and memory process snapshots

### 3) Collect Kernel and Network Pressure Signals

Common checks:

- UDP counters (`/proc/net/snmp`, `nstat`)
- Interface error/drops (`ip -s link`)
- Packet path checks during incidents (`tcpdump`)

### 4) Collect Application and Service Signals

- Service-level counters and errors from Prometheus
- Aggregated log category counts (avoid raw sensitive payload dumps)
- Container-level CPU/memory/network (`docker stats --no-stream`)

### 5) Use Prometheus Deliberately

- Validate scrape source mapping before analysis.
- Prefer counter-style series (`*_total`) for increases/rates.
- Use `query_range` for 24h-72h time-correlation, not only point-in-time queries.
- Explicitly document caveats when metric names suggest gauge-like behavior.

### 6) Correlate with External Uptime

Correlate internal metrics with external probe windows:

- newTrackon status changes
- synthetic probes from multiple locations
- host/network pressure windows

### 7) Decide on Remediation Path

- Tune first if clear bottleneck is configuration-level.
- Scale up if pressure is persistent and tuning is insufficient.
- Validate impact after each change using same evidence method.

## Common Things To Check

1. CPU contention between reverse proxy and tracker process.
2. UDP receive buffer errors and queue/backlog pressure.
3. Request error ratio trend by protocol and port.
4. IPv4/IPv6 differences in failure behavior.
5. Restart windows vs uptime drops (restart alone rarely explains large drops).

## Output Template (per investigation phase)

Create a progress/conclusions note containing:

1. What was done
2. What was learned
3. Temporary conclusions
4. Candidate actions (immediate, short-term tuning, scaling)
5. Open questions

## Example From This Repository

Use ISSUE-19 evidence as a reference implementation:

- `docs/issues/evidence/ISSUE-19/2026-04-13-baseline-server-snapshot.md`
- `docs/issues/evidence/ISSUE-19/2026-04-13-host-kernel-tracker-sanitized-diagnostics.md`
- `docs/issues/evidence/ISSUE-19/2026-04-13-prometheus-source-mapping.md`
- `docs/issues/evidence/ISSUE-19/2026-04-13-prometheus-3h-summaries.md`
- `docs/issues/evidence/ISSUE-19/2026-04-13-progress-and-temporary-conclusions.md`

## Safety Notes

- Do not commit secrets, tokens, credentials, or private keys.
- Avoid storing raw logs with full client-identifying request payloads when not
  strictly necessary.
- Prefer aggregated counts when raw logs are high-volume and privacy-sensitive.
