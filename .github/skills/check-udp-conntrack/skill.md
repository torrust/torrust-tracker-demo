---
name: check-udp-conntrack
description: Workflow for checking whether UDP packet loss or uptime degradation may be caused by conntrack saturation on the torrust-tracker-demo server. Use when diagnosing UDP timeouts, low newTrackon uptime, packet drops, conntrack pressure, UDP receive-buffer errors, or when validating whether conntrack tuning is still healthy.
metadata:
  author: torrust
  version: "1.0"
---

<!-- cspell:ignore Rcvbuf conntrack NoPorts -->

# Check UDP Conntrack

## Overview

Use this skill to investigate whether UDP instability is caused by kernel-side
conntrack saturation or related packet-path pressure.

The canonical human-facing reference is:

- `docs/udp-conntrack-runbook.md`

Keep durable explanations and operational guidance in that document. This skill
should stay focused on workflow and safe execution.

## When To Use

Use this skill when the user asks to:

- check whether conntrack is too small
- diagnose UDP timeouts or packet loss
- validate that current conntrack tuning is still active
- verify whether the server is dropping UDP packets
- assess whether current symptoms point to conntrack saturation or something else

## Workflow

1. Run the host checks from `docs/udp-conntrack-runbook.md`.
2. Summarize the results in terms of:
   - conntrack occupancy
   - presence or absence of `table full` events
   - IPv4 and IPv6 UDP receive-buffer errors
   - whether `NoPorts` counters are relevant or benign
3. Distinguish conntrack saturation from softirq/RX steering imbalance.
4. If the user asks to document the result, update the relevant issue evidence
   or incident file and reference the runbook when appropriate.

## Interpretation Rules

- `nf_conntrack_count` near or equal to `nf_conntrack_max` means real pressure.
- Any fresh `nf_conntrack: table full, dropping packet` message is a confirmed problem.
- `UdpRcvbufErrors` or `Udp6RcvbufErrors` increasing during the incident means packet loss below the application layer.
- `NoPorts` counters alone do not prove tracker loss.
- High load average with one CPU dominated by `%soft` points to softirq concentration, not necessarily conntrack exhaustion.

## Safety Constraints

- Do not change sysctl values unless the user explicitly asks for a fix.
- If applying a fix, update both runtime state and persistent files when appropriate.
- Preserve issue-specific evidence in `docs/issues/evidence/ISSUE-<N>/`.
- Do not present the skill as the primary source of truth; the runbook in `docs/` is the canonical explanation.
