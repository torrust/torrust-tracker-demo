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

## Key Configuration Notes

### Docker IPv6 (`etc/docker/daemon.json`)

`ip6tables: true` is required for IPv6 UDP traffic to reach Docker containers. Without it
Docker does not insert ip6tables rules for published ports and its chain rewrites wipe ufw's
live ip6tables rules after every container restart, silently dropping all IPv6 UDP traffic.

See [docs/docker-ipv6.md](../docs/docker-ipv6.md) for the full explanation.

### Floating IP routing (`etc/netplan/60-floating-ip.yaml`)

Each Hetzner floating IP requires a policy routing table entry so that replies leave via the
same floating IP rather than the primary server IP (asymmetric routing fix). Adding a new
floating IP requires updating this file and running `sudo netplan apply`.

See [docs/docker-ipv6.md](../docs/docker-ipv6.md) for details.
