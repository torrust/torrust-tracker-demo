---
name: scale-up-server
description: Step-by-step workflow for resizing (scaling up) the Hetzner server in the torrust-tracker-demo stack. Use when asked to resize, scale up, or upgrade the server plan. Covers pre-resize preparation, graceful shutdown, provider panel action, post-resize recovery, and evidence capture. Triggers on "resize server", "scale up", "upgrade server plan", "Hetzner resize", "change server type".
metadata:
  author: torrust
  version: "1.0"
---

<!-- cspell:ignore nproc Rcvbuf snmp nstat urlencode -->

# Scaling Up the Server

## Overview

This skill covers a **planned, live resize** of the Hetzner Cloud server:
shut down services gracefully, resize the instance in the provider panel,
restart services, and validate everything before re-opening to traffic.

> **Important**: Resizing a Hetzner Cloud server **does not change IP addresses**.
> Neither the public IPv4/IPv6 addresses nor any attached Floating IPs are
> affected. DNS records and Floating IP assignments do not need updating.
> This is standard cloud-provider behavior for in-place resizes.

## Responsibilities

| Step                                | Who                    |
| ----------------------------------- | ---------------------- |
| Capture pre-resize baseline         | AI assistant           |
| Graceful service shutdown           | AI assistant (via SSH) |
| Resize in Hetzner Cloud panel       | **Human operator**     |
| Post-resize recovery and validation | AI assistant (via SSH) |
| Document evidence and commit        | AI assistant           |

---

## Workflow

### Step 1 — Capture pre-resize baseline

Before touching the server, record the current state so there is a before/after
reference. Save results to the issue-scoped evidence folder
(`docs/issues/evidence/ISSUE-<N>/00-pre-resize-baseline.md`).

```bash
# Host snapshot
ssh demotracker 'date -u; nproc; free -h; uptime; df -h'

# Docker services
ssh demotracker 'cd /opt/torrust && docker compose ps'

# Prometheus request rates (5m window)
ssh demotracker 'curl -sG "http://127.0.0.1:9090/api/v1/query" \
  --data-urlencode "query=sum(rate(http_tracker_core_requests_received_total{server_binding_protocol=\"http\",server_binding_port=\"7070\"}[5m]))"'

ssh demotracker 'curl -sG "http://127.0.0.1:9090/api/v1/query" \
  --data-urlencode "query=sum(rate(udp_tracker_server_requests_received_total{server_binding_protocol=\"udp\",server_binding_port=\"6969\"}[5m]))"'

# UDP buffer error counters
ssh demotracker 'grep "^Udp:" /proc/net/snmp; nstat -az 2>/dev/null | grep -Ei "UdpRcvbufErrors|Udp6RcvbufErrors" || true'
```

Commit the baseline file before proceeding to shutdown.

### Step 2 — Confirm readiness

Before shutting down:

- Baseline file is complete and committed.
- Branch is clean and pushed.
- Nightly backup window awareness (~03:00 UTC). Prefer resizing outside that window.
- Operator is available to complete the Hetzner panel action promptly.

### Step 3 — Graceful service shutdown (AI assistant)

Run from a local terminal. Capture the full output and record it in
`docs/issues/evidence/ISSUE-<N>/01-resize-execution.md`.

```bash
ssh demotracker 'set -e
  echo "=== shutdown-start-utc ==="
  date -u +%Y-%m-%dT%H:%M:%SZ
  cd /opt/torrust
  echo "=== docker-compose-ps-before ==="
  docker compose ps
  echo "=== docker-compose-down ==="
  docker compose down
  echo "=== docker-compose-ps-after ==="
  docker compose ps
  echo "=== shutdown-end-utc ==="
  date -u +%Y-%m-%dT%H:%M:%SZ'
```

Confirm all containers are stopped and networks are removed before handing over.

### Step 4 — Resize in Hetzner Cloud panel (human operator)

1. Log in to [Hetzner Cloud Console](https://console.hetzner.cloud/).
2. Navigate to the project and select the server (`torrust-tracker-demo` or similar).
3. Go to **Rescale** (or **Server type**) tab.
4. Select the target server type (e.g. CCX33) and confirm.
5. Wait for the resize to complete — typically under 2 minutes.
6. Power on the server if it does not start automatically.
7. Notify the AI assistant when the server is reachable again.

> No IP address changes are required. Floating IPs, public IPs, and private
> network IPs all remain the same after a Hetzner in-place resize.

### Step 5 — Post-resize recovery (AI assistant)

Start all services and capture the new host profile:

```bash
ssh demotracker 'set -e
  echo "=== startup-utc ==="
  date -u +%Y-%m-%dT%H:%M:%SZ
  echo "=== host ==="
  nproc; free -h; uptime
  cd /opt/torrust
  echo "=== docker-compose-up ==="
  docker compose up -d
  echo "=== docker-compose-ps ==="
  docker compose ps'
```

### Step 6 — Post-resize validation (AI assistant)

Run all checks and record outputs in the execution log.

```bash
# Container health
ssh demotracker 'cd /opt/torrust && docker compose ps'

# UDP buffer counters (should be zero after fresh boot)
ssh demotracker 'grep "^Udp:" /proc/net/snmp; nstat -az 2>/dev/null | grep -Ei "UdpRcvbufErrors|Udp6RcvbufErrors" || true'

# Prometheus targets
ssh demotracker 'curl -sG "http://127.0.0.1:9090/api/v1/query" \
  --data-urlencode "query=up{job=\"tracker_metrics\"}"
  curl -sG "http://127.0.0.1:9090/api/v1/query" \
  --data-urlencode "query=up{job=\"tracker_stats\"}"'
```

External checks (from local machine):

```bash
# HTTP tracker health
curl -fsS "https://http1.torrust-tracker-demo.com/health_check"

# Grafana (302 to /login is expected)
curl -I "https://grafana.torrust-tracker-demo.com"

# UDP port probe
nc -zvu udp1.torrust-tracker-demo.com 6969 2>&1 | head -5
```

All services must reach `healthy` status, HTTP health must return `200`,
and Prometheus targets must show `up=1` before the resize is considered
complete.

> The tracker API health endpoint (`/health_check` on `api.torrust-tracker-demo.com`)
> requires authentication and returns `500 unauthorized` without a token.
> This is expected and not a failure indicator.

### Step 7 — Document and commit

Fill in the execution log (`01-resize-execution.md`) with all checklist items,
the full timeline (start UTC / end UTC / total impact window), the command
outputs, and the validation results.

Run linters before committing:

```bash
./scripts/lint.sh
```

Commit with:

```bash
git commit -S -m "docs(issue-<N>): document resize execution and post-resize validation" \
  -m "Refs: #<N>"
```

### Step 8 — Update infrastructure docs

After the resize is confirmed stable:

- Update the hardware table in `docs/infrastructure.md` to reflect the new
  server type, vCPU count, RAM, storage, traffic allowance, and price.
- Add a row to `docs/infrastructure-resize-history.md` with the resize date,
  old and new plan, throughput at resize time, normalized req/s per vCPU,
  and a link to the related issue.

---

## Post-Resize Observation Period

After the resize, monitor for at least **7 days** before concluding success:

- Fill one row per day in `docs/issues/evidence/ISSUE-<N>/02-post-resize-daily-checks.md`
  using the same Prometheus queries from Step 1.
- Check external uptime from [newTrackon](https://newtrackon.com/) or similar.
- Watch UDP buffer error counters for any resurgence.

Once the observation window is complete, fill the final comparison table in
`docs/issues/evidence/ISSUE-<N>/03-pre-post-comparison.md` and decide whether
the resize meets the acceptance criteria.
