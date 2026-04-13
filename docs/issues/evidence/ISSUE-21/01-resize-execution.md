# Resize Execution Log

<!-- cspell:ignore nproc Rcvbuf perc snmp nstat urlencode -->

## Planned Change

- From: CCX23 (4 vCPU, 16 GB RAM, 20 TB)
- To: CCX33 (8 vCPU, 32 GB RAM, 30 TB)
- Expected monthly cost: €62.49/mo

## Execution Checklist

- [ ] Resize action executed in provider panel
- [ ] Server reachable by SSH after resize
- [ ] `docker compose ps` healthy
- [ ] HTTP endpoint reachable
- [ ] UDP endpoint reachable
- [ ] Prometheus targets up
- [ ] Grafana accessible

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

- Start (UTC):
- End (UTC):
- Total impact window:

## Immediate Post-Resize Snapshot

- `uptime`:
- `free -h`:
- `docker stats --no-stream` summary:
- Any regressions observed:

## Rollback Criteria (Operational)

- Server becomes unstable after resize.
- Core services fail to become healthy.
- External endpoints unavailable for prolonged window.

If rollback is required, document reason and exact time window here.

## Notes

- Include exact commands and short outputs (or link to files under `data/`).
- Keep this file chronological and append-only during execution.
