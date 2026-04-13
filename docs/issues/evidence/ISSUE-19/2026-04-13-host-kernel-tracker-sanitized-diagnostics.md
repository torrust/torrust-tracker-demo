# ISSUE-19 Evidence: Host/Kernel/Tracker Sanitized Diagnostics (2026-04-13)

<!-- cspell:ignore softirqd kworker ksoftirqd nproc snmp nstat RcvbufErrors SndbufErrors dockerd mysqld loadavg ppid etimes perc containerd multipathd upgr csum rcvbuf sndbuf -->

## Context

Second-stage diagnostics snapshot for issue #19.

This capture intentionally avoids secrets and client-identifying raw payloads:

- No environment dumps
- No config file dumps
- No raw tracker announce lines with query strings
- Tracker logs are included only as aggregated counts

## Command

```bash
ssh demotracker 'set -e; echo "=== now_utc ==="; date -u; echo "=== cpu_load_context ==="; nproc; cat /proc/loadavg; echo "=== top_cpu_processes ==="; ps -eo pid,ppid,comm,%cpu,%mem,etimes --sort=-%cpu | head -n 15; echo "=== top_mem_processes ==="; ps -eo pid,ppid,comm,%mem,%cpu,etimes --sort=-%mem | head -n 15; echo "=== docker_stats_snapshot ==="; docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"; echo "=== udp_snmp_counters ==="; grep "^Udp:" /proc/net/snmp; echo "=== udp_nstat_counters ==="; nstat -az 2>/dev/null | grep -Ei "Udp(InErrors|NoPorts|RcvbufErrors|SndbufErrors|InDatagrams|OutDatagrams)|Udp6(InErrors|NoPorts|RcvbufErrors|SndbufErrors|InDatagrams|OutDatagrams)" | head -n 50 || true; echo "=== tracker_log_summary_last_60m ==="; cd /opt/torrust; LOGS=$(docker compose logs tracker --since 60m 2>&1 || true); echo "udp_response_error_total=$(printf "%s" "$LOGS" | grep -c "UDP TRACKER: response error" || true)"; echo "udp_warn_abort_no_finished_tasks_total=$(printf "%s" "$LOGS" | grep -c "aborting request: (no finished tasks)" || true)"; echo "invalid_announce_event_total=$(printf "%s" "$LOGS" | grep -c "Invalid announce event" || true)"; echo "cookie_expired_total=$(printf "%s" "$LOGS" | grep -c "cookie value is expired" || true)"; echo "cookie_from_future_total=$(printf "%s" "$LOGS" | grep -c "cookie value is from future" || true)"; echo "invalid_action_total=$(printf "%s" "$LOGS" | grep -c "Invalid action" || true)"'
```

## Output

```text
=== now_utc ===
Mon Apr 13 14:31:19 UTC 2026
=== cpu_load_context ===
4
8.39 7.76 7.41 9/456 909795
=== top_cpu_processes ===
    PID    PPID COMMAND         %CPU %MEM ELAPSED
 789376  789355 caddy            188  2.3    9534
 761900  761878 torrust-tracker 76.3  3.9   11644
 909792  909791 bash            50.0  0.0       0
   1271       1 dockerd         16.2  0.6  736245
 761878       1 containerd-shim 14.6  0.1   11644
 761657  761635 mysqld           5.7  3.4   11657
 909791  909720 sshd             4.7  0.0       0
 909450       2 kworker/u8:4-ev  2.9  0.0      21
 898765       2 kworker/u8:0-ev  1.8  0.0     840
 876355       2 kworker/u8:3-ev  1.4  0.0    2622
 903431       2 kworker/u8:1-ev  1.2  0.0     487
     24       2 ksoftirqd/2      1.2  0.0  736255
 894545       2 kworker/u8:2-ev  1.2  0.0    1167
 909720 1460563 sshd             1.0  0.0       0
=== top_mem_processes ===
    PID    PPID COMMAND         %MEM %CPU ELAPSED
 761900  761878 torrust-tracker  3.9 76.3   11644
 761657  761635 mysqld           3.4  5.7   11657
 789376  789355 caddy            2.3  188    9534
 789690  789668 grafana          1.7  0.4    9527
   1271       1 dockerd          0.6 16.2  736245
 789528  789494 prometheus       0.5  0.0    9533
1460567       1 systemd-journal  0.4  0.0  287386
    949       1 containerd       0.3  0.3  736246
    410       1 multipathd       0.1  0.0  736250
 762108    1271 docker-proxy     0.1  0.0   11630
    960       1 unattended-upgr  0.1  0.0  736246
 762113    1271 docker-proxy     0.1  0.0   11630
 761878       1 containerd-shim  0.1 14.6   11644
 789355       1 containerd-shim  0.1  0.0    9534
=== docker_stats_snapshot ===
NAME         CPU %     MEM USAGE / LIMIT     NET I/O           BLOCK I/O
grafana      7.54%     95.32MiB / 15.24GiB   548kB / 14.1MB    1.6MB / 19.8MB
prometheus   0.04%     23.5MiB / 15.24GiB    3.15MB / 1.18MB   0B / 4.95MB
caddy        190.76%   382.8MiB / 15.24GiB   40.3GB / 79.9GB   0B / 24.6kB
tracker      73.98%    606.1MiB / 15.24GiB   12.7GB / 10.2GB   4.1kB / 24.6kB
mysql        4.31%     507.7MiB / 15.24GiB   703MB / 815MB     100MB / 4.36GB
=== udp_snmp_counters ===
Udp: InDatagrams NoPorts InErrors OutDatagrams RcvbufErrors SndbufErrors InCsumErrors IgnoredMulti MemErrors
Udp: 367996 147312 18444 431790 18444 0 0 0 0
=== udp_nstat_counters ===
UdpInDatagrams                  367996             0.0
UdpNoPorts                      147312             0.0
UdpInErrors                     18444              0.0
UdpOutDatagrams                 431790             0.0
UdpRcvbufErrors                 18444              0.0
UdpSndbufErrors                 0                  0.0
Udp6InDatagrams                 81549              0.0
Udp6NoPorts                     39320              0.0
Udp6InErrors                    494                0.0
Udp6OutDatagrams                9153               0.0
Udp6RcvbufErrors                494                0.0
Udp6SndbufErrors                0                  0.0
=== tracker_log_summary_last_60m ===
udp_response_error_total=0
udp_warn_abort_no_finished_tasks_total=1
invalid_announce_event_total=213
cookie_expired_total=175
cookie_from_future_total=18
invalid_action_total=55
```

## Notes

- Load is high on a 4 vCPU host (`loadavg` around 8), with `caddy` and
  `torrust-tracker` as top CPU consumers.
- UDP receive buffer errors are present (`UdpRcvbufErrors` / `Udp6RcvbufErrors`),
  which is a strong signal to investigate socket/kernel buffer pressure.
- Aggregated tracker counters show high invalid/expired/future announce patterns,
  but no raw client-identifying request payloads were stored in this file.
