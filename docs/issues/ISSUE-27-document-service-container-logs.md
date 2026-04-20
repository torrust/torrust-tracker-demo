# Document Normal and Notable Service Container Logs

**Issue**: [#27](https://github.com/torrust/torrust-tracker-demo/issues/27)

## Overview

While investigating unexpected log output from the Grafana container, we realised we had no
reference for what "normal" looks like for any of the services running in the demo. This made
it hard to judge whether a repeated log message was a real problem, a known quirk, or expected
behaviour.

This issue proposes creating a `docs/logs/` section in the repository to document container log
output for each service: what is normal, what is noise, what signals a real problem, and why.
The goal is to avoid repeating the same investigation the next time we see an unfamiliar message.

## Background: What Triggered This

On 2026-04-20 we examined `docker logs grafana` and saw the following message repeating every
30 seconds:

```text
INFO [04-20|...] No last resource version found, starting from scratch logger=dashboard-service orgID=1
```

We did not know whether this was a bug, a misconfiguration, or normal. After research we
determined it is **expected behaviour in Grafana 12** introduced by the new Kubernetes-style
unified storage API (`dashboard-service`). Grafana watches this API for dashboard changes using
a resource version. When file-based provisioning is used (as in this demo), the storage backend
has no persistent resource version to return, so the watch resets every 30 seconds and logs this
message. Dashboards still load correctly from the file provider.

No action is required for this message — but it took investigation time to confirm that.

## Proposed Structure

Create a `docs/logs/` directory organised by service:

```text
docs/logs/
  README.md           ← explains the purpose and how to read the sections
  grafana.md          ← Grafana container log reference
  tracker.md          ← Tracker container log reference (future)
  prometheus.md       ← Prometheus container log reference (future)
  mysql.md            ← MySQL container log reference (future)
  caddy.md            ← Caddy container log reference (future)
```

Each service file should cover:

- **How to read the logs** — the command to run and what the log format looks like.
- **Normal steady-state messages** — messages that always appear and are safe to ignore.
- **Periodic housekeeping messages** — messages that appear on a schedule and what they mean.
- **Notable messages that need investigation** — patterns that indicate real problems.
- **Version notes** — behaviour that changed between versions.

## Content for `docs/logs/grafana.md` (seed content from this investigation)

### How to read Grafana logs

```bash
ssh demotracker "docker logs grafana --tail 100 2>&1"
# or follow live:
ssh demotracker "docker logs grafana -f 2>&1"
```

Log format: `LEVEL [MM-DD|HH:MM:SS] <message> logger=<component> [key=value ...]`

### Normal steady-state messages (Grafana 12.x)

| Message                                                 | Frequency    | Logger                   | Explanation                                                                                                                                                                             |
| ------------------------------------------------------- | ------------ | ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `No last resource version found, starting from scratch` | Every 30 s   | `dashboard-service`      | Grafana 12 unified storage API watch reset. Normal when using file-based provisioning. The watch finds no stored resource version and restarts from scratch. Dashboards load correctly. |
| `flag evaluation succeeded`                             | Every 10 min | `plugins.update.checker` | Plugin auto-update feature flag evaluated as `false` (disabled). Expected.                                                                                                              |
| `Update check succeeded`                                | Every 10 min | `plugins.update.checker` | Grafana checked for plugin updates successfully. Expected.                                                                                                                              |
| `Completed cleanup jobs`                                | Every 10 min | `cleanup`                | Routine database cleanup (sessions, temp files, etc.) completed. Expected.                                                                                                              |

### Periodic housekeeping messages (Grafana 12.x)

| Message                           | Frequency           | Logger             | Explanation                                                        |
| --------------------------------- | ------------------- | ------------------ | ------------------------------------------------------------------ |
| `Building index using memory`     | On demand / ~10 min | `bleve-backend`    | Search index rebuilt for dashboards or folders. Normal.            |
| `Finished building index`         | On demand / ~10 min | `bleve-backend`    | Confirms the index rebuild completed.                              |
| `Storing index in cache`          | On demand / ~10 min | `bleve-backend`    | Search index cached with a 10-minute TTL.                          |
| `index evicted from cache`        | ~10 min             | `bleve-backend`    | Cache TTL expired; index will be rebuilt on next search. Normal.   |
| `Usage stats are ready to report` | Periodic            | `infra.usagestats` | Anonymous usage statistics prepared for reporting to Grafana Labs. |

### Messages that warrant investigation

| Pattern                     | Possible cause                                              |
| --------------------------- | ----------------------------------------------------------- |
| `level=error` or `ERRO`     | Any component error; read the full line                     |
| `level=warn` or `WARN`      | Any component warning; may be ignorable, may not            |
| `database is locked`        | SQLite contention — check if multiple processes are writing |
| `failed to connect`         | Data source (Prometheus) unreachable                        |
| `context deadline exceeded` | Query timeout; Prometheus may be overloaded or down         |
| `provisioning failed`       | Dashboard or datasource YAML has a syntax error             |

### Version notes

- Grafana 12 introduced the unified storage API and the `dashboard-service` watch loop.
  The `No last resource version found` message does **not** appear in Grafana 11 or earlier.

## Implementation Plan

- [ ] Create `docs/logs/README.md` explaining the section's purpose.
- [ ] Create `docs/logs/grafana.md` with the seed content from this investigation.
- [ ] Add placeholder stubs for `tracker.md`, `prometheus.md`, `mysql.md`, `caddy.md`
      so future investigations have a clear home.

## Acceptance Criteria

- [ ] `docs/logs/` directory exists with a `README.md` and `grafana.md`.
- [ ] `grafana.md` documents at minimum: how to read logs, the `dashboard-service` watch
      message, and the periodic housekeeping messages observed on 2026-04-20.
- [ ] Stub files exist for the remaining services.
- [ ] All files pass `./scripts/lint.sh`.
