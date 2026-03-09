# Post-Mortem: UDP Tracker Down on newTrackon After Nightly Restart

**Date**: 2026-03-09
**Issue**: [#2](https://github.com/torrust/torrust-tracker-demo/issues/2)
**Issue doc**: [issues/ISSUE-2-udp-tracker-down-on-newtrackon.md](../issues/ISSUE-2-udp-tracker-down-on-newtrackon.md)
**Server**: `udp1.torrust-tracker-demo.com` / `2a01:4f8:1c0c:828e::1`

---

## Investigation

### Step 1 — Check live ip6tables INPUT chain

Note: `ufw reload` had NOT been run manually since the last nightly restart when these
commands were executed.

Command:

```bash
sudo ip6tables -L INPUT -n --line-numbers | grep -E "6969|ACCEPT|Chain"
```

Output:

```text
Chain INPUT (policy DROP)
```

**Finding**: No ACCEPT rule for port 6969 in the live ip6tables. Policy is DROP.
The bug was already active — IPv6 UDP 6969 was being dropped without needing to
simulate a restart.

---

### Step 2 — Check ufw status (stored rules vs live rules)

Command:

```bash
sudo ufw status verbose
```

Output:

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere                   # SSH access (configured port 22)
6969/udp                   ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)              # SSH access (configured port 22)
6969/udp (v6)              ALLOW IN    Anywhere (v6)
```

**Finding**: ufw has the 6969/udp (v6) rule stored on disk but it is absent from the live
ip6tables. Docker's chain rewrite after the nightly container restart wiped ufw's live
ip6tables rules and ufw did not reload them. Root cause confirmed.

---

### Step 3 — Check Docker daemon.json (ip6tables setting)

Command:

```bash
cat /etc/docker/daemon.json 2>/dev/null || echo "(no daemon.json)"
```

Output:

```text
(no daemon.json)
```

**Finding**: Docker is using all defaults. `ip6tables` is disabled by default in Docker,
so Docker never inserts ip6tables rules for published ports. IPv6 UDP traffic on port 6969
must pass through the ufw INPUT chain, but Docker's chain rewrite after each container
start wipes ufw's live ip6tables rules.

---

### Step 4 — Verify fix survives a container restart

After adding `/etc/docker/daemon.json` with `{"ip6tables": true}` and restarting the
Docker daemon, the container restart was simulated to confirm the fix:

Command:

```bash
cd /opt/torrust && docker compose stop tracker && docker compose up -d tracker && sudo ip6tables -L ufw6-user-input -n
```

Output:

```text
[+] Stopping 1/1
 ✔ Container tracker  Stopped
[+] Running 2/2
 ✔ Container mysql    Healthy
 ✔ Container tracker  Started
