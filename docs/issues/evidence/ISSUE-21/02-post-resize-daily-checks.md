# Post-Resize Daily Checks (7 Days)

<!-- cspell:ignore Rcvbuf -->

## Daily Log Template

| Day | Date (UTC) | HTTP1 req/s | UDP1 req/s | Total req/s | Req/s per vCPU | UDP uptime (%) | UDP errors trend | UDP aborted trend | Host load trend | Notes                                                                                                                                             |
| --- | ---------- | ----------- | ---------- | ----------- | -------------- | -------------- | ---------------- | ----------------- | --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| D+1 | 2026-04-20 | ~1564       | ~1015      | ~2579       | ~322           | 83.9%          | ~37k/h (pre-fix) | 0                 | 6.05/5.49/4.80  | conntrack table full (262144/262144); fixed: nf_conntrack_max→1048576, UDP timeouts reduced; also includes planned resize downtime on 2026-04-14  |
| D+2 | 2026-04-21 |             |            |             |                | 85.70%         |                  |                   |                 | Rolling uptime still low, but recent [newTrackon raw](https://newtrackon.com/raw) probes are currently successful; likely lag from prior failures |
| D+3 |            |             |            |             |                |                |                  |                   |                 |                                                                                                                                                   |
| D+4 |            |             |            |             |                |                |                  |                   |                 |                                                                                                                                                   |
| D+5 |            |             |            |             |                |                |                  |                   |                 |                                                                                                                                                   |
| D+6 |            |             |            |             |                |                |                  |                   |                 |                                                                                                                                                   |
| D+7 |            |             |            |             |                |                |                  |                   |                 |                                                                                                                                                   |

## D+2 Live Verification Snapshot (2026-04-21T07:23:08Z)

- Host check command source: `ssh demotracker` runtime validation
- `nf_conntrack_max`: `1048576`
- `nf_conntrack_count`: `331258` (`31.59%` of max)
- `nf_conntrack_udp_timeout_stream`: `15`
- `nf_conntrack_udp_timeout`: `10`
- `UdpRcvbufErrors`: `0`
- `Udp6RcvbufErrors`: `0`
- `dmesg` check (`sudo -n dmesg -T | grep -i "nf_conntrack: table full" | tail -10`): no recent matches

Interpretation: the configured conntrack sizing and UDP timeouts remain active
on the live host, and there is no current evidence of UDP packet drops caused
by conntrack table saturation.
