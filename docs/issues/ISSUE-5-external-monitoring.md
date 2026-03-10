# Add External Monitoring and Alerting

**Issue**: [#5](https://github.com/torrust/torrust-tracker-demo/issues/5)

## Overview

The new Hetzner-based tracker demo has no external monitoring or alerting. When a public
service goes down we only discover it by accident (e.g. checking
[newTrackon](https://newtrackon.com/)) or via user reports. We need a lightweight,
independent monitoring setup that covers the three public services and sends email
notifications when any of them is down.

## What We Had on the Old Demo (Digital Ocean — Index + Tracker)

Digital Ocean provides built-in monitoring tools. The old demo used two categories:

### Resource Alerts (per droplet)

Triggered when a threshold is exceeded for a sustained period:

| Metric                     | Threshold | Duration |
| -------------------------- | --------- | -------- |
| Disk Utilization Percent   | > 85 %    | 1 hour   |
| Memory Utilization Percent | > 90 %    | 1 hour   |
| CPU Utilization Percent    | > 85 %    | 1 hour   |

### Uptime Checks

HTTPS checks run from the Europe region:

| Name         | URL                                                 |
| ------------ | --------------------------------------------------- |
| HTTP Tracker | `https://tracker.torrust-demo.com/health_check`     |
| Tracker API  | `https://tracker.torrust-demo.com/api/health_check` |

Notes:

- UDP monitoring was **not possible** on Digital Ocean (no UDP probe support).
- The Torrust Tracker exposes an internal health check API that tests all subsystems,
  but it is bound to `127.0.0.1:1313` and is **not publicly accessible**:

  ```toml
  [health_check_api]
  bind_address = "127.0.0.1:1313"
  ```

- UDP service health was only observable indirectly via newTrackon, with **no
  notifications** configured.
- No notification channels (email or otherwise) were configured on the old demo either.

## Current State on the New Demo (Hetzner)

The new demo exposes the following public endpoints. HTTPS services are proxied through
Caddy; UDP services are exposed directly (no reverse proxy):

| Service          | Public Endpoint                                     | Internal Port | Purpose           |
| ---------------- | --------------------------------------------------- | ------------- | ----------------- |
| Tracker REST API | `https://api.torrust-tracker-demo.com`              | `1212`        | Public            |
| HTTP Tracker 1   | `https://http1.torrust-tracker-demo.com`            | `7070`        | Public            |
| HTTP Tracker 2   | `https://http2.torrust-tracker-demo.com`            | `7071`        | Testing/debugging |
| Grafana          | `https://grafana.torrust-tracker-demo.com`          | `3000`        | Internal          |
| UDP Tracker 1    | `udp://udp1.torrust-tracker-demo.com:6969/announce` | `6969`        | Public            |
| UDP Tracker 2    | `udp://udp1.torrust-tracker-demo.com:6868/announce` | `6868`        | Testing/debugging |

Only HTTP Tracker 1 and UDP Tracker 1 are submitted to
[newTrackon](https://newtrackon.com/) and intended for public use. HTTP Tracker 2 and
UDP Tracker 2 exist for testing and debugging purposes and do not need to be monitored.

Hetzner does **not** provide built-in uptime checks or resource alerting tools
equivalent to Digital Ocean's. The Prometheus + Grafana stack already running on the
server can handle internal resource monitoring but is not suitable as the sole alerting
mechanism — if the server itself goes down, Grafana goes with it.

## Goals

1. **External and independent** — the monitoring system must not run on the same
   infrastructure being monitored. If the server goes down, alerts must still fire.
   Ideally it should run on a different provider or a different Hetzner region.
2. **Open-source and self-hosted** — prefer tools we control and can deploy ourselves
   over third-party SaaS. SaaS services are acceptable as a fallback if no suitable
   self-hosted option is found.
3. **Cover the three primary public services:**
   - Tracker REST API
   - HTTP Tracker 1
   - UDP Tracker 1
4. **Email notification** only after the service has been down for a sustained period
   (e.g. 10 minutes) to avoid false-positive alerts. Check interval: every 5 minutes.
5. **Nice-to-have — internal resource alerts:** CPU, disk, and memory usage monitoring
   with email notifications, similar to the Digital Ocean resource alerts. This can be
   implemented inside the existing Prometheus + Grafana + Alertmanager stack.

## Preliminary Research

The following options are identified as starting points for the research phase. Each
candidate needs to be evaluated in detail before a decision is made (see Tasks).

### Option A — Self-Hosted Uptime Monitor

Open-source uptime monitoring tools that can be deployed on an independent host
(different Hetzner region or different provider) as a Docker container:

| Tool                                                   | Language | HTTP | UDP       | Email alerts | Notes                              |
| ------------------------------------------------------ | -------- | ---- | --------- | ------------ | ---------------------------------- |
| [Uptime Kuma](https://github.com/louislam/uptime-kuma) | Node.js  | Yes  | Port only | Yes          | Popular; good UI; active community |
| [Gatus](https://github.com/TwiN/gatus)                 | Go       | Yes  | No        | Yes          | Config-driven; lightweight         |
| [Vigil](https://github.com/valeriansaliou/vigil)       | Rust     | Yes  | No        | Yes          | Rust-based; minimal footprint      |

Note: none of these tools perform a real BitTorrent UDP announce — they can only check
that a UDP port is reachable. The research phase should confirm whether any tool
supports custom UDP protocol probes.

### Option B — Custom Dockerized Checker (tracker_checker)

The Torrust Tracker repository already includes a
[tracker-client](https://github.com/torrust/torrust-tracker/tree/develop/console/tracker-client)
package with a
[`tracker_checker`](https://github.com/torrust/torrust-tracker/blob/develop/console/tracker-client/src/bin/tracker_checker.rs)
binary. This binary accepts a JSON configuration listing the services to check and
performs **real protocol-level probes** — including UDP announces — which none of the
other tools can do.

The checker would be packaged as a Docker image and run on an **independent host** —
not on the same server as the services it monitors. Possible deployment targets include:

- A cheap VPS on a different provider or Hetzner region.
- A PaaS / container-hosting service (e.g. Fly.io, Railway, Render).
- A serverless / lambda-style function (e.g. AWS Lambda, Google Cloud Run) triggered
  on a schedule.
- A GitHub Actions scheduled workflow.

The JSON configuration lists the services to probe; the checker runs on a cron schedule,
performs real HTTP and UDP announces against the public endpoints, and reports failures.

**Advantages:**

- Full protocol coverage — can perform a real UDP announce, not just a port-open check.
  This would have caught the IPv6 routing issue documented in
  [ISSUE-2](ISSUE-2-udp-tracker-down-on-newtrackon.md).
- Reuses existing, maintained Rust code from the main tracker repository.
- Configuration-driven — the JSON config lists the services to check, making it easy to
  add or remove endpoints.
- No external account or third-party dependency required beyond the hosting platform.
- Satisfies goal 1 (external and independent) when deployed on a separate host.

**Disadvantages:**

- Requires building and maintaining a Docker image for the checker.
- Email sending needs an SMTP relay or external email service.
- The checker binary currently reports results to stdout; a notification mechanism
  (email, webhook) would need to be added or wrapped around it.

### Option C — SaaS Uptime Monitor (fallback)

If no suitable self-hosted solution is found, the following free-tier SaaS services
support HTTPS health checks with email notifications:

| Service                                                     | Free checks | Min interval | HTTPS | UDP        | Email alerts | Notes                                                            |
| ----------------------------------------------------------- | ----------- | ------------ | ----- | ---------- | ------------ | ---------------------------------------------------------------- |
| [UptimeRobot](https://uptimerobot.com/)                     | 50          | 5 min        | Yes   | Yes (port) | Yes          | Most widely used; UDP is a port-open check, not a protocol check |
| [Better Uptime](https://betterstack.com/better-uptime)      | 10          | 3 min        | Yes   | No         | Yes          | Clean UI; no UDP support                                         |
| [Freshping](https://www.freshworks.com/website-monitoring/) | 50          | 1 min        | Yes   | No         | Yes          | Part of Freshworks suite                                         |
| [StatusCake](https://www.statuscake.com/)                   | unlimited   | 5 min        | Yes   | No         | Yes          | Free tier has limited locations                                  |

Same UDP limitation applies: SaaS tools can only check that UDP port 6969 is reachable,
not perform a real BitTorrent announce. [newTrackon](https://newtrackon.com/) remains
the only external source for full-protocol UDP health visibility but provides no
notification mechanism.

### Option D — Internal Resource Monitoring (Goal 5 — nice-to-have)

The server already runs Prometheus and Grafana, so host-level metrics can be added with
minimal effort using the standard Prometheus ecosystem — no external service required.

**Step 1 — Collect host metrics with node_exporter:**

[node_exporter](https://github.com/prometheus/node_exporter) is the official Prometheus
exporter for host hardware and OS metrics (CPU, memory, disk, network, etc.). It runs
as a Docker container alongside the existing stack, exposes metrics on port 9100, and
Prometheus scrapes it like any other target. It requires one extra service in
`docker-compose.yml` and one additional scrape job in `prometheus.yml`.

**Step 2 — Visualize with Grafana:**

Ready-made Grafana dashboards for node_exporter already exist on
[grafana.com/dashboards](https://grafana.com/grafana/dashboards/) (e.g. the widely used
"Node Exporter Full" dashboard, ID 1860). No custom dashboard work is needed.

**Step 3 — Alert with Alertmanager:**

Adding [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/) to the
Docker Compose stack enables email alerts when Prometheus alert rules fire. Alert rules
are defined in a YAML file and loaded by Prometheus.

Suggested alert rules (mirroring the old Digital Ocean demo thresholds):

| Metric       | Threshold | Duration |
| ------------ | --------- | -------- |
| CPU usage    | > 85 %    | 1 hour   |
| Memory usage | > 90 %    | 1 hour   |
| Disk usage   | > 85 %    | 1 hour   |

This entire setup is open-source, self-hosted, and runs entirely within the existing
stack on the same server. It does **not** satisfy goal 1 (external independence) — if
the server goes down, Alertmanager goes with it — but that is acceptable for resource
alerts since they are a separate concern from service uptime monitoring.

## Tasks

### Research phase

- [ ] Evaluate **Option A** self-hosted uptime tools (Uptime Kuma, Gatus, Vigil):
      confirm Docker support, UDP port check capability, email notification setup,
      and effort to deploy on an independent host.
- [ ] Evaluate **Option B** (`tracker_checker`): confirm the binary can be packaged as
      a Docker image, assess effort to add email notification support (SMTP or webhook),
      and identify a suitable independent host to run it on.
- [ ] Determine whether Option A and Option B can be combined (A for basic reachability
      and B for full protocol-level checks including real UDP announces).
- [ ] If no self-hosted solution is viable, fall back to **Option C** (SaaS) and
      select the most suitable service.
- [ ] Verify that `https://http1.torrust-tracker-demo.com/health_check` and
      `https://api.torrust-tracker-demo.com/health_check` return HTTP 200 and are
      suitable health check targets.
- [ ] Research SMTP relay options for sending alert emails from a self-hosted tool
      (e.g. AWS SES, Mailgun, Brevo free tier, or self-hosted Postfix).

### Implementation phase

- [ ] Deploy the chosen uptime monitoring solution on an independent host.
- [ ] Configure monitors for the three primary services with a 5-minute check interval
      and email alert after 10 minutes of downtime.
- [ ] Document the setup (host, tool, configuration) in this repository.
- [ ] (Nice-to-have) Implement Option D for internal resource monitoring:
      add `node_exporter` to `docker-compose.yml`, configure Prometheus to scrape it,
      import a node_exporter Grafana dashboard, and add Alertmanager with CPU / memory /
      disk alert rules and SMTP email notifications.
