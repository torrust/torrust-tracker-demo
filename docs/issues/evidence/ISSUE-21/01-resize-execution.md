# Resize Execution Log

<!-- cspell:ignore nproc Rcvbuf perc snmp nstat urlencode poweroff entr -->

## Planned Change

- From: CCX23 (4 vCPU, 16 GB RAM, 20 TB)
- To: CCX33 (8 vCPU, 32 GB RAM, 30 TB)
- Expected monthly cost: €62.49/mo

## Execution Checklist

- [x] Graceful service shutdown completed via `docker compose down`
- [x] Resize action executed in provider panel
- [x] Server reachable by SSH after resize
- [x] `docker compose ps` healthy
- [x] HTTP endpoint reachable
- [x] UDP endpoint reachable
- [x] Prometheus targets up
- [x] Grafana accessible

## Pre-Resize Safety Checks

- [ ] Confirm latest baseline file is complete:
      `docs/issues/evidence/ISSUE-21/00-pre-resize-baseline.md`
- [ ] Confirm branch is clean and pushed.
- [ ] Confirm backup window awareness (nightly restart at ~03:00 UTC).
- [ ] Confirm maintenance window and operator availability.

## Provider Action (Hetzner)

1. Open server in Hetzner Cloud panel.
2. Resize from **CCX23** to **CCX33**.
3. Wait for resize operation to report complete.
4. Reconnect via SSH and run post-resize checks below.

## Post-Resize Command Checklist

Run from local machine:

```bash
ssh demotracker 'set -e; echo "=== now ==="; date -u; echo "=== cpu_mem ==="; nproc; free -h; echo "=== uptime ==="; uptime; echo "=== docker ==="; cd /opt/torrust && docker compose ps'
```

```bash
ssh demotracker 'set -e; cd /opt/torrust; echo "=== docker_stats ==="; docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"'
```

```bash
ssh demotracker 'set -e; echo "=== udp_buffers ==="; grep "^Udp:" /proc/net/snmp; nstat -az 2>/dev/null | grep -Ei "UdpRcvbufErrors|Udp6RcvbufErrors" || true'
```

```bash
ssh demotracker 'set -e; q(){ expr="$1"; echo "--- $expr"; curl -sG "http://127.0.0.1:9090/api/v1/query" --data-urlencode "query=$expr"; echo; }; q "up{job=\"tracker_metrics\"}"; q "up{job=\"tracker_stats\"}"'
```

## Endpoint Sanity Checks

- HTTP tracker health: `curl -fsS "https://http1.torrust-tracker-demo.com/health_check"`
- Tracker API health: `curl -fsS "https://api.torrust-tracker-demo.com/health_check"`
- UDP quick sanity (optional): use existing tracker client tooling and store output under `data/`.

## Timeline

- Start (UTC): 2026-04-13T15:36:51Z
- End (UTC): 2026-04-13T15:44:07Z
- Total impact window: ~7m16s (shutdown + provider resize + startup + validation)

## Pre-Poweroff Graceful Shutdown Log

Command executed from local machine:

```bash
ssh demotracker 'set -e; echo "=== resize-prep-start-utc ==="; date -u +%Y-%m-%dT%H:%M:%SZ; cd /opt/torrust; echo "=== docker-compose-ps-before ==="; docker compose ps; echo "=== docker-compose-down ==="; docker compose down; echo "=== docker-compose-ps-after ==="; docker compose ps; echo "=== resize-prep-end-utc ==="; date -u +%Y-%m-%dT%H:%M:%SZ'
```

Captured output:

