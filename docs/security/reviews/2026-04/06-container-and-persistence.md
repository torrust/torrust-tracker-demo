# Container and Persistence - 2026-04

**Summary**: [README.md](README.md)
**Progress**: [progress.md](progress.md)

## Scope

- Container privilege model
- Mounted volumes and writable paths
- Secret exposure through runtime configuration
- Lateral movement between services
- Persistence via cron, backups, or writable config

## Hypotheses

- A compromise of the tracker or Grafana container could become persistent
  through writable mounted storage.
- Network segmentation is partial rather than strict, and compromise of one
  internet-facing service may provide access to internal services.

## Evidence Reviewed

- [../../../server/opt/torrust/docker-compose.yml](../../../server/opt/torrust/docker-compose.yml)
- [../../../server/opt/torrust/storage/backup/etc/backup-paths.txt](../../../server/opt/torrust/storage/backup/etc/backup-paths.txt)
- [../../../server/etc/cron.d/tracker-backup](../../../server/etc/cron.d/tracker-backup)
- [../../../server/usr/local/bin/maintenance-backup.sh](../../../server/usr/local/bin/maintenance-backup.sh)

## Checks Performed

- Confirmed the tracker has writable mounts for config, logs, and data.
- Confirmed Grafana and MySQL use persistent storage.
- Confirmed the backup workflow reads configuration and database state and
  writes archives under persistent storage.
- Confirmed tracker spans `metrics_network`, `database_network`, and
  `proxy_network`, making it the most connected internet-facing service.

## Findings or Non-Findings

- No confirmed finding yet. The current configuration creates several
  persistence and lateral-movement paths that need runtime and source review.

## Open Questions

- Which services run as root inside their containers?
- Are any mounts writable beyond what the service strictly needs?
- Can a tracker compromise reach MySQL or Prometheus with useful credentials?

## Next Actions

- Review container users, capabilities, and network reachability from runtime
  evidence.
- Review backup scripts for secret exposure and privilege-escalation paths.
