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

**Apply on the server:**

```bash
# Copy daemon.json to the server
sudo cp /path/to/daemon.json /etc/docker/daemon.json

# Restart the Docker daemon
# Containers with restart: unless-stopped will come back up automatically
sudo systemctl restart docker

# Verify Docker is running
sudo systemctl status docker
```

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

**Apply on the server:**

```bash
cd /opt/torrust
docker compose down
docker compose up -d
```

> `docker compose down` removes the old IPv4-only `proxy_network`. `up` recreates it with
> IPv6 enabled and a new ULA subnet (`fd01:db8:1::/64`). The tracker container will
> receive a new IPv6 address on this bridge.

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

**Apply on the server:**

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

## Scope and limitations

Fix 1 (`ip6tables: true`) is a **daemon-level** setting. It applies automatically to:

- All containers, on all Docker-published ports, without any per-container or per-port
  configuration.

Fix 2 (`enable_ipv6` on `proxy_network` + SNAT) is **per-`proxy_network`** and
**per-floating-IP**:

- Future UDP trackers on new ports that use `proxy_network` get IPv6 DNAT automatically.
- If a new floating IPv6 is added, an additional SNAT rule for that address is required
  in `before6.rules`.

**Floating IP asymmetric routing** is a separate concern for IPv4. When a published port
is reachable via a Hetzner floating IPv4, replies must leave via the same floating IPv4
rather than the server's primary IP. This is handled by policy routing tables in netplan,
and is not part of this document.

For IPv6, the floating-IP reply source is handled by the SNAT rule in Fix 2b above.

See [server/etc/netplan/60-floating-ip.yaml](../server/etc/netplan/60-floating-ip.yaml).

## Packet Flow

### IPv6 client

The packet is IPv6 end-to-end on the wire. No address mapping occurs inside the
container.