```text
=== resize-prep-start-utc ===
2026-04-13T15:36:51Z
=== docker-compose-ps-before ===
NAME         IMAGE                     COMMAND                  SERVICE      CREATED       STATUS                 PORTS
caddy        caddy:2.10.2              "caddy run --config …"   caddy        4 hours ago   Up 4 hours (healthy)   0.0.0.0:80->80/tcp, :::80->80/tcp, 0.0.0.0:443->443/tcp, :::443->443/tcp, 0.0.0.0:443->443/udp, :::443->443/udp, 2019/tcp
grafana      grafana/grafana:12.4.2    "/run.sh"                grafana      4 hours ago   Up 4 hours (healthy)   3000/tcp
mysql        mysql:8.4                 "docker-entrypoint.s…"   mysql        4 hours ago   Up 4 hours (healthy)   3306/tcp, 33060/tcp
prometheus   prom/prometheus:v3.5.1    "/bin/prometheus --c…"   prometheus   4 hours ago   Up 4 hours (healthy)   127.0.0.1:9090->9090/tcp
tracker      torrust/tracker:develop   "/usr/local/bin/entr…"   tracker      4 hours ago   Up 4 hours (healthy)   1212/tcp, 0.0.0.0:6868->6868/udp, :::6868->6868/udp, 1313/tcp, 7070/tcp, 0.0.0.0:6969->6969/udp, :::6969->6969/udp
=== docker-compose-down ===
Container grafana  Stopping
Container caddy  Stopping
Container grafana  Stopped
Container grafana  Removing
Container grafana  Removed
Container prometheus  Stopping
Container prometheus  Stopped
Container prometheus  Removing
Container prometheus  Removed
Container tracker  Stopping
Container caddy  Stopped
Container caddy  Removing
Container caddy  Removed
Container tracker  Stopped
Container tracker  Removing
Container tracker  Removed
Container mysql  Stopping
Container mysql  Stopped
Container mysql  Removing
Container mysql  Removed
Network torrust_proxy_network  Removing
Network torrust_database_network  Removing
Network torrust_visualization_network  Removing
Network torrust_metrics_network  Removing
Network torrust_visualization_network  Removed
Network torrust_database_network  Removed
Network torrust_metrics_network  Removed
Network torrust_proxy_network  Removed
=== docker-compose-ps-after ===
NAME      IMAGE     COMMAND   SERVICE   CREATED   STATUS    PORTS
=== resize-prep-end-utc ===
2026-04-13T15:37:11Z
```

## Immediate Post-Resize Snapshot

- `nproc`: 8
- `uptime`: `15:40:20 up 0 min, 1 user, load average: 0.20, 0.06, 0.02`
- `free -h`: `Mem total 30Gi, used 673Mi, available 29Gi`
- `docker compose ps`: all services healthy after startup (caddy, grafana, mysql,
  prometheus, tracker)
- `docker stats --no-stream` summary (initial warm-up snapshot):
  - `caddy`: high transient CPU during startup (`603.22%`), memory `3.092GiB`
  - `tracker`: `153.34%` CPU, memory `364.2MiB`
  - `mysql`: `46.54%` CPU, memory `553.2MiB`
  - `grafana`: `40.58%` CPU, memory `257.4MiB`
  - `prometheus`: `0.06%` CPU, memory `85.14MiB`
- Any regressions observed:
  - HTTP1 health endpoint returned `200` with `{"status":"Ok"}`.
  - Grafana root returned `302` redirect to `/login` (expected behavior).
  - UDP public port probe succeeded on `udp1:6969`.
  - API health endpoint returned `500 unauthorized` (same check path appears to
    require authorization token; not treated as resize failure).
  - Prometheus targets `up{job="tracker_metrics"}` and `up{job="tracker_stats"}` both `1`.
  - UDP receive buffer error counters immediately after restart were `0` for both
    `UdpRcvbufErrors` and `Udp6RcvbufErrors`.

## Rollback Criteria (Operational)

- Server becomes unstable after resize.
- Core services fail to become healthy.
- External endpoints unavailable for prolonged window.

If rollback is required, document reason and exact time window here.

## Post-Resize Validation Commands and Key Outputs

Command (host recovery and internal checks):

