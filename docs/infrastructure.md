# Infrastructure

Documents the hardware, network, and DNS configuration of the live demo server.

For raw command outputs (`ip addr`, `df -h`, etc.) see
[infrastructure-raw-outputs.md](infrastructure-raw-outputs.md).
For server resize and observed request-rate history see
[infrastructure-resize-history.md](infrastructure-resize-history.md).
For UDP packet-loss diagnosis and conntrack tuning guidance see
[udp-conntrack-runbook.md](udp-conntrack-runbook.md).

## Server

### Hardware

| Property      | Value                                          |
| ------------- | ---------------------------------------------- |
| Provider      | [Hetzner Cloud](https://www.hetzner.com)       |
| Project       | `torrust-tracker-demo`                         |
| Plan          | CCX23 (dedicated vCPU)                         |
| vCPUs         | 4                                              |
| RAM           | 16 GB                                          |
| Local disk    | 160 GB NVMe SSD                                |
| Volume        | 50 GB, mounted at `/opt/torrust/storage`       |
| Traffic       | 20 TB                                          |
| Price         | €0.051/h - €31.49/month                        |
| Datacenter    | `nbg1-dc3`                                     |
| City          | Nuremberg, Germany                             |
| Network zone  | `eu-central`                                   |
| Provisioned   | 2026-03-04, using [torrust-tracker-deployer][] |
| Backups       | Daily (Hetzner automated snapshots)            |
| Latest backup | `2026-03-09T02:25:08Z`, 1.57 GB                |

[torrust-tracker-deployer]: https://github.com/torrust/torrust-tracker-deployer

### OS and Runtime

| Property       | Value                              |
| -------------- | ---------------------------------- |
| OS             | Ubuntu 24.04.4 LTS                 |
| Kernel         | `6.8.0-101-generic`                |
| Docker         | `28.2.2` (28.2.2-0ubuntu1~24.04.1) |
| Docker Compose | `v2.29.2`                          |

### Disk Layout

| Filesystem   | Size | Used | Avail | Use% | Mounted on                      |
| ------------ | ---- | ---- | ----- | ---- | ------------------------------- |
| `/dev/sda1`  | 150G | 5.0G | 139G  | 4%   | `/` (OS, local disk)            |
| `/dev/sdb`   | 49G  | 264M | 47G   | 1%   | `/opt/torrust/storage` (volume) |
| `/dev/sda15` | 253M | 146K | 252M  | 1%   | `/boot/efi`                     |

## Network

### Server IPs

Assigned by Hetzner at provisioning time. No private network is configured.

| Name        | Version | Address                   |
| ----------- | ------- | ------------------------- |
| Public IPv4 | IPv4    | `46.225.234.201`          |
| Public IPv6 | IPv6    | `2a01:4f8:1c19:620b::/64` |

### Floating IPs

Defined in [`server/etc/netplan/60-floating-ip.yaml`](../server/etc/netplan/60-floating-ip.yaml).

| Name       | Version | Address                   |
| ---------- | ------- | ------------------------- |
| http1-ipv4 | IPv4    | `116.202.176.169`         |
| http1-ipv6 | IPv6    | `2a01:4f8:1c0c:9aae::/64` |
| udp1-ipv4  | IPv4    | `116.202.177.184`         |
| udp1-ipv6  | IPv6    | `2a01:4f8:1c0c:828e::/64` |

### Firewall

Managed by UFW. Rules are in
[`server/etc/ufw/user.rules`](../server/etc/ufw/user.rules) (IPv4) and
[`server/etc/ufw/user6.rules`](../server/etc/ufw/user6.rules) (IPv6).
Custom pre-filter rules (including the SNAT for IPv6 UDP) are in
[`server/etc/ufw/before6.rules`](../server/etc/ufw/before6.rules).

Port 443 (HTTPS) is not in the UFW user rules — it is exposed directly by the
Caddy container via Docker's `iptables` integration.

| Port | Protocol | Source  | Action | Purpose     |
| ---- | -------- | ------- | ------ | ----------- |
| 22   | TCP      | 0.0.0.0 | ALLOW  | SSH access  |
| 6969 | UDP      | 0.0.0.0 | ALLOW  | UDP tracker |

### DNS

DNS is managed via [Hetzner DNS](https://dns.hetzner.com).
Nameservers: `oxygen.ns.hetzner.com`, `hydrogen.ns.hetzner.com`, `helium.ns.hetzner.de`.

| Type | Name                           | Value                   | TTL  |
| ---- | ------------------------------ | ----------------------- | ---- |
| NS   | torrust-tracker-demo.com       | oxygen.ns.hetzner.com   | 3600 |
| NS   | torrust-tracker-demo.com       | hydrogen.ns.hetzner.com | 3600 |
| NS   | torrust-tracker-demo.com       | helium.ns.hetzner.de    | 3600 |
| A    | http1.torrust-tracker-demo.com | 116.202.176.169         | 300  |
| AAAA | http1.torrust-tracker-demo.com | 2a01:4f8:1c0c:9aae::1   | 300  |
| A    | udp1.torrust-tracker-demo.com  | 116.202.177.184         | 300  |
| AAAA | udp1.torrust-tracker-demo.com  | 2a01:4f8:1c0c:828e::1   | 300  |

## Backup Storage

The backup service stores nightly archives under `/opt/torrust/storage/backup/`.
Backup paths are configured in
[`server/opt/torrust/storage/backup/etc/backup-paths.txt`](../server/opt/torrust/storage/backup/etc/backup-paths.txt).

Archives are created daily at 03:00 UTC. Naming convention: `<type>_YYYYMMDD_HHmmss.<ext>`.

```text
/opt/torrust/storage/backup/
├── config
│   ├── config_20260304_160759.tar.gz
│   ├── config_20260305_030013.tar.gz
│   ├── config_20260306_030013.tar.gz
│   ├── config_20260307_030014.tar.gz
│   ├── config_20260308_030014.tar.gz
│   └── config_20260309_030013.tar.gz
├── etc
│   ├── backup-paths.txt
│   └── backup.conf
└── mysql
    ├── mysql_20260304_160758.sql.gz
    ├── mysql_20260305_030013.sql.gz
    ├── mysql_20260306_030013.sql.gz
    ├── mysql_20260307_030014.sql.gz
    ├── mysql_20260308_030014.sql.gz
    └── mysql_20260309_030013.sql.gz

4 directories, 14 files
```
