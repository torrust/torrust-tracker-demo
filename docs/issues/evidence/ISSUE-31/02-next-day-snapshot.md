# ISSUE-31 Evidence — T+next-day Snapshot

**Issue:** [#31 Re-enable Caddy HTTP/3 and Document ISSUE-29 Rationale][issue-31]  
**Scope:** Post-change next-day checkpoint (T+next-day)  
**Captured:** 2026-05-08 08:37:47 UTC  
**Author:** Jose Celano

[issue-31]: https://github.com/torrust/torrust-tracker-demo/issues/31

---

## 1. Context

This snapshot is the next-day checkpoint for ISSUE-31 after re-enabling Caddy
edge HTTP/3 (`443:443/udp`).

Goal: confirm that the edge HTTP/3 mapping remains active and healthy, and
continue rollback-trigger evaluation after the T+0 and T+1h checkpoints.

---

## 2. Commands Executed and Outputs

### 2.1 Full capture command

```bash
cat <<'EOS' | ssh demotracker 'bash -s'
set -euo pipefail

echo '=== ISSUE-31 T+next-day snapshot ==='
date -u +"UTC_TIME=%Y-%m-%dT%H:%M:%SZ"

echo

echo '--- caddy ports ---'
docker ps --format 'table {{.Names}}\t{{.Ports}}' | grep caddy || true

echo

echo '--- udp listeners :443 ---'
ss -ulnp | grep ':443' || true

echo

echo '--- caddy health ---'
docker inspect --format='{{.State.Health.Status}}' caddy

echo

echo '--- http tracker health ---'
code=$(curl -s -o /tmp/http1_hc.out -w '%{http_code}' https://http1.torrust-tracker-demo.com:443/health_check || true)
echo "HTTP_CODE=$code"
head -c 400 /tmp/http1_hc.out || true
echo

echo

echo '--- api stats endpoint status ---'
code=$(curl -s -o /tmp/api_stats.out -w '%{http_code}' https://http1.torrust-tracker-demo.com/api/v1/stats || true)
echo "HTTP_CODE=$code"
head -c 400 /tmp/api_stats.out || true
echo

echo

echo '--- host uptime/load ---'
uptime

echo

echo '--- mpstat -P ALL 1 1 ---'
mpstat -P ALL 1 1

echo

echo '--- docker stats --no-stream ---'
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}'

echo

echo '--- prometheus HTTP1 rate (5m) ---'
curl -sG 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=sum(rate(http_tracker_core_requests_received_total[5m]))'

echo

echo '--- prometheus UDP1 rate (5m) ---'
curl -sG 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=sum(rate(udp_tracker_server_requests_received_total[5m]))'

echo

echo '--- newtrackon raw page sample ---'
curl -sL 'https://newtrackon.com/raw' | head -c 800

echo
EOS
```

### 2.2 Key outputs captured

Timestamp:

```text
UTC_TIME=2026-05-08T08:37:47Z
```

Caddy ports:

```text
caddy  0.0.0.0:80->80/tcp, [::]:80->80/tcp,
       0.0.0.0:443->443/tcp, [::]:443->443/tcp,
       0.0.0.0:443->443/udp, [::]:443->443/udp, 2019/tcp
```

UDP 443 listeners:

```text
UNCONN 0 0 0.0.0.0:443 0.0.0.0:*
UNCONN 0 0    [::]:443    [::]:*
```

Caddy health:

```text
healthy
```

HTTP tracker health:

```text
HTTP_CODE=200
{"status":"Ok"}
```

API stats endpoint:

```text
HTTP_CODE=404
```

Host load:

```text
load average: 7.38, 7.15, 7.42
```

`mpstat -P ALL 1 1` (aggregate):

| Metric | Value |
| ------ | ----- |
| %usr   | 31.66 |
| %sys   | 14.93 |
| %soft  | 28.70 |
| %idle  | 24.71 |

`docker stats --no-stream`:

| Container  | CPU%    | Memory             |
| ---------- | ------- | ------------------ |
| caddy      | 396.15% | 529.2MiB / 30.6GiB |
| tracker    | 156.71% | 601MiB / 30.6GiB   |
| mysql      | 4.26%   | 611.8MiB / 30.6GiB |
| grafana    | 0.53%   | 300.1MiB / 30.6GiB |
| prometheus | 0.09%   | 98.15MiB / 30.6GiB |

Prometheus rates (5m):

```text
HTTP1: 1872.2701754385962 req/s
UDP1:  1924.9859649122807 req/s
```

newtrackon raw sample:

```text
Returns HTML document content, not a plain tracker status line.
```

---

## 3. Comparison vs Prior Checkpoints

| Signal             | T+0 (13:17)  | T+1h (16:29) | T+next-day (08:37) | Notes                     |
| ------------------ | ------------ | ------------ | ------------------ | ------------------------- |
| Caddy health       | healthy      | healthy      | healthy            | Stable                    |
| UDP 443 published  | yes          | yes          | yes                | Stable                    |
| UDP 443 listeners  | yes          | yes          | yes                | Stable                    |
| HTTP health code   | 200          | 200          | 200                | Stable                    |
| API stats code     | 500/unauth\* | 404          | 404                | Out of scope for ISSUE-31 |
| HTTP1 rate (req/s) | 2116.38      | 1902.15      | 1872.27            | Normal variation          |
| UDP1 rate (req/s)  | 2238.84      | 2053.50      | 1924.99            | Normal variation          |
| Caddy CPU%         | 717.12       | 420.91       | 396.15             | Lower than restart spike  |
| Load avg (1m)      | 18.93        | 11.46        | 7.38               | Lower than restart spike  |

\*The T+0 note recorded `500 unauthorized`; from T+1h onward, `/api/v1/stats` returned `404`.

---

## 4. Rollback Trigger Check (Next-day)

Configured rollback triggers:

1. Caddy CPU > baseline x 1.20 sustained 24h
2. Host load > baseline x 1.15 sustained 24h
3. External availability regression on HTTP1/UDP1

### Assessment

- Trigger 3: **not observed** in this checkpoint.
- Triggers 1 and 2: **inconclusive for sustained 24h comparison** because host uptime
  was only ~6h at capture time and kernel changed to `6.8.0-111-generic`, indicating
  a host restart and new observation window.

Interim conclusion: no immediate rollback signal; continue observation from this
new host-uptime window if strict sustained-24h criteria are required.

---

## 5. Notable Environment Change

This snapshot shows:

- `uptime`: `up 6:37`
- `uname` (from `mpstat` header): `Linux 6.8.0-111-generic`

Compared to earlier snapshots (`6.8.0-110-generic`), this indicates host reboot
or kernel update occurred between checkpoints. This interrupts strict 24h
continuity for baseline comparisons.

---

## 6. Summary

- Caddy edge HTTP/3 mapping (`443:443/udp`) remains active and healthy on IPv4 and IPv6.
- HTTP and UDP tracker traffic rates remain in expected operating range.
- No availability regression observed.
- Sustained-24h rollback-trigger evaluation for CPU/load is interrupted by host reboot;
  results are operationally healthy but not a strict continuous 24h baseline window.