Chain ufw6-user-input (1 references)
target     prot opt source               destination
ACCEPT     6    --  ::/0                 ::/0                 tcp dpt:22
ACCEPT     17   --  ::/0                 ::/0                 udp dpt:6969
```

**Finding**: The `ACCEPT udp dpt:6969` rule survived the container restart. Fix confirmed.

---

## Root Cause

1. ufw has `6969/udp (v6) ALLOW IN` stored on disk in `/etc/ufw/` ✅
2. The live ip6tables INPUT chain had **no rule** for 6969 and policy is DROP ❌
3. Docker has no `daemon.json` → `ip6tables` is disabled by default
4. When Docker starts/restarts the tracker container it rewrites its chains, flushing
   ufw's live ip6tables rules. ufw does not automatically reload after this.
5. For IPv4, Docker inserts its own DNAT rules that bypass ufw INPUT entirely → unaffected.
   For IPv6, no equivalent DNAT rules are inserted → traffic must go through ufw INPUT →
   silently dropped.

**Root cause A**: Docker's default `ip6tables: false` combined with Docker chain rewrites
on container restart — ufw's ip6tables rules are wiped and never restored after the
nightly `docker compose stop/start` in the backup cron job.

## Root Cause B (follow-up, same incident)

After Root Cause A was fixed, the tracker still failed for IPv6 UDP.

Docker's userland proxy (`docker-proxy`) spawns two processes for each published UDP port:

- `-host-ip 0.0.0.0 … -container-ip 172.21.0.3` — IPv4 relay (same AF) ✅
- `-host-ip :: … -container-ip 172.21.0.3` — IPv6 relay with IPv4 backend (cross-AF) ❌

docker-proxy cannot relay native IPv6 UDP packets to an IPv4 backend. It receives native
IPv6 packets on its `::` socket but silently drops them. No forwarding, no reply.

Root Cause B was only reachable because Root Cause A had been masking it: when ip6tables
dropped all IPv6 UDP at the INPUT chain, packets never reached docker-proxy at all.

**Root cause B**: Docker networks are IPv4-only by default. No container has an IPv6
address, so Docker creates no ip6tables DNAT rules. All IPv6 UDP is handled by
docker-proxy's cross-AF path, which silently fails.

---

## Fix Decision

### Fix A — Enable `ip6tables: true` in `/etc/docker/daemon.json`

Prevents Docker chain rewrites from wiping ufw's live ip6tables rules. Systemic fix —
applies to all containers and ports, no per-port changes needed.

See [docs/docker-ipv6.md](../docker-ipv6.md) for the full configuration reference.

### Fix B — Enable IPv6 on Docker's `proxy_network` + SNAT for reply source address

Two sub-steps:

**B1**: Add `enable_ipv6: true` with a fixed ULA subnet to `proxy_network` in
`docker-compose.yml`. This gives the tracker container an IPv6 address on the bridge
network, which causes Docker to create ip6tables DNAT rules for published ports —
bypassing docker-proxy for native IPv6 traffic entirely, exactly as iptables DNAT
already does for IPv4.

```yaml
proxy_network:
  driver: bridge
  enable_ipv6: true
  ipam:
    config:
      - subnet: "fd01:db8:1::/64"
```

**B2**: Docker's MASQUERADE rule rewrites container reply source addresses to the
server's primary IPv6 (`2a01:4f8:1c19:620b::1`). Clients probing the floating IPv6
(`2a01:4f8:1c0c:828e::1`) receive a reply from the wrong source and treat it as a
timeout. Add a SNAT rule to `/etc/ufw/before6.rules` before the `*filter` section:

```text
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s fd01:db8:1::/64 -o eth0 -p udp --sport 6969 \
    -j SNAT --to-source 2a01:4f8:1c0c:828e::1
COMMIT
```

This rule fires before Docker's MASQUERADE (it is added by ufw at boot, before Docker
starts) and SNATs replies to the floating IPv6.

---

## Follow-up Investigation (same day, ~24 min after fix confirmed)

newTrackon reported the tracker down again with `UDP timeout` on the IPv6 address. The
daemon.json fix was confirmed still in place and the container was running healthy.

### Step 5 — Confirm docker-proxy is listening on IPv6

Command:

```bash
sudo ss -6 -ulnp | grep 6969
```

Output:

```text
UNCONN 0 0 [::]:6969 [::]:* users:(("docker-proxy",pid=1343459,fd=7))
```

**Finding**: docker-proxy is listening on `[::]` (wildcard), not on the floating IP
specifically. This was initially suspected to cause source-address asymmetry (replies
leaving from the primary IPv6 `2a01:4f8:1c19:620b::1` rather than the floating IP
`2a01:4f8:1c0c:828e::1`).

### Step 6 — Check all global IPv6 addresses on eth0

Command:

```bash
ip -6 addr show dev eth0 scope global
```

Output:

```text
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    inet6 2a01:4f8:1c0c:828e::1/64 scope global
    inet6 2a01:4f8:1c0c:9aae::1/64 scope global
    inet6 2a01:4f8:1c19:620b::1/64 scope global
