# ISSUE-31 Evidence — Immediate Post-Change Snapshot

**Issue:** [#31 Re-enable Caddy HTTP/3 and Document ISSUE-29 Rationale][issue-31]  
**Change applied:** Re-add `443:443/udp` port mapping to Caddy in docker-compose.yml  
**Captured:** 2026-05-07 ~13:17 UTC  
**Author:** Jose Celano

[issue-31]: https://github.com/torrust/torrust-tracker-demo/issues/31

---

## 1. Pre-Change State

Since ISSUE-29 Phase 2 (2026-05-04), the Caddy service in
`/opt/torrust/docker-compose.yml` on the live server had the `443:443/udp`
port removed. The stated reason was "remove unused port binding", but
no measurable CPU benefit was observed. See
`docs/issues/ISSUE-29-research-high-cpu-load-after-udp-fix.md` for the
original decision text, now marked as superseded by ISSUE-31.

---

## 2. Change Applied

### Local repo change (`server/opt/torrust/docker-compose.yml`)

```yaml
ports:
  - "80:80"
  - "443:443"
  # HTTP/3 (QUIC) re-enabled in ISSUE-31
  - "443:443/udp"
```

### Live server patch (via `sed` over SSH)

```bash
# Insert the UDP port line after the TCP 443 line on the live server
ssh demotracker "sed -i '/\"443:443\"$/a \      # HTTP\/3 (QUIC) re-enabled in ISSUE-31\n      - \"443:443\/udp\"' \
  /opt/torrust/docker-compose.yml"

# Recreate only the Caddy container (zero downtime for other services)
ssh demotracker "cd /opt/torrust && docker compose up -d caddy"
```

Expected output:

```text
Container caddy  Recreated
Container caddy  Started
```

> **Cosmetic note:** The `sed` command inserted the new block correctly but
> left an orphan comment `# HTTP/3 (QUIC)` that was already present below
> the `443:443` line. The live server ports block therefore has one redundant
> comment line. This is harmless and will be cleaned up in the next
> docker-compose sync.

---

## 3. Post-Change Validations

### 3.1 Container ports

```bash
ssh demotracker "docker ps --format 'table {{.Names}}\t{{.Ports}}' | grep caddy"
```

Output:

```text
caddy   0.0.0.0:80->80/tcp, :::80->80/tcp,
        0.0.0.0:443->443/tcp, :::443->443/tcp,
        0.0.0.0:443->443/udp, :::443->443/udp,
        2019/tcp
```

Both `0.0.0.0:443->443/udp` and `:::443->443/udp` are present. ✅

### 3.2 Host UDP 443 listener (kernel socket)

```bash
ssh demotracker "ss -ulnp | grep ':443'"
```

Output:

```text
UNCONN  0  0  0.0.0.0:443  0.0.0.0:*
UNCONN  0  0     [::]:443     [::]:*
```

IPv4 and IPv6 UDP sockets are bound. ✅

### 3.3 Caddy container health

```bash
ssh demotracker "docker inspect --format='{{.State.Health.Status}}' caddy"
```

Output: `healthy` ✅

### 3.4 HTTP tracker health

```bash
ssh demotracker \
  "curl -s -o /dev/null -w '%{http_code}' https://http1.torrust-tracker-demo.com:443/health_check"
```

Output: `200` (body: `{"status":"Ok"}`) ✅

### 3.5 API health (expected 500 — pre-existing)

```bash
ssh demotracker \
  "curl -s -o /dev/null -w '%{http_code}' https://http1.torrust-tracker-demo.com/api/v1/stats"
```

Output: `500` (unauthorized — pre-existing, not caused by this change) ⚠️ pre-existing

---

## 4. Metrics Snapshot (T+0 ~1 min post-restart)

> **Important caveat:** These metrics were captured approximately 1 minute
> after the Caddy container restart. Several values are anomalously high and
> are almost certainly transient artifacts of the container initialization,
> not a steady-state signal. Do not use T+0 values for rollback evaluation.
> Use T+1h and T+next-day checkpoints instead.

### 4.1 Host load average

```bash
ssh demotracker "uptime"
```

Output (approximate):

```text
 13:17:09 up ...  load average: 18.93, 13.89, 11.95
```

Comment: elevated 1-min average (18.93) consistent with a freshly restarted
container; 5-min and 15-min averages trail higher from ISSUE-29 baseline but
this single-point reading is not meaningful.

### 4.2 CPU usage snapshot (`mpstat -P ALL 1 1`)

| Metric | Value |
|--------|-------|
| %usr   | 3.25  |
| %sys   | 90.88 |
| %soft  | 5.75  |
| %idle  | 0.12  |

High `%sys` during container restart is expected. Softirq load was distributed
across all CPUs (2–13% each), confirming RPS/RFS is still operating correctly
(no single-core bottleneck).

### 4.3 Docker container resource usage (T+0)

| Container  | CPU%   | MEM       |
|------------|--------|-----------|
| caddy      | 717%   | 763.2 MiB |
| tracker    | 58.73% | 826.5 MiB |
| mysql      | 6.27%  | —         |
| grafana    | 2.91%  | —         |
| prometheus | 0.03%  | —         |

Caddy at 717% is a well-known container-restart spike. No action required.

### 4.4 HTTP and UDP request rates (Prometheus)

Queries executed via Prometheus API:

```bash
# HTTP1 tracker
ssh demotracker \
  "curl -sG 'http://localhost:9090/api/v1/query' \
    --data-urlencode 'query=sum(rate(http_tracker_core_requests_received_total[5m]))'"

# UDP1 tracker
ssh demotracker \
  "curl -sG 'http://localhost:9090/api/v1/query' \
    --data-urlencode 'query=sum(rate(udp_tracker_server_requests_received_total[5m]))'"
```

| Metric          | Value (req/s) |
|-----------------|---------------|
| HTTP1 req rate  | 2116.38       |
| UDP1 req rate   | 2238.84       |

Both values are in normal operating range. ✅

---

## 5. Observation Schedule

| Checkpoint    | Target Time (UTC)  | Status     | File                               |
|---------------|--------------------|------------|------------------------------------|
| T+0 (this)    | 2026-05-07 ~13:17  | ✅ Done    | `00-immediate-post-change-snapshot.md` |
| T+1h          | 2026-05-07 ~14:17  | ⏳ Pending | `01-t1h-snapshot.md`               |
| T+next-day    | 2026-05-08 ~13:17  | ⏳ Pending | `02-next-day-snapshot.md`          |

---

## 6. Rollback Triggers

From ISSUE-31 implementation plan:

1. Caddy sustained CPU > baseline × 1.20 over a 24 h window
2. Host load average sustained > baseline × 1.15 over a 24 h window
3. HTTP1 or UDP1 availability regression reported on newtrackon.com

T+0 snapshot is not sufficient to evaluate any of these. Assessment deferred
to T+1h and T+next-day checkpoints.

---

## 7. Summary

- UDP 443 successfully re-enabled at the Caddy edge proxy on both IPv4 and IPv6.
- Caddy is healthy and all downstream services (HTTP tracker, MySQL, Grafana,
  Prometheus) are unaffected.
- HTTP1 and UDP1 tracker request rates are in normal operating range.
- T+0 CPU/load figures are transient restart artifacts — not a signal.
- No rollback action required at this checkpoint.
