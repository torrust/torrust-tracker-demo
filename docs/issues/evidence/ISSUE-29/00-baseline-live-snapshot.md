<!-- cspell:ignore CPUPerc urlencode -->

# ISSUE-29 Baseline Live Snapshot (Phase 1)

## Context

- Issue: [#29](https://github.com/torrust/torrust-tracker-demo/issues/29)
- Capture timestamp (UTC): `2026-05-04T15:20:07Z`
- Goal: record a pre-change baseline before any production tuning action.

## Commands Used

```bash
ssh demotracker 'date -u +%Y-%m-%dT%H:%M:%SZ; uptime; nproc'
ssh demotracker 'mpstat -P ALL 1 1'
ssh demotracker 'ps -eo pid,comm,%cpu,%mem,stat --sort=-%cpu | head -20'
ssh demotracker 'cd /opt/torrust && docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"'
ssh demotracker 'sudo sysctl net.netfilter.nf_conntrack_max net.netfilter.nf_conntrack_count net.netfilter.nf_conntrack_udp_timeout net.netfilter.nf_conntrack_udp_timeout_stream'
ssh demotracker 'cat /sys/class/net/eth0/queues/rx-0/rps_cpus; cat /sys/class/net/eth0/queues/rx-0/rps_flow_cnt; sudo sysctl net.core.rps_sock_flow_entries'
ssh demotracker 'curl -sG "http://127.0.0.1:9090/api/v1/query" --data-urlencode "query=sum(rate(http_tracker_core_requests_received_total[5m]))"'
ssh demotracker 'curl -sG "http://127.0.0.1:9090/api/v1/query" --data-urlencode "query=sum(rate(udp_tracker_server_requests_received_total[5m]))"'
ssh demotracker 'curl -sG "http://127.0.0.1:9090/api/v1/query" --data-urlencode "query=sum(rate(http_tracker_core_responses_sent_total{result=\"error\"}[5m]))"'
ssh demotracker 'curl -sG "http://127.0.0.1:9090/api/v1/query" --data-urlencode "query=sum(rate(udp_tracker_server_responses_sent_total{result=\"error\"}[5m]))"'
```

External uptime sampling source:

```text
https://newtrackon.com/raw
```

## Key Results

### Host and CPU

- `uptime`: `load average: 10.46, 9.44, 8.85`
- `nproc`: `8`
- `mpstat` (all CPUs): `%usr=32.81`, `%sys=16.01`, `%soft=20.08`, `%idle=30.97`
- `mpstat` (CPU2): `%soft=100.00`, `%idle=0.00`

### Top CPU Processes

- `caddy`: about `279%`
- `torrust-tracker`: about `88.4%`
- `ksoftirqd/2`: about `14.6%`

### Container CPU Snapshot

- `caddy`: `323.16%`
- `tracker`: `84.39%`
- `mysql`: `6.63%`
- `grafana`: `0.37%`
- `prometheus`: `0.02%`

### Conntrack and RX Steering

- `nf_conntrack_max`: `1048576`
- `nf_conntrack_count`: `424607`
- `nf_conntrack_udp_timeout`: `10`
- `nf_conntrack_udp_timeout_stream`: `15`
- `/sys/class/net/eth0/queues/rx-0/rps_cpus`: `00`
- `/sys/class/net/eth0/queues/rx-0/rps_flow_cnt`: `0`
- `net.core.rps_sock_flow_entries`: `0`

### Prometheus Request Rates

- HTTP1 request rate: `1983.1789473684207 req/s`
- UDP1 request rate: `2240.870175438596 req/s`
- Combined request rate: `4224.0491228070167 req/s`
- HTTP error rate query result: empty vector (`0` at sample time)
- UDP error response rate: `26.34035087719298 req/s`

### newTrackon Raw Snapshot (Sample)

Observed at capture window from `newtrackon/raw`:

- `https://http1.torrust-tracker-demo.com:443/announce` -> `Working`
- `udp://udp1.torrust-tracker-demo.com:6969/announce` -> `Working`

## Attached Evidence

- `2026-05-04-htop-snapshot.png` (provided by maintainer)

## Notes

- This baseline is intentionally captured before changing any production setting.
- The first planned production experiment remains Phase 2: disable Caddy HTTP/3
  (`443:443/udp`) only, then observe before any further action.
