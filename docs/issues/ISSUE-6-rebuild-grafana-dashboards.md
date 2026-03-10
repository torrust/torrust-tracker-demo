# Rebuild Grafana Dashboards for New Multi-Protocol Dual-Stack Tracker

**Issue**: [#6](https://github.com/torrust/torrust-tracker-demo/issues/6)

## Overview

The demo was deployed using the
[Torrust Tracker Deployer](https://github.com/torrust/torrust-tracker-deployer),
which includes a basic Grafana configuration with two provisioned dashboards
(`stats.json` and `metrics.json`). These dashboards were designed for the
**old Torrust Index + Tracker demo**, which ran a single UDP tracker with
IPv4 only.

The tracker exposes metrics via two endpoints:

- **Stats** (`/api/v1/stats`) — the legacy endpoint, still available.
- **Metrics** (`/api/v1/metrics`) — the newer, extensible endpoint.

In the old demo, both dashboards existed solely to verify that the two
endpoints produced the same data. In this demo we only need the **Metrics**
endpoint. The Stats dashboard and the Stats Prometheus scrape job can be
removed.

## Current Configuration

### Tracker services (from `tracker.toml`)

<!-- markdownlint-disable MD013 -->

| Service        | Bind Address | Public Endpoint                            |
| -------------- | ------------ | ------------------------------------------ |
| UDP Tracker 1  | `[::]:6969`  | `udp://udp1.torrust-tracker-demo.com:6969` |
| UDP Tracker 2  | `[::]:6868`  | `udp://udp1.torrust-tracker-demo.com:6868` |
| HTTP Tracker 1 | `[::]:7070`  | `https://http1.torrust-tracker-demo.com`   |
| HTTP Tracker 2 | `[::]:7071`  | `https://http2.torrust-tracker-demo.com`   |

<!-- markdownlint-enable MD013 -->

All services bind to `[::]`, meaning they accept both IPv4 (`inet`) and
IPv6 (`inet6`) connections.

### Existing dashboards (from deployer)

| File           | Endpoint used     | Covers        |
| -------------- | ----------------- | ------------- |
| `metrics.json` | `/api/v1/metrics` | UDP IPv4 only |
| `stats.json`   | `/api/v1/stats`   | UDP IPv4 only |

### Available metric labels

The Metrics endpoint exposes per-service metrics with labels:

- `server_binding_address_ip_family` — always `inet6` in the current setup
  (all services bind to `[::]` dual-stack sockets; IPv4 clients appear as
  IPv4-mapped IPv6 addresses `::ffff:<ipv4>` in logs but the socket family
  is always reported as `inet6` in metrics)
- `server_binding_port` — the port number (`6969`, `6868`, `7070`, `7071`);
  this is the correct label to filter per service instance
- `request_kind` — `connect`, `announce`, `scrape`
- `peer_role` — `seeder`, `leecher`

> **Key finding**: The planned "IPv4 vs IPv6 dual series" design is not
> viable. Because all sockets are dual-stack, `server_binding_address_ip_family`
> is always `inet6` regardless of whether the connecting client is IPv4 or
> IPv6. Use `server_binding_port` to distinguish between service instances.

## Proposed New Dashboard Structure

Replace the two existing **provisioned** dashboards with **five** new
dashboards created directly in the Grafana UI. All use the Metrics endpoint
only. Each service instance gets its own dedicated dashboard showing its
metrics as a single `inet6` series (filtering by `server_binding_port`).

IPv4 vs IPv6 filtering per dashboard is not yet possible because
`server_binding_address_ip_family` is always `inet6` in the current
dual-stack setup. Dashboards will be refactored once one of these
preconditions is met (see [Future improvements](#future-improvements)):

- Separate IPv4/IPv6 socket bindings are implemented in the tracker, or
- A `client_address_ip_type` label is added to tracker metrics.

### 1. Tracker Overview

Global aggregate metrics shared across all protocols and IP families:

- Completed downloads (stat)
- Torrents (stat)
- Seeders (stat)
- Leechers (stat)

### 2. UDP Tracker 1 (port 6969)

UDP request/response metrics for the public UDP instance filtered by
`server_binding_port=6969`:

- Connections (per sec)
- Announces (per sec)
- Scrapes (per sec)
- Errors (per sec)
- Avg connect time
- Avg announce time
- Avg scrape time
- Banned requests (per sec)
- Requests & responses (per sec)
- Banned IPs
- Aborted requests (per sec)

### 3. UDP Tracker 2 (port 6868)

UDP request/response metrics for the testing UDP instance filtered by
`server_binding_port=6868`. Same panels as UDP Tracker 1.

### 4. HTTP Tracker 1 (port 7070)

HTTP request/response metrics for the public HTTP instance filtered by
`server_binding_port=7070`.
Note: the live metrics endpoint currently only exposes
`http_tracker_core_requests_received_total` for HTTP — other panels
(errors, timing, banned) may be empty until the tracker exposes them:

- Announces (per sec)
- Scrapes (per sec)
- Errors (per sec)
- Avg announce time
- Avg scrape time
- Banned requests (per sec)
- Requests & responses (per sec)
- Banned IPs
- Aborted requests (per sec)

### 5. HTTP Tracker 2 (port 7071)

HTTP request/response metrics for the testing HTTP instance filtered by
`server_binding_port=7071`. Same panels as HTTP Tracker 1.

### Future improvements

When one of the following is implemented, the dashboards can be refactored
to show separate IPv4 and IPv6 series per panel:

- **Option A** — separate socket bindings: configure the tracker with one
  `0.0.0.0:<port>` socket (IPv4-only) and one `[::]:<port>` socket
  (IPv6-only) per service. Requires `net.ipv6.bindv6only = 1` or a kernel
  that allows binding both on the same port (currently blocked by
  `EADDRINUSE` — see
  [ADR-001](../adr/ADR-001-dual-stack-socket-vs-separate-ipv4-ipv6-sockets.md)).
- **Option B** — client IP type label: add a `client_address_ip_type` label
  to tracker metrics counters so that IPv4-mapped addresses
  (`::ffff:<ipv4>`) can be distinguished in Grafana without changing the
  socket model.

### Implementation approach

1. Create dashboard JSON files locally for import into Grafana UI
   (not provisioned via config).
2. Import and verify on the live Grafana instance.
3. Iterate until dashboards display data correctly.
4. Once verified, export final versions from Grafana and store as
   backups in this repo.
5. Remove old provisioned dashboards (`stats.json`, `metrics.json`)
   from server config and restart Grafana.

### Notes

- The live `/api/v1/metrics` endpoint confirms that
  `server_binding_address_ip_family` is always `inet6` for all services.
  IPv4 clients connect via IPv4-mapped IPv6 addresses (`::ffff:<ipv4>`)
  but the socket family seen by metrics is always `inet6`.
- Use `server_binding_port` to filter per instance: UDP1=6969, UDP2=6868,
  HTTP1=7070, HTTP2=7071.
- HTTP metrics are currently sparse — only
  `http_tracker_core_requests_received_total` is exposed. Error, timing,
  and banned-IP panels for HTTP may remain empty until more metrics are
  added to the tracker.
- UDP metrics are richer and match the existing `metrics.json` pattern
  (e.g. `udp_tracker_server_*`).

## Changes Required

### Provisioned dashboards to remove (on server)

| File           | Reason                              |
| -------------- | ----------------------------------- |
| `metrics.json` | Replaced by the five new dashboards |
| `stats.json`   | Stats endpoint is no longer needed  |

### Prometheus config update

Consider removing the `tracker_stats` scrape job from
`prometheus.yml` since the Stats endpoint is no longer needed.

## Tasks

- [ ] Create draft dashboard JSON files for import (one per service)
- [ ] Import into Grafana and verify they display data
- [ ] Filter each dashboard by its `server_binding_port` value
- [ ] Verify HTTP tracker panels (expect most to be empty initially)
- [ ] Remove provisioned `metrics.json` and `stats.json`
      from server and restart Grafana
- [ ] Remove `tracker_stats` scrape job from
      `prometheus.yml` (optional)
- [ ] Export final dashboards and store backups in repo

## Acceptance Criteria

- [ ] Old provisioned dashboards are removed
- [ ] Five new dashboards display data in Grafana
      (Overview, UDP1, UDP2, HTTP1, HTTP2)
- [ ] Each service dashboard is filtered by its own `server_binding_port`
- [ ] All dashboards use the Metrics endpoint only
- [ ] Final dashboard JSON backups are stored in repo
