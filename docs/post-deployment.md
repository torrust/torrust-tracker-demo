# Post-Deployment Manual Steps

The server was provisioned using
[torrust-tracker-deployer](https://github.com/torrust/torrust-tracker-deployer),
which sets up the complete Docker Compose stack (tracker, MySQL, Caddy, Prometheus,
Grafana) and configures the firewall and basic networking.

The following steps are **not handled by the deployer** and must be applied manually
after provisioning. They represent customizations specific to this demo's use of
Hetzner floating IPs and IPv6 UDP.

---

## 1. Floating IP routing (required for each floating IP)

The deployer configures the tracker to listen on the server's primary public IP only.
If you want tracker endpoints to be reachable via a **Hetzner floating IP**, you must
add policy routing rules so that replies leave via the same floating IP rather than the
primary server IP (asymmetric routing fix).

This is required for **both IPv4 and IPv6** floating IPs.

**Configuration file**: [`server/etc/netplan/60-floating-ip.yaml`](../server/etc/netplan/60-floating-ip.yaml)

For each floating IP pair (IPv4 + IPv6), add a routing policy and a route entry, then
apply:

```bash
sudo netplan apply
```

Verify the rules are active:

```bash
ip rule list
ip route show table 100
ip -6 rule list
ip -6 route show table 200
```

> This step must be repeated for every new floating IP you add. The deployer has no
> support for floating IP routing and will not generate or apply netplan configuration.

---

## 2. Docker IPv6 for UDP trackers (required only for IPv6 UDP announces)

The deployer does not configure Docker to manage `ip6tables`. Without this, Docker's
chain rewrites wipe ufw's live ip6tables rules after every container restart, silently
dropping all IPv6 UDP traffic on port 6969.

This step is only needed if you want the UDP tracker to be reachable over **IPv6**.
IPv4 UDP and all HTTP traffic are unaffected.

**Configuration file**: [`server/etc/docker/daemon.json`](../server/etc/docker/daemon.json)

Apply on the server:

```bash
sudo cp server/etc/docker/daemon.json /etc/docker/daemon.json
sudo systemctl restart docker
```

Verify:

```bash
sudo ip6tables -L ufw6-user-input -n
# Must show: ACCEPT  17  --  ::/0  ::/0  udp dpt:6969
```

See [docker-ipv6.md](docker-ipv6.md) for the full explanation and verification steps.
