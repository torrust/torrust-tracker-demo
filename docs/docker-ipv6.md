# Docker IPv6 Configuration

> **Post-deployment step**: This configuration is not applied by the
> [torrust-tracker-deployer](https://github.com/torrust/torrust-tracker-deployer).
> It must be applied manually after provisioning. See
> [post-deployment.md](post-deployment.md) for all manual steps.

## Overview

Docker requires two distinct configuration changes to make IPv6 UDP tracker traffic work
correctly end-to-end. Both problems were discovered during the 2026-03-09 incident
(see [post-mortems/2026-03-09-udp-ipv6-docker.md](post-mortems/2026-03-09-udp-ipv6-docker.md)).

### Problem 1 — Docker chain rewrites wipe ufw ip6tables rules

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

### Problem 2 — docker-proxy cannot relay native IPv6 UDP to an IPv4 container

Even after Problem 1 is fixed, native IPv6 UDP still does not work. Docker spawns two
`docker-proxy` processes for each published UDP port:

- IPv4: `-host-ip 0.0.0.0 … -container-ip 172.x.x.x` (same address family — works)
- IPv6: `-host-ip :: … -container-ip 172.x.x.x` (cross-address-family — silently fails)

docker-proxy receives native IPv6 UDP on its `::` socket but cannot forward to an IPv4
container backend. Packets are accepted by ip6tables, reach docker-proxy, and are then
silently dropped with no reply and no error log.

## Packet Flow

```text
                        SERVER (eth0)
                        ┌──────────────────────────────────────────────────────────┐
                        │                                                          │
  CLIENT                │  ip6tables nat PREROUTING                                │
  2409:8a5e::1          │  ┌─────────────────────────────────┐                     │
        │               │  │ DOCKER chain                    │                     │
        │  UDP :6969    │  │ DNAT → fd01:db8:1::3:6969       │                     │
        ▼               │  └────────────────┬────────────────┘                     │
  2a01:4f8:1c0c:828e::1 │                   │                                      │
  (floating IPv6)       │                   ▼                                      │
        │               │  Docker bridge (fd01:db8:1::/64)                         │
        │               │  ┌──────────────────────────────┐                        │
        │               │  │  TRACKER CONTAINER           │                        │
        │               │  │  fd01:db8:1::3               │                        │
        │               │  │                              │                        │
        │               │  │  sends reply from            │                        │
        │               │  │  fd01:db8:1::3               │                        │
        │               │  └──────────────┬───────────────┘                        │
        │               │                 │                                        │
        │               │  ip6tables nat POSTROUTING                               │
        │               │  ┌──────────────────────────────────────────────┐        │
        │               │  │ our SNAT rule (before6.rules)                │        │
        │               │  │ fd01:db8:1::/64 → 2a01:4f8:1c0c:828e::1      │        │
        │               │  │                                              │        │
        │               │  │ (without this, Docker MASQUERADE would use   │        │
        │               │  │  primary IPv6 2a01:4f8:1c19:620b::1 instead) │        │
        │               │  └──────────────────────────────────────────────┘        │
        │               │                 │                                        │
        └───────────────┼─────────────────┘                                        │
          reply from    │  source = 2a01:4f8:1c0c:828e::1 ✅                       │
          correct IP    │                                                          │
                        └──────────────────────────────────────────────────────────┘
```

## Fix

Two configuration changes are required.

### Fix 1 — Enable `ip6tables` in the Docker daemon

Create `/etc/docker/daemon.json`:

```json
{
  "ip6tables": true
}
```

With this setting, Docker manages ip6tables rules for published ports (same as it already
does for IPv4 with iptables). ufw's INPUT chain rules are preserved after Docker chain
rewrites because Docker now inserts its own FORWARD chain rules for published ports.

The configuration file is tracked in this repository at
[server/etc/docker/daemon.json](../server/etc/docker/daemon.json).

### Fix 2 — Enable IPv6 on the Docker bridge network + SNAT for reply source

Enabling `ip6tables: true` alone is not sufficient. Docker only creates ip6tables DNAT
rules when the container has an IPv6 address. Without IPv6 on the Docker network, the
container has only IPv4 bridge addresses and docker-proxy is still the only IPv6 path
(which silently drops native IPv6 UDP, see Problem 2 above).

**Step 2a — Enable IPv6 on `proxy_network`** in `docker-compose.yml`:

```yaml
proxy_network:
  driver: bridge
  enable_ipv6: true
  ipam:
    config:
      - subnet: "fd01:db8:1::/64"
```

With an IPv6 address on the container, Docker creates ip6tables DNAT rules that bypass
docker-proxy entirely for native IPv6 traffic, exactly as iptables DNAT does for IPv4.

This is tracked in
[server/opt/torrust/docker-compose.yml](../server/opt/torrust/docker-compose.yml).

**Step 2b — Add SNAT to `/etc/ufw/before6.rules`** to rewrite reply source to floating IP:

Docker's MASQUERADE rule rewrites container reply sources to the server's primary IPv6
(`2a01:4f8:1c19:620b::1`). Clients probing the floating IPv6 (`2a01:4f8:1c0c:828e::1`)
would receive a reply from the wrong address and time out. Add this block at the **very
top** of `/etc/ufw/before6.rules`, before the existing `*filter` section:

```text
# NAT: rewrite source of Docker UDP tracker IPv6 replies to the floating IP
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s fd01:db8:1::/64 -o eth0 -p udp --sport 6969 \
    -j SNAT --to-source 2a01:4f8:1c0c:828e::1
COMMIT
```

This rule fires before Docker's MASQUERADE because ufw loads `before6.rules` at startup,
before Docker starts. The SNAT takes precedence and replies leave via the correct floating
IP.

## Scope

Fix 1 (`ip6tables: true`) is a **daemon-level** setting. It applies automatically to:

- All containers, on all Docker-published ports, without any per-container or per-port
  configuration.

Fix 2 (`enable_ipv6` on `proxy_network` + SNAT) is **per-`proxy_network`** and
**per-floating-IP**:

- Future UDP trackers on new ports that use `proxy_network` get IPv6 DNAT automatically.
- If a new floating IPv6 is added, an additional SNAT rule for that address is required
  in `before6.rules`.

## What this does NOT cover

**Floating IP asymmetric routing** is a separate concern for IPv4. When a published port
is reachable via a Hetzner floating IPv4, replies must leave via the same floating IPv4
rather than the server's primary IP. This is handled by policy routing tables in netplan.

For IPv6, the floating-IP reply source is handled by the SNAT rule in Fix 2b above.

See [server/etc/netplan/60-floating-ip.yaml](../server/etc/netplan/60-floating-ip.yaml).

## Applying on the server

### Fix 1 — Docker daemon (one-time setup)

```bash
# Copy daemon.json to the server
sudo cp /path/to/daemon.json /etc/docker/daemon.json

# Restart the Docker daemon
# Containers with restart: unless-stopped will come back up automatically
sudo systemctl restart docker

# Verify Docker is running
sudo systemctl status docker
```

### Fix 2a — Enable IPv6 on proxy_network

Update `docker-compose.yml` on the server to match
[server/opt/torrust/docker-compose.yml](../server/opt/torrust/docker-compose.yml), then
recreate the network:

```bash
cd /opt/torrust
docker compose down
docker compose up -d
```

> `docker compose down` removes the old IPv4-only `proxy_network`. `up` recreates it with
> IPv6 enabled and a new ULA subnet (`fd01:db8:1::/64`). The tracker container will
> receive a new IPv6 address on this bridge.

### Fix 2b — SNAT in before6.rules

Add the following block at the **very top** of `/etc/ufw/before6.rules` (before the
existing `*filter` line):

```bash
sudo sed -i '1s/^/# NAT: Docker UDP tracker IPv6 reply source → floating IP\n*nat\n:POSTROUTING ACCEPT [0:0]\n-A POSTROUTING -s fd01:db8:1:\/64 -o eth0 -p udp --sport 6969 -j SNAT --to-source 2a01:4f8:1c0c:828e::1\nCOMMIT\n\n/' /etc/ufw/before6.rules
sudo ufw reload
```

Or edit manually — the file should begin with:

```text
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s fd01:db8:1::/64 -o eth0 -p udp --sport 6969 \
    -j SNAT --to-source 2a01:4f8:1c0c:828e::1
COMMIT

# rules.before
# ...(existing content follows)
```

### Verification

After applying all three steps, verify end-to-end:

**1. ufw ip6tables rules still present:**

```bash
sudo ip6tables -L ufw6-user-input -n
```

Expected:

```text
Chain ufw6-user-input (1 references)
target     prot opt source               destination
ACCEPT     6    --  ::/0                 ::/0                 tcp dpt:22
ACCEPT     17   --  ::/0                 ::/0                 udp dpt:6969
```

**2. Container has an IPv6 address on the Docker bridge:**

```bash
docker inspect tracker --format '{{range .NetworkSettings.Networks}}{{.GlobalIPv6Address}} {{end}}'
```

Expected: a non-empty address starting with `fd01:db8:1::` (the ULA subnet).

**3. ip6tables DNAT rule exists for port 6969:**

```bash
sudo ip6tables -t nat -L PREROUTING -n -v | grep 6969
```

Expected: a DNAT rule redirecting to the container's IPv6 address.

**4. SNAT rule exists in POSTROUTING:**

```bash
sudo ip6tables -t nat -L POSTROUTING -n -v | grep 6969
```

Expected:

```text
SNAT  17  --  fd01:db8:1::/64  ::/0  udp spt:6969  to:2a01:4f8:1c0c:828e::1
```

**5. Simulate a nightly restart and verify all rules survive:**

```bash
cd /opt/torrust
docker compose stop tracker
docker compose up -d tracker
sudo ip6tables -L ufw6-user-input -n
sudo ip6tables -t nat -L POSTROUTING -n -v | grep 6969
```

Both the INPUT ACCEPT rule and the SNAT rule must still be present.
