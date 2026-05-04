<!-- cspell:ignore CPUPerc -->

# ISSUE-29 Phase 2 Execution - Disable HTTP/3 UDP Port

## Context

- Issue: [#29](https://github.com/torrust/torrust-tracker-demo/issues/29)
- Goal: perform the first isolated production change by removing Caddy UDP 443
  (`443:443/udp`) and restarting only Caddy.
- Change timestamp (UTC): `2026-05-04T15:30:23Z` (edit) and
  `2026-05-04T15:30:45Z` (Caddy restart complete).

## Pre-Change Snapshot

Pre-change live checks confirmed:

- `/opt/torrust/docker-compose.yml` contained:

```yaml
# HTTP/3 (QUIC)
- "443:443/udp"
```

- Host listener existed on UDP 443:

```text
UNCONN 0      0      0.0.0.0:443 0.0.0.0:*
UNCONN 0      0         [::]:443    [::]:*
```

- Caddy published ports included UDP 443.

## Change Applied

### 1) Repository-side tracked config change

`server/opt/torrust/docker-compose.yml` was updated to remove the UDP publish
line for Caddy while keeping TCP 80 and 443 unchanged.

### 2) Live server runtime change

On `demotracker`, in `/opt/torrust/docker-compose.yml`, the line
`- "443:443/udp"` was removed and only Caddy was recreated:

```bash
docker compose up -d caddy
```

Live diff on server:

```diff
 # HTTPS
 - "443:443"
 # HTTP/3 (QUIC)
-- "443:443/udp"
```

## Immediate Post-Change Validation

### Service and port checks

- Caddy container status: `healthy` after recreation.
- Host UDP 443 listener: not present after change.
- HTTP tracker health endpoint:

```http
GET https://http1.torrust-tracker-demo.com/health_check -> 200
{"status":"Ok"}
```

### API health note (not attributed to this change)

During immediate checks:

```http
GET https://api.torrust-tracker-demo.com/health_check -> 500
Unhandled rejection: Err { reason: "unauthorized" }
```

Direct backend check from within Caddy to `tracker:1212/health_check` also
returned HTTP 500 with `unauthorized`, indicating this is upstream API behavior
at capture time, not a reverse-proxy-only failure introduced by the UDP 443
change.

### Immediate post-change metrics sample

Capture timestamp (UTC): `2026-05-04T15:31:33Z`

- Host load average: `7.63 / 8.49 / 8.67`
- `mpstat` all CPUs: `%usr=33.16`, `%sys=15.79`, `%soft=19.08`, `%idle=31.97`
- `mpstat` CPU2: `%soft=98.02`, `%idle=1.98`
- Container CPU snapshot:
  - `caddy`: `319.30%`
  - `tracker`: `100.78%`
  - `mysql`: `4.66%`
  - `grafana`: `0.27%`
  - `prometheus`: `0.00%`
- Prometheus rates:
  - HTTP1 request rate: `1907.1684210526314 req/s`
  - UDP1 request rate: `2269.859649122807 req/s`

### External probe sample

From `https://newtrackon.com/raw` during this window:

- `https://http1.torrust-tracker-demo.com:443/announce` -> `Working`
- `udp://udp1.torrust-tracker-demo.com:6969/announce` -> `Working`

## Observation Schedule

Agreed observation windows for Phase 2:

| Checkpoint | Target time (UTC)        | Status  |
| ---------- | ------------------------ | ------- |
| T+1 h      | 2026-05-04 16:31         | pending |
| T+next day | 2026-05-05 (any morning) | pending |

Capture the same metrics at each checkpoint: `mpstat`, `docker stats`, Prometheus
HTTP1/UDP1 rates, and a `newtrackon.com/raw` sample.

Keep this single change in place until both checkpoints are completed before
deciding whether to keep HTTP/3 disabled permanently or revert.
