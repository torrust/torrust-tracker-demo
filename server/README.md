# Server Configuration

This directory mirrors the live demo server's filesystem. Each file's path here corresponds
exactly to its path on the server:

```text
server/<path>  →  <path> on the server
```

For example, `server/opt/torrust/docker-compose.yml` is `/opt/torrust/docker-compose.yml` on
the server.

## Purpose

- Auditable, reviewable record of the server configuration
- Reference for reproducing or migrating the server
- Track configuration changes over time via git history

## Secret Placeholders

All secrets have been replaced with clearly-named placeholders. To restore a working
configuration, substitute each placeholder with the real value:

| Placeholder                                                        | Secret                       |
| ------------------------------------------------------------------ | ---------------------------- |
| `<MYSQL_ROOT_PASSWORD>`                                            | MySQL root password          |
| `<MYSQL_PASSWORD>`                                                 | MySQL torrust user password  |
| `<TORRUST_TRACKER_CONFIG_OVERRIDE_HTTP_API__ACCESS_TOKENS__ADMIN>` | Tracker HTTP API admin token |
| `<GF_SECURITY_ADMIN_PASSWORD>`                                     | Grafana admin password       |
| `<EMAIL_LETS_ENCRYPT_NOTIFICATIONS>`                               | Let's Encrypt email address  |
| `<REDACTED>`                                                       | Any other SSH keys or tokens |

To find all placeholders in one shot:

```bash
grep -r '<[A-Z_]*>' server/
```

## What Is Not Stored Here

The following are excluded — they contain runtime data, large binaries, or additional secrets:

| Path on server                        | Reason excluded             |
| ------------------------------------- | --------------------------- |
| `/opt/torrust/storage/backup/config/` | Backup archives (`.tar.gz`) |
| `/opt/torrust/storage/backup/mysql/`  | MySQL dumps (`.sql.gz`)     |
| `/opt/torrust/storage/caddy/config/`  | Caddy runtime state         |
| `/opt/torrust/storage/caddy/data/`    | TLS certificates (secrets)  |
| `/opt/torrust/storage/grafana/data/`  | Grafana database, plugins   |
| `/opt/torrust/storage/mysql/data/`    | MySQL data files            |
| `/opt/torrust/storage/tracker/lib/`   | SQLite database             |
| `/opt/torrust/storage/tracker/log/`   | Log files                   |