```

**Finding**: Three global IPv6 addresses: the two floating IPs and the primary
Hetzner-assigned address `2a01:4f8:1c19:620b::1`. This identified a suspected
source-address asymmetry: docker-proxy on `[::]` would send replies with the kernel's
preferred source, which could be the primary IP rather than the floating IP.

### Step 7 — Capture on-wire traffic (tcpdump)

Command:

```bash
sudo tcpdump -i eth0 -n udp port 6969 -v
```

Output (excerpt, ~10 seconds of capture):

```text
18:46:06.152974 IP ... 176.124.202.52.34035 > 116.202.177.184.6969: UDP, length 55
18:46:06.153389 IP ... 116.202.177.184.6969 > 176.124.202.52.34035: UDP, length 137
 ...
18:46:06.838585 IP6 ... 2409:8a5e:dc81:5bf0:e40:9a4a:2b89:5a64.31550 > 2a01:4f8:1c0c:828e::1.6969: ...
 (no reply)
18:46:11.554713 IP6 ... 2408:8207:1921:9e20:ac83:6ed9:f11:1641.9346 > 2a01:4f8:1c0c:828e::1.6969: ...
 (no reply)
```

**Finding**: IPv4 works correctly — requests arrive and replies leave immediately. IPv6
requests arrive but **zero replies** leave eth0 for any IPv6 client. This rules out the
source-address asymmetry hypothesis (a misrouted reply would still appear in tcpdump).
The replies are not being generated or not reaching eth0 at all.

### Step 8 — Full ip6tables filter table inspection

Command:

```bash
sudo ip6tables -L -n -v
```

Key findings from output:

- `Chain ufw6-user-input`: `315K 22M ACCEPT 17 udp dpt:6969` — the firewall IS accepting
  incoming IPv6 UDP 6969 packets. The INPUT chain is **not** the problem.
- `Chain FORWARD (policy DROP 0 packets, 0 bytes)` — zero packets through FORWARD. Docker's
  FORWARD path for IPv6 is not being used at all.
- `Chain DOCKER-BRIDGE` and `Chain DOCKER-CT`: both empty (no rules, no traffic).
  Docker set up no container routing rules for IPv6.
- `Chain OUTPUT (policy ACCEPT)` — output policy is ACCEPT and the ufw output chains have
  no blocking rules for UDP.

**Finding**: The firewall accepts IPv6 UDP 6969 incoming. docker-proxy on `[::]:6969`
should receive those packets. The OUTPUT chain does not block replies. Yet tcpdump
confirms no replies leave eth0. The failure point is between docker-proxy receiving
the packet and the reply being emitted on eth0.

**Remaining hypotheses**:

1. Docker's NAT table (`ip6tables -t nat`) has an interfering rule added with
   `ip6tables: true`.
2. docker-proxy is not forwarding to the container (or the container is not responding to
   the forwarded packet).

**Next diagnostic commands**:

```bash
sudo ip6tables -t nat -L -n -v
docker logs tracker --tail 50 2>&1
```

### Step 9 — Inspect ip6tables NAT table

Command:

```bash
sudo ip6tables -t nat -L -n -v
```

Output (abridged):

```text
Chain PREROUTING (policy ACCEPT 2254K packets, 171M bytes)
    21090 1619K DOCKER     0    --  *      *       ::/0    ::/0    ADDRTYPE match dst-type LOCAL

Chain DOCKER (2 references)
 pkts bytes target     prot opt in     out     source               destination
```

**Finding**: The `DOCKER` chain in the ip6tables NAT table is **empty**. Docker with
`ip6tables: true` has NOT created any IPv6 DNAT rules for published ports.

For IPv4, Docker creates iptables DNAT rules for every published port (e.g.
`-j DNAT --to-destination 172.17.0.x:6969`), routing incoming packets directly to the
container via the kernel. For IPv6, no equivalent DNAT rules exist. The IPv6 DOCKER chain
(in the nat table) is empty because none of the tracker's Docker networks have IPv6
enabled, so containers have no IPv6 addresses. Docker cannot create DNAT rules pointing to
container IPv6 addresses that do not exist.

Without ip6tables DNAT, the **only** IPv6 forwarding path is docker-proxy.

### Step 10 — Inspect container logs

Command:

```bash
docker logs tracker --tail 50 2>&1
```

The initial `--tail 50` only showed HTTP entries because those 50 lines happened to be
HTTP requests. Filtering with `docker logs tracker | grep ":6969"` revealed a different
picture:

```text
... ERROR ... UDP TRACKER: response error
    client_socket_addr=[::ffff:213.155.193.247]:42881
    server_socket_addr=[::]:6969 ...
