# ISSUE-19 Progress and Temporary Conclusions (2026-04-13)

<!-- cspell:ignore Rcvbuf rmem netdev -->

## Scope Reminder

Goal: explain why newTrackon uptime for
`udp://udp1.torrust-tracker-demo.com:6969/announce` is around 92% instead of
at least 99%, and identify bottlenecks and fixes.

## What Was Done So Far

1. Created issue and evidence structure for ongoing investigation.
2. Collected baseline host snapshot (uptime/load/memory/disk/UDP sockets/docker services).
3. Collected sanitized host, kernel, and tracker diagnostics:
   process CPU/memory, docker stats, UDP kernel counters, aggregate tracker
   error categories.
4. Pulled Prometheus data and validated source mapping between:
   - `tracker_stats` (`/api/v1/stats`)
   - `tracker_metrics` (`/api/v1/metrics`)
5. Confirmed key metric families and caveats (counter-like vs non-counter).

## Evidence Files Collected

- `docs/issues/evidence/ISSUE-19/2026-04-13-baseline-server-snapshot.md`
- `docs/issues/evidence/ISSUE-19/2026-04-13-host-kernel-tracker-sanitized-diagnostics.md`
- `docs/issues/evidence/ISSUE-19/2026-04-13-prometheus-3h-summaries.md`
- `docs/issues/evidence/ISSUE-19/2026-04-13-prometheus-source-mapping.md`

## What We Learned So Far

1. Both Prometheus jobs are up and provide different data:
   - `tracker_stats` includes aggregate UDP series such as `udp6_requests`.
   - `tracker_metrics` includes detailed reliability counters such as
     `udp_tracker_server_*_total`.
2. Process-level metrics such as `process_cpu_seconds_total` are not exported by
   these tracker endpoints, so resource usage must be taken from host/docker/Hetzner.
3. During snapshot windows, host load was high for a 4-vCPU machine, with heavy
   CPU usage from `caddy` and `torrust-tracker`.
4. Kernel UDP receive buffer errors were non-zero (`UdpRcvbufErrors`, `Udp6RcvbufErrors`),
   indicating potential packet pressure/drops under load.
5. Tracker aggregate log categories show substantial malformed/expired/future
   UDP request patterns (not necessarily internal server failure, but real load/error pressure).

## Temporary Conclusions (Not Final Root Cause)

1. Nightly restart alone is unlikely to explain uptime as low as ~92%.
   Expected impact from a short nightly restart should still be around 99%+.
2. Capacity pressure is currently a strong suspect:
   - High sustained load on 4 vCPU
   - High tracker and caddy CPU demand
   - Non-zero UDP receive buffer errors
3. We still need proof of direct correlation between newTrackon failures and
   observed server-side pressure.

## Potential Actions to Improve Uptime (Based on Current Evidence)

## Immediate (low risk)

1. Build a 24-48h minute-resolution dataset for key counters:
   `udp_tracker_server_requests_received_total`,
   `udp_tracker_server_responses_sent_total{result="error"}`,
   `udp_tracker_server_errors_total`, `udp_tracker_server_requests_aborted_total`,
   plus host CPU/load and UDP buffer errors.
2. Add synthetic external probes (IPv4 + IPv6) from more than one source
   location to compare with newTrackon observations.
3. Capture packet path during degraded windows (`tcpdump`) to verify if probes
   arrive and whether replies leave with expected source IP.

## Short-term tuning

1. Review and tune UDP socket/kernel buffers (`rmem`/`netdev_max_backlog`) if justified by counters.
2. Reduce avoidable CPU contention in co-located services (especially `caddy`
   and `tracker`) and monitor effect.
3. Check connection/request rate limiting behavior and whether malformed traffic
   is causing disproportionate processing cost.

## Capacity/scaling

1. Run a controlled vertical scaling test (for example 4 vCPU -> 8 vCPU) and
   compare error ratios and external probe success rates.
2. If improvement is significant, keep larger sizing or split heavy services
   across hosts.

## Open Questions

1. Are newTrackon failures concentrated in IPv4, IPv6, or both?
2. Do failure windows align with specific traffic bursts or time-of-day patterns?
3. Is Caddy contributing to resource contention that affects UDP handling indirectly?

## Next Recommended Step

Export and store Prometheus `query_range` time-series for the last 24h and 72h
for the selected reliability metrics, then correlate with external probe status.
