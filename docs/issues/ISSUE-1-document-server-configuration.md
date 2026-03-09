# Document and Version-Control the Demo Server Configuration

**Issue**: [#1](https://github.com/torrust/torrust-tracker-demo/issues/1)
**Related**:
[torrust-tracker-deployer#405](https://github.com/torrust/torrust-tracker-deployer/issues/405)

## Overview

The demo tracker server was provisioned on March 3, 2026 using
[torrust-tracker-deployer](https://github.com/torrust/torrust-tracker-deployer). The deployer is a
**one-shot deployment tool** — it provisions the server and sets the initial configuration, but does
not manage the server's ongoing state. After provisioning, several manual post-provision steps were
performed (floating IPs, DNS, policy routing, ufw rules).

None of the current server configuration is versioned outside the server itself. The goal of this
issue is to capture the full configuration of the live demo server in this repository — with secrets
replaced by placeholders — so that:

- The configuration is auditable and reviewable.
- It can be used as a reference if the server needs to be reproduced or migrated.
- Changes to the configuration can be tracked over time via git history.
- Other users can learn from a real production-like deployment.

## What to Capture

### From `/opt/torrust/` (deployer-managed)

The deployer places everything under `/opt/torrust/`. The actual directory structure on the server
is:

```text
/opt/torrust/
├── .env                   ← capture (contains secrets — replace with placeholders)
├── docker-compose.yml
└── storage/
    ├── backup/
    │   ├── config/         ← EXCLUDE — backup archives (.tar.gz)
    │   ├── etc/
    │   │   ├── backup-paths.txt   ← capture
    │   │   └── backup.conf        ← capture
    │   └── mysql/          ← EXCLUDE — MySQL dumps (.sql.gz)
    ├── caddy/
    │   ├── config/         ← EXCLUDE — Caddy runtime state
    │   ├── data/           ← EXCLUDE — TLS certificates (secrets)
    │   └── etc/
    │       └── Caddyfile          ← capture
    ├── grafana/
    │   ├── data/           ← EXCLUDE — Grafana database, plugins, runtime data
    │   └── provisioning/
    │       ├── dashboards/
    │       │   ├── torrust/
    │       │   │   ├── metrics.json   ← capture
    │       │   │   └── stats.json     ← capture
    │       │   └── torrust.yml        ← capture
    │       └── datasources/
    │           └── prometheus.yml     ← capture
    ├── lost+found/         ← EXCLUDE — filesystem artifact
    ├── mysql/
    │   └── data/           ← EXCLUDE — MySQL data files
    ├── prometheus/
    │   └── etc/
    │       └── prometheus.yml         ← capture
    └── tracker/
        ├── etc/
        │   └── tracker.toml           ← capture
        ├── lib/            ← EXCLUDE — SQLite database
        └── log/            ← EXCLUDE — log files
```

Config files to capture and runtime data to exclude are annotated above.

### System configuration files

| File on server                     | Description                                       |
| ---------------------------------- | ------------------------------------------------- |
| `/etc/netplan/60-floating-ip.yaml` | Floating IP assignments and policy routing tables |
| `/etc/ufw/user.rules`              | ufw firewall allow/deny rules (IPv4)              |
| `/etc/ufw/user6.rules`             | ufw firewall allow/deny rules (IPv6)              |

### Cron and backup scripts

The deployer installs the backup schedule and script at the host level (not inside Docker):

| File on server                         | Description                      |
| -------------------------------------- | -------------------------------- |
| `/etc/cron.d/tracker-backup`           | Cron schedule for nightly backup |
| `/usr/local/bin/maintenance-backup.sh` | Backup script invoked by cron    |

Note: `sudo crontab -l` (root user crontab) is empty — the schedule is in `cron.d`, not the
user crontab.

## Repository Directory Structure

Files will be organized to **mirror the server's directory structure** under a `server/` top-level
directory in this repo. This makes it immediately obvious where each file lives on the server and
allows a simple one-to-one mapping:

```text
server/                                               # mirrors the server filesystem root
├── README.md                                         # explains convention + placeholder list
├── etc/
│   ├── cron.d/
│   │   └── tracker-backup
│   ├── netplan/
│   │   └── 60-floating-ip.yaml
│   └── ufw/
│       ├── user.rules
│       └── user6.rules
├── usr/
│   └── local/
│       └── bin/
│           └── maintenance-backup.sh
└── opt/
    └── torrust/
        ├── .env
        ├── docker-compose.yml
        └── storage/
            ├── backup/
            │   └── etc/
            │       ├── backup-paths.txt
            │       └── backup.conf
            ├── caddy/
            │   └── etc/
            │       └── Caddyfile
            ├── grafana/
            │   └── provisioning/
            │       ├── dashboards/
            │       │   ├── torrust/
            │       │   │   ├── metrics.json
            │       │   │   └── stats.json
            │       │   └── torrust.yml
            │       └── datasources/
            │           └── prometheus.yml
            ├── prometheus/
            │   └── etc/
            │       └── prometheus.yml
            └── tracker/
                └── etc/
                    └── tracker.toml
```

A `README.md` at the top of `server/` will explain the convention — that files here mirror server
paths — and list all secrets that have been replaced with placeholders.

## Secret Placeholders

The following secrets must be replaced with clearly-named placeholders before committing:

| Secret                    | Placeholder                  |
| ------------------------- | ---------------------------- |
| MySQL root password       | `<MYSQL_ROOT_PASSWORD>`      |
| Tracker admin API token   | `<TRACKER_ADMIN_API_TOKEN>`  |
| Grafana admin password    | `<GRAFANA_ADMIN_PASSWORD>`   |
| Let's Encrypt admin email | `<LETS_ENCRYPT_ADMIN_EMAIL>` |
| Any SSH keys or tokens    | `<REDACTED>`                 |

## How to Collect the Files

All commands run from the local machine (using the `demotracker` SSH alias).

### 1. Compose file and environment

```bash
rsync -av --mkpath demotracker:/opt/torrust/.env server/opt/torrust/
rsync -av --mkpath demotracker:/opt/torrust/docker-compose.yml server/opt/torrust/
```

### 2. Service config files from `storage/`

```bash
# Tracker
rsync -av --mkpath demotracker:/opt/torrust/storage/tracker/etc/tracker.toml \
    server/opt/torrust/storage/tracker/etc/

# Caddy
rsync -av --mkpath demotracker:/opt/torrust/storage/caddy/etc/Caddyfile \
    server/opt/torrust/storage/caddy/etc/

# Prometheus
rsync -av --mkpath demotracker:/opt/torrust/storage/prometheus/etc/prometheus.yml \
    server/opt/torrust/storage/prometheus/etc/

# Grafana provisioning
rsync -av --mkpath demotracker:/opt/torrust/storage/grafana/provisioning/ \
    server/opt/torrust/storage/grafana/provisioning/

# Backup config
rsync -av --mkpath demotracker:/opt/torrust/storage/backup/etc/ \
    server/opt/torrust/storage/backup/etc/
```

### 3. System config files

```bash
rsync -av --mkpath --rsync-path="sudo rsync" demotracker:/etc/netplan/60-floating-ip.yaml server/etc/netplan/
rsync -av --mkpath --rsync-path="sudo rsync" demotracker:/etc/ufw/user.rules server/etc/ufw/
rsync -av --mkpath --rsync-path="sudo rsync" demotracker:/etc/ufw/user6.rules server/etc/ufw/
```

### 4. Cron schedule and backup script

```bash
rsync -av --mkpath demotracker:/etc/cron.d/tracker-backup server/etc/cron.d/
mkdir -p server/usr/local/bin
ssh demotracker sudo cat /usr/local/bin/maintenance-backup.sh \
    > server/usr/local/bin/maintenance-backup.sh
chmod +x server/usr/local/bin/maintenance-backup.sh
```

## Implementation Plan

- [ ] Run all `rsync` commands above to collect files into `server/`
- [ ] Review `Caddyfile`, `tracker.toml`, `docker-compose.yml`, `.env` for secrets and replace with placeholders
- [ ] Review `backup.conf` and `backup-paths.txt` for any sensitive paths
- [ ] Review `maintenance-backup.sh` and `tracker-backup` cron file for any sensitive content
- [ ] Create `server/README.md` explaining the mirroring convention and the placeholder list
- [ ] Run linters (`npx markdownlint-cli2 "**/*.md"` and `npx cspell --no-progress`)
- [ ] Commit

## Acceptance Criteria

- [ ] `server/` directory exists and mirrors the server directory structure as described above
- [ ] `server/README.md` explains the convention and lists all replaced secrets
- [ ] No real secrets are committed (verified by reviewing the placeholder list)
- [ ] Runtime data (`storage/backup/config/`, `storage/mysql/`, `storage/caddy/data/`, etc.) is excluded
- [ ] Linters pass
