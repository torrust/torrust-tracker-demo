# Docker IPv6 Configuration

## Overview

By default, Docker has `ip6tables` support disabled. This means Docker does not insert
ip6tables rules when containers publish ports — unlike IPv4, where Docker automatically
creates iptables DNAT rules that route traffic to containers and bypass the ufw INPUT chain.

For IPv6, without `ip6tables` support enabled in Docker:

- Incoming IPv6 packets must pass through the ufw INPUT chain to reach a container.
- When Docker starts or restarts any container it rewrites its own iptables/ip6tables
  chains (`DOCKER`, `DOCKER-FORWARD`, `DOCKER-USER`). This flush removes ufw's live
  ip6tables rules from the kernel, even though they remain stored on disk in `/etc/ufw/`.
- ufw does not automatically reload its ip6tables rules after a Docker chain rewrite.
- Result: IPv6 UDP traffic is silently dropped after every container restart.

This is documented in [post-mortems/2026-03-09-udp-ipv6-docker.md](post-mortems/2026-03-09-udp-ipv6-docker.md).

## Fix

Enable `ip6tables` in the Docker daemon configuration:

```json
// /etc/docker/daemon.json
{
  "ip6tables": true
}
```

With this setting, Docker inserts its own ip6tables DNAT and FORWARD rules when containers
publish ports, exactly mirroring its IPv4 behaviour. ufw's INPUT chain is bypassed for
Docker-published ports, and the rules survive Docker chain rewrites.

The configuration file is tracked in this repository at
[server/etc/docker/daemon.json](../server/etc/docker/daemon.json).

## Scope

This is a **daemon-level** setting. It applies automatically to:

- All containers, on all Docker-published ports, without any per-container or per-port
  configuration.
- Future UDP trackers on new ports (e.g. 6868, 7979) — no additional action needed.

## What this does NOT cover

**Floating IP asymmetric routing** is a separate concern. When a published port is
reachable via a Hetzner floating IP, replies must leave via the same floating IP rather
than the server's primary IP. This is handled by policy routing tables in netplan and must
be configured per floating IP.

See [server/etc/netplan/60-floating-ip.yaml](../server/etc/netplan/60-floating-ip.yaml).

When adding a **new floating IP**, repeat the following in that file and run
`sudo netplan apply`:

```yaml
routing-policy:
  - from: <new-floating-ipv4>
    table: <new-table-id>
  - from: <new-floating-ipv6>
    table: <new-table-id-v6>
routes:
  - to: default
    via: 172.31.1.1
    table: <new-table-id>
  - to: default
    via: fe80::1
    table: <new-table-id-v6>
```

## Applying on the server

### One-time setup

```bash
# Copy daemon.json to the server
sudo cp /path/to/daemon.json /etc/docker/daemon.json

# Restart the Docker daemon
# Containers with restart: unless-stopped will come back up automatically
sudo systemctl restart docker

# Verify Docker is running
sudo systemctl status docker
```

### Verification

After the Docker daemon restarts, confirm ufw's ip6tables rules are present in the
live kernel:

```bash
sudo ip6tables -L ufw6-user-input -n
```

Expected output includes:

```text
Chain ufw6-user-input (1 references)
target     prot opt source               destination
ACCEPT     6    --  ::/0                 ::/0                 tcp dpt:22
ACCEPT     17   --  ::/0                 ::/0                 udp dpt:6969
```

Note: Docker with `ip6tables: true` uses FORWARD chain rules (via `DOCKER-FORWARD` →
`DOCKER-BRIDGE`) rather than NAT/DNAT for IPv6 published ports. The ufw INPUT chain
rules for port 6969 are preserved after Docker chain rewrites, which is the fix.

### Simulating a nightly restart

To verify the fix survives a container restart without waiting for the cron job:

```bash
cd /opt/torrust
docker compose stop tracker
docker compose up -d tracker
sudo ip6tables -L ufw6-user-input -n
```

The `ACCEPT udp dpt:6969` rule must still be present after `docker compose up`.
This was verified on 2026-03-09 and the rule survived.