1. **Client sends UDP to the floating IPv6.**
   The client resolves the tracker hostname to `2a01:4f8:1c0c:828e::1` and sends a UDP
   announce to port 6969. That address is declared in
   [server/etc/netplan/60-floating-ip.yaml](../server/etc/netplan/60-floating-ip.yaml#L12).

2. **ip6tables DNAT forwards the packet to the container.**
   Docker's `DOCKER` chain in ip6tables PREROUTING rewrites the destination from
   `2a01:4f8:1c0c:828e::1:6969` to the container's IPv6 bridge address
   `fd01:db8:1::3:6969`. conntrack records the translation.

   This step requires two settings:
   - `"ip6tables": true` in
     [server/etc/docker/daemon.json](../server/etc/docker/daemon.json) — without this,
     Docker never inserts ip6tables rules.
   - `enable_ipv6: true` with subnet `fd01:db8:1::/64` on `proxy_network` in
     [server/opt/torrust/docker-compose.yml](../server/opt/torrust/docker-compose.yml)
     — this gives the container an IPv6 address so Docker can create the ip6tables DNAT
     rule. Without it, docker-proxy is the only IPv6 path and it silently drops native
     IPv6 UDP packets (see Problem 2 above).

3. **Tracker container processes the request.**
   The tracker's dual-stack socket (configured as `bind_address = "[::]:6969"` in
   [server/opt/torrust/storage/tracker/etc/tracker.toml](../server/opt/torrust/storage/tracker/etc/tracker.toml#L53))
   receives the packet with the client's real IPv6 source address. No address mapping
   occurs.

4. **Tracker sends a reply.**
   The container replies: `src = fd01:db8:1::3`, `dst = <client-ipv6>`.

5. **SNAT rewrites the reply source to the floating IPv6.**
   The reply reaches ip6tables POSTROUTING. Without intervention, Docker's MASQUERADE
   rule would rewrite `fd01:db8:1::3` to the server's primary IPv6
   `2a01:4f8:1c19:620b::1` — the wrong address. The SNAT rule at
   [server/etc/ufw/before6.rules line 14](../server/etc/ufw/before6.rules#L14) fires
   first (ufw loads `before6.rules` at boot, before Docker starts) and rewrites the
   source to the correct floating IPv6 `2a01:4f8:1c0c:828e::1`.

6. **Policy routing sends the reply out via the correct gateway.**
   The kernel selects a route for `src = 2a01:4f8:1c0c:828e::1`. The policy routing
   rule in
   [server/etc/netplan/60-floating-ip.yaml lines 16–17](../server/etc/netplan/60-floating-ip.yaml#L16-L17)
   matches and selects routing table 200, which routes via gateway `fe80::1`
   (lines 22–24).

7. **Client receives the reply from the correct address.**
   The reply arrives from `2a01:4f8:1c0c:828e::1:6969` — the same address the client
   sent to. ✅

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

### IPv4 client

The packet is IPv4 end-to-end on the wire. The `::ffff:` address representation seen
inside the container is a kernel-level abstraction only — it never appears in any network
packet.

1. **Client sends UDP to the floating IPv4.**
   The client resolves the tracker hostname to `116.202.177.184` and sends a UDP announce
   to port 6969. That address is declared in
   [server/etc/netplan/60-floating-ip.yaml](../server/etc/netplan/60-floating-ip.yaml#L11).

2. **iptables DNAT forwards the packet to the container.**
   Docker's `DOCKER` chain in iptables PREROUTING rewrites the destination from
   `116.202.177.184:6969` to the container's IPv4 bridge address `172.x.x.x:6969`.
   conntrack records the translation. This rule is created automatically by Docker
   because the tracker publishes UDP port 6969 (`ports: - "6969:6969/udp"` in
   [server/opt/torrust/docker-compose.yml](../server/opt/torrust/docker-compose.yml)).
   No extra configuration is needed for IPv4 DNAT.

3. **Tracker container processes the request.**
   The tracker's dual-stack socket (configured as `bind_address = "[::]:6969"` in
   [server/opt/torrust/storage/tracker/etc/tracker.toml](../server/opt/torrust/storage/tracker/etc/tracker.toml#L53))
   receives an IPv4 packet. Because `net.ipv6.bindv6only = 0` (the Linux default), the
   kernel presents the IPv4 source address to the application as `::ffff:<client-ipv4>`.
   This is a purely internal kernel abstraction — the underlying packet remains IPv4
   throughout.

4. **Tracker sends a reply.**
   The tracker replies to `::ffff:<client-ipv4>`. The kernel strips the `::ffff:` prefix
   and sends a plain IPv4 reply: `src = 172.x.x.x`, `dst = <client-ipv4>`.

5. **conntrack reverse DNAT restores the reply source.**
   conntrack recognizes this as the return path of the tracked connection and
   automatically rewrites `src = 172.x.x.x` → `src = 116.202.177.184`. No explicit SNAT
   rule is needed for IPv4 — conntrack recorded the inbound DNAT in step 2 and undoes
   it on the reply path, rewriting the reply source back to the floating IP.

6. **Policy routing sends the reply out via the correct gateway.**
   The kernel selects a route for `src = 116.202.177.184`. The policy routing rule in
   [server/etc/netplan/60-floating-ip.yaml lines 14–15](../server/etc/netplan/60-floating-ip.yaml#L14-L15)
   matches and selects routing table 100, which routes via gateway `172.31.1.1`
   (lines 19–21). Without this rule the kernel would use the main routing table and the
   reply would leave with the server's primary IPv4 as source — the client would time out.

7. **Client receives the reply from the correct address.**
   The reply arrives from `116.202.177.184:6969` — the same address the client sent to.
   ✅

### Comparison: reply source restoration

Both address families need the reply source set to the correct floating IP (not the
container address or the server's primary address). The mechanism that achieves this
differs between IPv4 and IPv6:

| Step | IPv4 client | IPv6 client |
| ---- | ----------- | ----------- |
| Inbound DNAT | `dst 116.202.177.184` → `172.x.x.x` — automatic, Docker iptables | `dst 2a01:4f8:1c0c:828e::1` → `fd01:db8:1::3` — requires `"ip6tables": true` + `enable_ipv6` on `proxy_network` |
| Reply source before POSTROUTING | `src = 172.x.x.x` | `src = fd01:db8:1::3` |
| Reply source restoration | **Automatic** — conntrack recorded the inbound DNAT and undoes it on the reply path, rewriting `src = 172.x.x.x` → `src = 116.202.177.184`. No explicit rule needed. | **Explicit SNAT required** — [before6.rules line 14](../server/etc/ufw/before6.rules#L14). Without it, Docker's MASQUERADE overwrites the source with the server's primary IPv6 `2a01:4f8:1c19:620b::1` (the wrong address). The SNAT rule takes precedence because ufw loads `before6.rules` at boot, before Docker starts. |
| Reply source after POSTROUTING | `src = 116.202.177.184` ✅ | `src = 2a01:4f8:1c0c:828e::1` ✅ |
| Egress routing | Policy routing table 100 ([60-floating-ip.yaml lines 14–15](../server/etc/netplan/60-floating-ip.yaml#L14-L15)) — gateway `172.31.1.1` | Policy routing table 200 ([60-floating-ip.yaml lines 16–17](../server/etc/netplan/60-floating-ip.yaml#L16-L17)) — gateway `fe80::1` |

In short: IPv4 reply source restoration is fully automatic (conntrack undoes its own
DNAT). IPv6 reply source restoration requires an explicit SNAT rule because Docker's
MASQUERADE would otherwise pick the wrong source address. Both address families
additionally require policy routing to ensure replies leave via the correct gateway.

## Note on dual-stack sockets and IPv4-mapped IPv6 addresses

### What are IPv4-mapped addresses?

When a process opens an IPv6 socket and binds to `::` (all interfaces), the Linux kernel
has a feature called **dual-stack sockets** (controlled by the `IPV6_V6ONLY` flag). By
default on Linux, `IPV6_V6ONLY` is `0`, meaning an IPv6 socket also accepts IPv4
connections. When an IPv4 packet arrives, the kernel transparently represents its source
address as `::ffff:x.x.x.x` before handing it to the socket.

This is entirely a kernel-level mechanism — Docker does nothing special here. It emerges
whenever any process uses a dual-stack socket.

### What you saw in the logs before the fix

Before Fix 2, docker-proxy was the only path for incoming traffic. It listened on a `::` dual-stack socket, so IPv4 clients were transparently mapped to `::ffff:x.x.x.x` by the
kernel before docker-proxy forwarded them. The tracker logs therefore showed entries like
`[::ffff:116.202.177.184]` for what were actually plain IPv4 clients.

After Fix 2, docker-proxy is bypassed entirely. iptables DNAT handles IPv4 and ip6tables
DNAT handles IPv6 — each family takes its own path — so IPv4 clients now appear as plain
IPv4 addresses in the tracker logs.

### When would you actually need dual-stack?

IPv4-mapped addresses matter when the **server has no public IPv4 address at all**
(IPv6-only server). In that scenario:

- The server has one or more IPv6 addresses but no IPv4 address on `eth0`.
- IPv4 clients reach the server through a hosting-provider NAT64/DNS64 gateway that
  translates their IPv4 packets into IPv6 before delivery.
- The tracker container receives all traffic as IPv6, with IPv4 client addresses
  represented as `::ffff:x.x.x.x`.

In such a setup there is only one IP family to manage, so the SNAT complexity described
in this document does not apply. The motivation for our multi-IP setup is different:
we use **two separate floating IPs** (one for HTTP, one for UDP) so that both tracker
endpoints can be listed independently on [newTrackon](https://newtrackon.com/), which
tracks one tracker per IP address.

### Current behavior with the tracker's dual-stack socket

Even after both fixes are applied, the tracker logs still show IPv4 clients as
IPv4-mapped addresses (e.g. `[::ffff:31.173.85.40]:27628`). This is **not** a Docker
issue — it is a property of the tracker's own socket configuration.

The tracker binds every service to `[::]` (the IPv6 wildcard). On Linux the
`IPV6_V6ONLY` socket flag defaults to `0` — controlled by the kernel parameter
`net.ipv6.bindv6only`, which is `0` on this server:

```text
$ sysctl net.ipv6.bindv6only
net.ipv6.bindv6only = 0
```

This creates a **dual-stack socket**: a single socket that accepts both IPv4 and IPv6
connections. When an IPv4 packet arrives,
the kernel transparently maps the client address into the
[IPv4-mapped IPv6 address space](https://datatracker.ietf.org/doc/html/rfc4291#section-2.5.5.2)
(`::ffff:0:0/96`) before handing it to the application. The application — the tracker
— only ever sees one socket and one address family: `inet6`.

Observed in the logs:

```text
# IPv4 client — mapped to ::ffff:
client_socket_addr=[::ffff:31.173.85.40]:27628  server_socket_addr=[::]:6969

# Native IPv6 client — no mapping
client_socket_addr=[2a0a:4cc0:c0:d0::a3]:11017  server_socket_addr=[::]:6969
```

#### Implication for Prometheus metrics

Because all sockets report `inet6`, the Prometheus label
`server_binding_address_ip_family` is **always `inet6`** regardless of whether the
connecting client is IPv4 or IPv6. A Grafana query split by this label would only ever
produce a single series — there is no `inet` data.

To distinguish between IPv4 and IPv6 clients in metrics, the tracker would need to open
**two separate sockets per port** — one bound to `0.0.0.0` (IPv4 only) and one bound to
`[::]` with `IPV6_V6ONLY=1` (IPv6 only). That is a tracker-level configuration change,
not a Docker or OS change.

In the current setup, the correct label for filtering per-service instance in Grafana is
`server_binding_port` (e.g. `6969` for UDP1, `6868` for UDP2).