... ERROR ... UDP TRACKER: response error
    client_socket_addr=[::ffff:95.25.50.20]:50711
    server_socket_addr=[::]:6969 ...
(many more similar lines, all with [::ffff:x.x.x.x] addresses)
```

**Finding**: The tracker IS receiving UDP traffic on port 6969. However, every single
`client_socket_addr` is of the form `[::ffff:x.x.x.x]` — IPv4-mapped IPv6 addresses.
This is how the Linux kernel represents IPv4 connections received on a dual-stack UDP
socket (`[::]:6969`). **Not one entry contains a native IPv6 address** such as
`[2a01:...]`, `[2409:...]`, etc.

The errors are all `"Invalid action"` — scanner/bot traffic sending malformed packets,
unrelated to the newTrackon failure.

### Step 11 — Review Docker network configuration and docker-proxy behaviour

Command:

```bash
docker logs tracker | grep ":6969" | grep -v "ffff" | head
```

(No output — zero native IPv6 UDP entries.)

Reviewing `server/opt/torrust/docker-compose.yml`:

```yaml
networks:
  database_network:
    driver: bridge
  metrics_network:
    driver: bridge
  proxy_network:
    driver: bridge
  visualization_network:
    driver: bridge
```

All four Docker networks are IPv4-only bridge networks. The tracker container's bridge
addresses are in the `172.x.x.x` range.

**Finding**: Docker's userland UDP proxy (`docker-proxy`) listens on `[::]:6969` (a
dual-stack IPv6 socket that also accepts IPv4-mapped connections). It relays IPv4 traffic
(as `::ffff:x.x.x.x`) to the container correctly. However, it **silently drops native
IPv6 UDP packets** — it receives them on the frontend socket but cannot relay them to the
IPv4 container backend. No error is emitted and no reply is generated.

This is a known limitation of Docker's userland UDP proxy: it does not support relaying
native IPv6 clients to an IPv4-only container backend.

### Step 12 — Confirm docker-proxy backend address (smoking gun)

Command:

```bash
ps aux | grep docker-proxy | grep 6969
```

Output:

```text
root  1343452  ...  /usr/bin/docker-proxy -proto udp -host-ip 0.0.0.0 -host-port 6969 \
    -container-ip 172.21.0.3 -container-port 6969 -use-listen-fd
root  1343459  ...  /usr/bin/docker-proxy -proto udp -host-ip :: -host-port 6969 \
    -container-ip 172.21.0.3 -container-port 6969 -use-listen-fd
```

**Finding**: Two docker-proxy processes for port 6969:

1. IPv4 proxy: `-host-ip 0.0.0.0` → `-container-ip 172.21.0.3` — same address family ✅
2. IPv6 proxy: `-host-ip ::` → **`-container-ip 172.21.0.3`** — cross-address-family ❌

The IPv6 proxy has a native IPv6 frontend socket (`::`) but an IPv4 container backend
(`172.21.0.3`). This is cross-address-family UDP forwarding. docker-proxy cannot relay
native IPv6 UDP packets to an IPv4 backend — it silently drops them without reply.

This is the definitive root cause. The fix requires giving the container an IPv6 address
so that Docker creates ip6tables DNAT rules (bypassing docker-proxy entirely, exactly as
it works for IPv4 today via iptables DNAT).

This explains all observed behaviour:

- ip6tables INPUT accepts 315K IPv6 UDP 6969 packets ✅ (they reach docker-proxy)
- docker logs show UDP traffic only with `::ffff:` IPv4-mapped addresses ✅ (IPv4 works)
- docker logs show zero native IPv6 UDP entries ✅ (docker-proxy cross-AF drop)
- tcpdump shows zero IPv6 replies ✅ (no reply is ever generated)
