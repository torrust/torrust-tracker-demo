# Re-enable Caddy HTTP/3 and Document ISSUE-29 Rationale

**Issue**: [#31](https://github.com/torrust/torrust-tracker-demo/issues/31)
**Related**:
[#29](https://github.com/torrust/torrust-tracker-demo/issues/29),
[#30](https://github.com/torrust/torrust-tracker-demo/issues/30),
[ISSUE-29-research-high-cpu-load-after-udp-fix.md](ISSUE-29-research-high-cpu-load-after-udp-fix.md)

## Overview

ISSUE-29 removed Caddy UDP port mapping `443:443/udp` (HTTP/3 over QUIC) during a controlled
production experiment. The observations showed no measurable CPU improvement after disabling
HTTP/3, while service availability remained stable.

This follow-up issue proposes re-enabling HTTP/3 at the Caddy edge and documenting why this
reversal is intentional. The goal is to restore HTTP/3 capability for present and future clients,
while keeping a controlled rollback path if resource cost or reliability regresses.

This issue also clarifies the protocol boundary in the current architecture:

- Edge protocol (client -> Caddy) can include HTTP/3.
- Backend protocol (Caddy -> tracker/grafana) remains reverse-proxy HTTP and does not require
  tracker native HTTP/3 support.

## Problem Statement

The current ISSUE-29 wording can be read as "HTTP/3 disabled for hygiene" even though the
experiment outcome was only that disabling HTTP/3 did not fix CPU pressure.

Keeping HTTP/3 disabled by default may also block automatic support for clients that prefer
or require HTTP/3 in the future. Since this demo already runs a Caddy edge proxy, re-enabling
UDP 443 is a low-complexity way to restore HTTP/3 capability without changing backend services.

The change should therefore be treated as a product-capability decision with operational
guardrails, not as a CPU-remediation tactic.

## Goals

1. Re-enable Caddy UDP 443 publish mapping for HTTP/3 at the edge.
2. Keep backend application topology unchanged.
3. Record explicitly that ISSUE-29 did not show CPU benefit from disabling HTTP/3.
4. Document why re-enable is being done now (future compatibility/capability) and how rollback
   will be handled if needed.

## Proposed Change

1. Re-add `"443:443/udp"` in Caddy service ports in
   `server/opt/torrust/docker-compose.yml`.
2. Apply the same change on live `/opt/torrust/docker-compose.yml` and recreate only Caddy.
3. Observe immediate, T+1h, and T+next-day checkpoints with the same metrics used in ISSUE-29.

## Rollback Triggers

If any trigger is met after re-enable, revert by removing `"443:443/udp"` again and record
the rollback in evidence:

1. Caddy CPU increases by more than 20% sustained for 24h vs pre-change baseline.
2. Host load average increases by more than 15% sustained for 24h vs pre-change baseline.
3. New external availability regression appears on tracked HTTP1 or UDP1 endpoints.

## Deliverables

- Compose change that re-enables Caddy UDP 443 publish mapping.
- Evidence notes for post-change observations (immediate, T+1h, T+next-day).
- Updated ISSUE-29 wording that clearly separates:
  - measured performance result,
  - capability/product decision,
  - rollback criteria and operational safeguards.

## Execution Status

- Repository config change completed: Caddy UDP 443 mapping has been re-added in
  `server/opt/torrust/docker-compose.yml`.
- Live-server Caddy recreate completed and UDP 443 listener validation completed.
- Immediate post-change evidence captured in
  `docs/issues/evidence/ISSUE-31/00-immediate-post-change-snapshot.md`.
- T+1h checkpoint captured in
  `docs/issues/evidence/ISSUE-31/01-t1h-snapshot.md`.
- T+next-day checkpoint captured in
  `docs/issues/evidence/ISSUE-31/02-next-day-snapshot.md`.
- Strict sustained-24h CPU/load trigger evaluation is currently inconclusive due
  to host restart between checkpoints (new uptime window).
- ISSUE-29 has been updated to record the re-enable rationale and clarify that
  edge HTTP/3 does not require backend native HTTP/3 support.

## Implementation Plan

- [x] Re-add `"443:443/udp"` for Caddy in `server/opt/torrust/docker-compose.yml`.
- [x] Apply only that change on the live server and recreate only Caddy.
- [x] Validate Caddy health and confirm host UDP 443 listener exists after deploy.
- [x] Capture immediate post-change metrics: `mpstat`, `docker stats`, Prometheus HTTP1/UDP1
      rates, and `newtrackon.com/raw` sample.
- [x] Capture T+next-day checkpoint with the same metrics.
- [x] Evaluate rollback triggers; if triggered, revert and record evidence.
- [x] Update ISSUE-29 text to explain why the earlier disablement is being reversed now.
- [x] Ensure ISSUE-29 states backend services do not need native HTTP/3 for edge HTTP/3 support.
- [x] Run `./scripts/lint.sh` and fix any markdown/cspell issues.

## Acceptance Criteria

- [x] Caddy HTTP/3 edge capability is re-enabled via `443:443/udp` mapping.
- [x] Immediate, T+1h, and T+next-day evidence snapshots are recorded.
- [x] No rollback trigger is met during the observation window, or rollback is executed and
      documented if a trigger is met.
- [x] ISSUE-29 explicitly states that disabling HTTP/3 did not reduce CPU in prior observations.
- [x] ISSUE-29 explicitly states why HTTP/3 was re-enabled and under which conditions it may be
      disabled again.
- [x] Documentation clearly states edge HTTP/3 is independent from backend native HTTP/3 support.
- [x] All changed files pass `./scripts/lint.sh`.

## Conclusion

ISSUE-31 can be closed.

- Edge HTTP/3 support has been restored by re-enabling `443:443/udp` on Caddy.
- Immediate, T+1h, and T+next-day evidence shows stable service health and no
  observed availability regression.
- A strict sustained-24h CPU/load comparison was interrupted by a host restart,
  so that specific continuity requirement is inconclusive rather than failed.
- No rollback trigger was met in the observed checkpoints, so rollback is not
  indicated.
