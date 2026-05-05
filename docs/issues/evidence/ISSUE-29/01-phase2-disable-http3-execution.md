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

| Checkpoint | Target time (UTC)    | Status   |
| ---------- | -------------------- | -------- |
| T+1 h      | 2026-05-04 16:31     | complete |
| T+next day | 2026-05-05 06:16 UTC | complete |

Capture the same metrics at each checkpoint: `mpstat`, `docker stats`, Prometheus
HTTP1/UDP1 rates, and a `newtrackon.com/raw` sample.

## T+1 h Observation (2026-05-04T16:54:13Z)

Capture timestamp (UTC): `2026-05-04T16:54:13Z` (~1 h 36 min after change).

- Host load average: `8.52 / 8.25 / 8.03`
- `mpstat` all CPUs: `%usr=34.11`, `%sys=15.43`, `%soft=19.58`, `%idle=30.61`
- `mpstat` CPU2: `%soft=100.00`, `%idle=0.00` — **unchanged from pre-change**
- Container CPU snapshot:
  - `caddy`: `321.33%`
  - `tracker`: `95.47%`
  - `mysql`: `7.06%`
  - `grafana`: `0.32%`
  - `prometheus`: `0.00%`
- `ps` top processes: `caddy 301%`, `torrust-tracker 88.9%`, `ksoftirqd/2 15.0%`
- Prometheus rates:
  - HTTP1 request rate: `1834.0 req/s`
  - UDP1 request rate: `2440.0 req/s`

### External probe sample (newtrackon.com/raw)

- `https://http1.torrust-tracker-demo.com:443/announce` -> `Working`
- `udp://udp1.torrust-tracker-demo.com:6969/announce` -> `Working`

### Assessment

**No improvement observed.** CPU2 remains 100% softirq (`ksoftirqd/2` still
pinned). Load, Caddy CPU (~320%), and tracker CPU (~95%) are all within the same
range as before the change. Removing the Caddy UDP 443 port had no measurable
effect on the softirq saturation, ruling out HTTP/3 (QUIC) as the root cause.

The Phase 2 change is safe to keep (it was correct hygiene — we have no HTTP/3
listener anyway), but it did not solve the CPU problem. The investigation must
continue with Phase 3 (RPS/RFS CPU affinity) or a deeper look at why Caddy
alone is consuming ~300% CPU at the observed request rate.

Keep this single change in place until both checkpoints are completed before
deciding whether to keep HTTP/3 disabled permanently or revert.

## T+next-day Observation (2026-05-05T06:16:14Z)

Capture timestamp (UTC): `2026-05-05T06:16:14Z` (~14 h 46 min after change).

- Host load average: `8.69 / 8.45 / 8.51`
- `mpstat` all CPUs: `%usr=29.57`, `%sys=14.92`, `%soft=19.71`, `%idle=35.67`
- `mpstat` CPU2: `%soft=98.02`, `%idle=1.98` — **unchanged from T+1 h**
- Container CPU snapshot:
  - `caddy`: `308.89%`
  - `tracker`: `93.22%`
  - `mysql`: `7.58%`
  - `grafana`: `0.32%`
  - `prometheus`: `0.00%`
- `ps` top processes: `caddy 296%`, `torrust-tracker 88.7%`, `ksoftirqd/2 17.8%`
- Prometheus rates:
  - HTTP1 request rate: `1909.11 req/s`
  - UDP1 request rate: `2178.98 req/s`

### External probe sample (newtrackon.com/raw)

- `https://http1.torrust-tracker-demo.com:443/announce` -> `Working`
- `udp://udp1.torrust-tracker-demo.com:6969/announce` -> `Working`

### Assessment

**Confirmed: Phase 2 had no effect.** After ~15 hours all metrics are
statistically identical to both the pre-change baseline and the T+1 h snapshot.
CPU2 remains saturated at ~98% softirq (`ksoftirqd/2` pinned), Caddy is still
~300–310% CPU, and tracker ~88–95%. Load average is stable at ~8.5.

**Phase 2 decision: keep the change.** Removing `443:443/udp` from Caddy was
correct hygiene (no HTTP/3 listener was in use), but it is not the source of
the CPU issue. The change causes no regressions and removes an unused
port mapping.

**Root cause is elsewhere.** The softirq saturation on a single CPU is
consistent with all UDP/TCP packet processing being steered to one core.
Confirmed that RPS/RFS are currently disabled on this host. **Phase 3 (enable
RPS/RFS)** is the next isolated change to attempt.
