# Pre-Resize Baseline

<!-- cspell:ignore Rcvbuf -->

## Context

Capture baseline immediately before resizing from CCX23 to CCX33.

## Snapshot

- Date (UTC):
- Server plan: CCX23
- vCPU / RAM: 4 / 16 GB
- Traffic allowance: 20 TB

## Load and Uptime Baseline

- HTTP1 req/s (Grafana, 3h window):
- UDP1 req/s (Grafana, 3h window):
- Total req/s:
- Req/s per vCPU:
- UDP newTrackon uptime (%):

## Reliability and Capacity Signals

- `udp_tracker_server_errors_total` (window/increase):
- `udp_tracker_server_requests_aborted_total` (window/increase):
- `udp_tracker_server_responses_sent_total{result="error"}` (window/increase):
- Host load average (1m/5m/15m):
- UDP receive buffer errors (`UdpRcvbufErrors`, `Udp6RcvbufErrors`):

## Notes

- Keep command list and links to raw exported artifacts in `data/`.
