# ADR-001: Dual-Stack Socket vs Separate IPv4/IPv6 Sockets

- **Date**: 2026-03-10
- **Status**: Accepted (retroactive)

## Context

When IPv6 support was added to the tracker demo, all services were configured
to bind to `[::]` (the IPv6 wildcard address):

```toml
# tracker.toml
[[udp_trackers]]
bind_address = "[::]:6969"

[[http_trackers]]
bind_address = "[::]:7070"
```

This was done with the intent of accepting both IPv4 and IPv6 connections, but
without explicitly deciding between the two socket strategies available on Linux.

### The two strategies

#### Option A — Dual-stack socket (current setup)

Bind each service to a single `[::]` socket. On Linux, the kernel parameter
`net.ipv6.bindv6only` defaults to `0`:

```text
$ sysctl net.ipv6.bindv6only
net.ipv6.bindv6only = 0
```

This means the `[::]` socket accepts both IPv4 and IPv6 connections. When an
IPv4 client connects, the kernel maps its address into the IPv6 address space
using the IPv4-mapped prefix (`::ffff:0:0/96`), as defined in
[RFC 4291 §2.5.5.2](https://datatracker.ietf.org/doc/html/rfc4291#section-2.5.5.2).
The application sees a single socket with all clients arriving as IPv6, and
IPv4 clients appearing as `::ffff:<ipv4>` in logs.

#### Option B — Separate sockets

Open two sockets per port: one bound to `0.0.0.0:<port>` (IPv4 only) and one
to `[::]:port` with `IPV6_V6ONLY=1` (IPv6 only). Each socket handles only its
own address family, with separate receive queues and separate metrics labels.

> **Important**: this option requires `net.ipv6.bindv6only = 1` (either set
> system-wide or per-socket via `IPV6_V6ONLY`). With the Linux default of
> `net.ipv6.bindv6only = 0`, binding `[::]:6969` claims port 6969 for both
> address families. A subsequent attempt to also bind `0.0.0.0:6969` will
> fail with `EADDRINUSE` (os error 98). This was confirmed experimentally:
>
> ```toml
> # tracker.toml — attempted separate-socket configuration
> [[udp_trackers]]
> bind_address = "0.0.0.0:6969"
>
> [[udp_trackers]]
> bind_address = "[::]:6969"
> ```
>
> ```text
> ERROR UDP TRACKER: panic! (error when building socket)
>   addr=[::]:6969 err=Address already in use (os error 98)
> ```
>
> The tracker does not currently set `IPV6_V6ONLY` on its sockets, so Option B
> is not available without a system-wide kernel change or a tracker code change.

### Observed behavior

Confirmed from live tracker logs — both IPv4 and IPv6 clients connect through
the same dual-stack socket:

```text
# IPv4 client — mapped to ::ffff:
client_socket_addr=[::ffff:31.173.85.40]:27628  server_socket_addr=[::]:6969

# Native IPv6 client — no mapping
client_socket_addr=[2a0a:4cc0:c0:d0::a3]:11017  server_socket_addr=[::]:6969
```

And from the Prometheus metrics endpoint (`/api/v1/metrics`), all samples carry
`server_binding_address_ip_family: inet6` regardless of client IP family.

### Metrics label clarification

The tracker exposes two server-side binding labels that are easily confused:

- `server_binding_address_ip_family` — always `inet6` in this setup, because
  the server socket is an IPv6 socket (even when serving IPv4 clients via
  IPv4-mapped addresses).
- `server_binding_address_ip_type` — describes the server socket's own address
  type (`plain` for `::`, `v4_mapped_v6` for `::ffff:<ipv4>`bound addresses).
  Since all services bind to `::` (a plain IPv6 address), this is always
  `plain`. It does **not** reflect the client's address type.

See [`IpType` in the tracker source](https://github.com/torrust/torrust-tracker/blob/develop/packages/primitives/src/service_binding.rs#L28-L39).

There is currently **no client-side label** (e.g. `client_address_ip_type`)
that would allow Prometheus or Grafana to distinguish IPv4 clients from native
IPv6 clients. This was originally intended to be addressable — see
[torrust-tracker#1375](https://github.com/torrust/torrust-tracker/issues/1375)
— but the client label does not yet exist in the metrics output.

Adding a client IP family label requires care: each new label multiplies the
number of Prometheus time series (one per unique label combination). A
per-client label that is per-IP would cause a cardinality explosion; a coarser
`client_address_ip_type` label (values: `plain_v4`, `plain_v6`, `v4_mapped_v6`)
would be safe and useful.

## Decision

Keep the current dual-stack socket configuration (`[::]` without
`IPV6_V6ONLY=1`) for all tracker services.

## Rationale

### Advantages of dual-stack (Option A)

- **Simpler configuration**: one bind address per service, not two.
- **Fewer OS resources**: one socket fd and one receive queue per port.
- **UDP connection ID coherence**: the UDP tracker protocol requires a client
  to use the same connection ID for its `connect` → `announce` sequence. With
  separate sockets, a client that connects via IPv4 and announces via IPv6 (or
  vice versa) would hit different connection ID stores, requiring shared state
  and reintroducing synchronization overhead.
- **Works by default on Linux**: `net.ipv6.bindv6only = 0` is the Linux
  default; no extra socket configuration needed.
- **Negligible performance difference at current scale**: the bottleneck for a
  UDP tracker is the announce logic (swarm registry), not socket receive
  throughput. Separate sockets would only show measurable gain at extremely
  high packet rates, well beyond what this demo handles.

### Disadvantages accepted

- **IPv4 client traffic cannot be isolated in Grafana.** Because all sockets
  are dual-stack, `server_binding_address_ip_family` is always `inet6`. There
  is no existing Prometheus label that identifies whether a given request came
  from a native IPv6 client or from an IPv4 client that was mapped to
  `::ffff:<ipv4>` by the kernel. It is therefore impossible to build a Grafana
  panel that shows "requests from IPv4 clients only" or "requests from IPv6
  clients only" with the current metrics.

- **The `server_binding_address_ip_type` label does not help here.** Although
  the tracker defines an `IpType::V4MappedV6` variant (see
  [service_binding.rs](https://github.com/torrust/torrust-tracker/blob/develop/packages/primitives/src/service_binding.rs#L28-L39)),
  this label describes the **server socket's own binding address**, not the
  connecting client's address. Since all services bind to `::` (a plain IPv6
  wildcard), this label is always `plain` for every request regardless of
  client IP family.

- **Fixing this requires a tracker code change.** A new per-request label
  (e.g. `client_address_ip_type` with values `plain_v4`, `plain_v6`,
  `v4_mapped_v6`) would need to be added to the tracker's metrics counters.
  This was the original intent of
  [torrust-tracker#1375](https://github.com/torrust/torrust-tracker/issues/1375)
  but was not implemented. Adding such a label requires care: Prometheus
  creates one time series per unique combination of label values, so any
  per-client label must use a small, bounded set of values (never raw IP
  addresses) to avoid cardinality explosion.

## Consequences

- All services continue to bind to `[::]` only.
- Grafana dashboards must use `server_binding_port` to distinguish between
  service instances (e.g. UDP1 on 6969 vs UDP2 on 6868).
- **It is currently impossible to filter Grafana metrics by client IP family
  (IPv4 vs IPv6).** Both client types are counted together under the same
  `inet6` label. This is a direct consequence of this decision.
- To enable per-client-family breakdowns in the future, a new issue must be
  opened in the tracker repository to add a `client_address_ip_type` (or
  equivalent) label to the relevant request counters, with explicit attention
  to Prometheus cardinality implications.

## Related

- [docs/docker-ipv6.md](../docker-ipv6.md) — dual-stack behavior in the Docker
  context, including the IPv4-mapped address explanation
- [torrust-tracker#1375](https://github.com/torrust/torrust-tracker/issues/1375)
  — original tracker issue for IPv6 metrics support