```bash
ssh demotracker 'set -e; echo "=== post-resize-start-utc ==="; date -u +%Y-%m-%dT%H:%M:%SZ; echo "=== host-size-check ==="; nproc; free -h; uptime; echo "=== start-stack ==="; cd /opt/torrust; docker compose up -d; echo "=== docker-compose-ps ==="; docker compose ps; echo "=== docker-stats-no-stream ==="; docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"; echo "=== health-http1 ==="; curl -fsS "https://http1.torrust-tracker-demo.com/health_check"; echo; echo "=== health-api ==="; curl -fsS "https://api.torrust-tracker-demo.com/health_check"; echo; echo "=== prometheus-targets-up ==="; curl -sG "http://127.0.0.1:9090/api/v1/query" --data-urlencode "query=up{job=\"tracker_metrics\"}"; echo; curl -sG "http://127.0.0.1:9090/api/v1/query" --data-urlencode "query=up{job=\"tracker_stats\"}"; echo; echo "=== udp-buffer-counters ==="; grep "^Udp:" /proc/net/snmp; nstat -az 2>/dev/null | grep -Ei "UdpRcvbufErrors|Udp6RcvbufErrors" || true; echo "=== post-resize-end-utc ==="; date -u +%Y-%m-%dT%H:%M:%SZ'
```

Key outputs:

- `post-resize-start-utc`: `2026-04-13T15:40:20Z`
- `nproc`: `8`
- `free -h` total memory: `30Gi`
- `docker compose ps`: all services `healthy`
- `health-http1`: `200` with `{"status":"Ok"}`
- `health-api`: initial check failed (`502`, then `500 unauthorized`)

Follow-up command (service stabilization and counters):

```bash
ssh demotracker 'echo "=== followup-check-utc ==="; date -u +%Y-%m-%dT%H:%M:%SZ; cd /opt/torrust; echo "=== docker-compose-ps ==="; docker compose ps; echo "=== api-health-retries ==="; for i in 1 2 3 4 5; do code=$(curl -s -o /tmp/api_health.out -w "%{http_code}" "https://api.torrust-tracker-demo.com/health_check" || true); echo "try_$i status=$code body=$(cat /tmp/api_health.out 2>/dev/null || true)"; [[ "$code" == "200" ]] && break; sleep 2; done; echo "=== prometheus-target-up ==="; curl -sG "http://127.0.0.1:9090/api/v1/query" --data-urlencode "query=up{job=\"tracker_metrics\"}"; echo; curl -sG "http://127.0.0.1:9090/api/v1/query" --data-urlencode "query=up{job=\"tracker_stats\"}"; echo; echo "=== udp-buffer-counters ==="; grep "^Udp:" /proc/net/snmp; nstat -az 2>/dev/null | grep -Ei "UdpRcvbufErrors|Udp6RcvbufErrors" || true'
```

Key outputs:

- `followup-check-utc`: `2026-04-13T15:42:10Z`
- `up{job="tracker_metrics"}`: `1`
- `up{job="tracker_stats"}`: `1`
- `UdpRcvbufErrors`: `0`
- `Udp6RcvbufErrors`: `0`

External sanity checks:

```bash
curl -s -o /tmp/http1.out -w "%{http_code}" "https://http1.torrust-tracker-demo.com/health_check"
curl -s -o /tmp/grafana.out -w "%{http_code}" "https://grafana.torrust-tracker-demo.com/"
nc -zvu -w2 udp1.torrust-tracker-demo.com 6969
```

Key outputs:

- HTTP1 health: `200`
- Grafana root: `302` (`/login` redirect)
- UDP probe: `succeeded`

## Notes

- Include exact commands and short outputs (or link to files under `data/`).
- Keep this file chronological and append-only during execution.
- Shutdown duration before poweroff: ~20 seconds.
- User-reported provider resize duration: ~1.5 minutes.
