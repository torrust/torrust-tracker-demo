# ISSUE-31 Evidence — T+1h Snapshot

**Issue:** [#31 Re-enable Caddy HTTP/3 and Document ISSUE-29 Rationale][issue-31]  
**Scope:** Post-change stability checkpoint (T+1h target window)  
**Captured:** 2026-05-07 16:29:55 UTC  
**Author:** Jose Celano

[issue-31]: https://github.com/torrust/torrust-tracker-demo/issues/31

---

## 1. Context

The T+1h checkpoint was scheduled for approximately 14:17 UTC. This capture was
performed at 16:29 UTC, still valid as a post-change steady-state checkpoint.

Primary objective: verify that re-enabling Caddy edge HTTP/3 (`443:443/udp`)
remains healthy and does not show immediate regression versus the restart-biased
T+0 snapshot.

---

## 2. Commands Executed and Outputs

### 2.1 Full capture command

```bash
cat <<'EOS' | ssh demotracker 'bash -s'
set -euo pipefail

echo '=== ISSUE-31 T+1h snapshot ==='
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

echo '--- api stats endpoint status (expected pre-existing unauthorized) ---'
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
UTC_TIME=2026-05-07T16:29:55Z
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
load average: 11.46, 9.87, 9.73
```

`mpstat -P ALL 1 1` (aggregate):

| Metric | Value |
| ------ | ----- |
| %usr   | 34.69 |
| %sys   | 14.54 |
| %soft  | 30.23 |
| %idle  | 20.41 |

`docker stats --no-stream`:

| Container  | CPU%    | Memory             |
| ---------- | ------- | ------------------ |
| caddy      | 420.91% | 481.9MiB / 30.6GiB |
| tracker    | 120.47% | 795.3MiB / 30.6GiB |
| mysql      | 5.94%   | 663.3MiB / 30.6GiB |
| grafana    | 0.48%   | 309.1MiB / 30.6GiB |
| prometheus | 0.00%   | 99.62MiB / 30.6GiB |

Prometheus rates (5m):

```text
HTTP1: 1902.150877192982 req/s
UDP1:  2053.5017543859644 req/s
```

newtrackon raw sample:

```text
Returns HTML document content (same behavior as T+0), not a plain tracker status line.
```

---

## 3. Comparison vs T+0 Snapshot

| Signal             | T+0 (13:17) | T+1h checkpoint (16:29) | Notes                    |
| ------------------ | ----------- | ----------------------- | ------------------------ |
| Caddy health       | healthy     | healthy                 | Stable                   |
| UDP 443 published  | yes         | yes                     | Stable                   |
| UDP 443 listeners  | yes         | yes                     | Stable                   |
| HTTP health code   | 200         | 200                     | Stable                   |
| HTTP1 rate (req/s) | 2116.38     | 1902.15                 | Normal variation         |
| UDP1 rate (req/s)  | 2238.84     | 2053.50                 | Normal variation         |
| Caddy CPU%         | 717.12      | 420.91                  | Lower than restart spike |
| Load avg (1m)      | 18.93       | 11.46                   | Lower than restart spike |

---

## 4. Rollback Trigger Check (Interim)

Configured rollback triggers require sustained 24h regressions.

1. Caddy CPU > baseline x 1.20 sustained 24h: **not evaluable yet (window incomplete)**
2. Host load > baseline x 1.15 sustained 24h: **not evaluable yet (window incomplete)**
3. External availability regression on HTTP1/UDP1: **not observed in this checkpoint**

Interim conclusion: no rollback action indicated at T+1h checkpoint.

---

## 5. Notes and Open Point

The API stats endpoint returned `404` in this snapshot, while the earlier note
recorded `500 unauthorized`.

This endpoint behavior is not part of ISSUE-31 acceptance criteria and does not
affect the HTTP/3 edge re-enable validation. It should be tracked separately if
API stats exposure is required for operations.

---

## 6. Summary

- Caddy edge HTTP/3 publish mapping remains active and healthy on IPv4 and IPv6.
- Request rates remain in expected operating range.
- T+0 restart artifacts have subsided (lower load and lower Caddy CPU than the
  immediate post-restart spike).
- No rollback trigger is met at this checkpoint.
- Next required checkpoint: T+next-day snapshot.
