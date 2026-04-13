# Pre-Resize Baseline

<!-- cspell:ignore Rcvbuf -->

## Context

Capture baseline immediately before resizing from CCX23 to CCX33.

## Snapshot

- Date (UTC): 2026-04-13T15:27:46Z
- Server plan: CCX23
- vCPU / RAM: 4 / 16 GB
- Traffic allowance: 20 TB

## Load and Uptime Baseline

- HTTP1 req/s (Prometheus `rate(...[5m])`): ~1350.05
- UDP1 req/s (Prometheus `rate(...[5m])`): ~1507.10
- Total req/s: ~2857.15
- Req/s per vCPU: ~714.29
- UDP newTrackon uptime (%): 92.20%

## Reliability and Capacity Signals

- `udp_tracker_server_errors_total` (1h/increase): ~52983.82
- `udp_tracker_server_requests_aborted_total` (1h/increase): ~283.18
- `udp_tracker_server_responses_sent_total{result="error"}` (1h/increase): ~52983.82
- Host load average (1m/5m/15m): 6.57 / 6.54 / 6.66
- UDP receive buffer errors (`UdpRcvbufErrors`, `Udp6RcvbufErrors`): 18444 / 494

## Notes

- Keep command list and links to raw exported artifacts in `data/`.
- Prometheus query method used (`http_rps_5m`):
  `sum(rate(http_tracker_core_requests_received_total{server_binding_protocol="http",server_binding_port="7070"}[5m]))`
- Prometheus query method used (`udp_rps_5m`):
  `sum(rate(udp_tracker_server_requests_received_total{server_binding_protocol="udp",server_binding_port="6969"}[5m]))`
- Prometheus query method used (`udp_errors_1h`):
  `sum(increase(udp_tracker_server_errors_total{server_binding_protocol="udp",server_binding_port="6969"}[1h]))`
- Prometheus query method used (`udp_aborted_1h`):
  `sum(increase(udp_tracker_server_requests_aborted_total{server_binding_protocol="udp",server_binding_port="6969"}[1h]))`
- Prometheus query method used (`udp_error_responses_1h`):
  `sum(increase(udp_tracker_server_responses_sent_total{server_binding_protocol="udp",server_binding_port="6969",result="error"}[1h]))`
