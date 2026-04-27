# Post-Resize Daily Checks (7 Days)

<!-- cspell:ignore Rcvbuf snmp utilization -->

## Daily Log Template

| Day | Date (UTC) | HTTP1 req/s  | UDP1 req/s  | Total req/s | Req/s per vCPU | UDP uptime (%) | UDP errors trend | UDP aborted trend | Host load trend | Notes                                                                                                                                             |
| --- | ---------- | ------------ | ----------- | ----------- | -------------- | -------------- | ---------------- | ----------------- | --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| D+1 | 2026-04-20 | ~1564        | ~1015       | ~2579       | ~322           | 83.9%          | ~37k/h (pre-fix) | 0                 | 6.05/5.49/4.80  | conntrack table full (262144/262144); fixed: nf_conntrack_max→1048576, UDP timeouts reduced; also includes planned resize downtime on 2026-04-14  |
| D+2 | 2026-04-21 |              |             |             |                | 85.70%         |                  |                   |                 | Rolling uptime still low, but recent [newTrackon raw](https://newtrackon.com/raw) probes are currently successful; likely lag from prior failures |
| D+3 | 2026-04-22 |              |             |             |                |                |                  |                   |                 | Uptime recovering post-fix; rolling window still catching up                                                                                      |
| D+4 | 2026-04-23 |              |             |             |                |                |                  |                   |                 | Uptime recovering post-fix; rolling window still catching up                                                                                      |
| D+5 | 2026-04-24 |              |             |             |                |                |                  |                   |                 | Uptime recovering post-fix; rolling window still catching up                                                                                      |
| D+6 | 2026-04-25 |              |             |             |                |                |                  |                   |                 | Uptime recovering post-fix; rolling window still catching up                                                                                      |
| D+7 | 2026-04-27 | ~2000 (peak) | ~750 (peak) |             |                | 99.9%          |                  |                   |                 | Target met: 99.9% >= 99.0%; 7-day window complete; issue resolved; peak req/s across 7-day window: HTTP1 ~2000, UDP1 ~750                         |

## D+7 newTrackon Snapshot (2026-04-27)

Source: newTrackon live tracker table captured 2026-04-27.

| Tracker URL                                           | Uptime | Status              | Checked        |
| ----------------------------------------------------- | ------ | ------------------- | -------------- |
| `https://http1.torrust-tracker-demo.com:443/announce` | 99.90% | Working for 2 days  | 7 minutes ago  |
| `udp://udp1.torrust-tracker-demo.com:6969/announce`   | 99.90% | Working for 6 hours | 10 minutes ago |

Both trackers above the 99.0% target. 7-day observation window complete.
Issue resolved as **Success**.

## D+7 Live Verification Snapshot (2026-04-27)

Checked immediately before merging PR #22 to confirm conntrack is healthy at
peak traffic (~750 UDP req/s, ~2000 HTTP req/s).

Command run:

```bash
ssh demotracker '
  echo "=== conntrack counts ===" &&
  sudo sysctl net.netfilter.nf_conntrack_max net.netfilter.nf_conntrack_count &&
  echo "=== UDP timeouts ===" &&
  sudo sysctl net.netfilter.nf_conntrack_udp_timeout net.netfilter.nf_conntrack_udp_timeout_stream &&
  echo "=== dmesg table full ===" &&
  sudo dmesg -T | grep -i "nf_conntrack: table full" | tail -10 &&
  echo "(no output = no table-full events)" &&
  echo "=== UDP receive errors ===" &&
  cat /proc/net/snmp | grep -E "^Udp:" |
    awk "NR==1{for(i=1;i<=NF;i++) h[i]=\$i} NR==2{for(i=1;i<=NF;i++) print h[i]\": \"\$i}" |
    grep -E "RcvbufErrors|InErrors|NoPorts" &&
  echo "=== UDP6 receive errors ===" &&
  cat /proc/net/snmp6 | grep -E "Udp6RcvbufErrors|Udp6InErrors|Udp6NoPorts"
'
```

Results:

- `nf_conntrack_max`: `1048576`
- `nf_conntrack_count`: `341652` (`32.59%` of max)
- `nf_conntrack_udp_timeout`: `10`
- `nf_conntrack_udp_timeout_stream`: `15`
- `dmesg` table-full events: none
- `UdpRcvbufErrors` (IPv4): `0`
- `UdpInErrors` (IPv4): `0`
- `UdpNoPorts` (IPv4): `57519` — benign; probes to closed ports, not tracker drops
- `Udp6RcvbufErrors` (IPv6): `56` — negligible cumulative counter since boot
- `Udp6InErrors` (IPv6): `56`
- `Udp6NoPorts` (IPv6): `26183` — benign; same as above

Interpretation: conntrack table is at 32.6% utilization. No table-full events
in dmesg. No IPv4 UDP receive-buffer drops. The 56 IPv6 errors are a cumulative
boot-time counter at ~750 req/s peak and are statistically insignificant.
Conntrack is not overflowing; safe to merge.

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
