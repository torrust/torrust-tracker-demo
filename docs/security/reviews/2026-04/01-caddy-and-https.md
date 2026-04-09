# Caddy and HTTPS - 2026-04

**Summary**: [README.md](README.md)
**Progress**: [progress.md](progress.md)

## Scope

- Public HTTPS entry points
- Virtual host routing
- Reverse proxy behavior
- Header trust boundaries
- Unexpected backend exposure

## Hypotheses

- Only the intended virtual hosts are publicly routed by Caddy.
- No default or catch-all route exposes an unintended backend.
- Public HTTPS entry points expose the tracker API and Grafana login surface,
  not only public dashboards.

## Evidence Reviewed

- [../../../server/opt/torrust/storage/caddy/etc/Caddyfile](../../../server/opt/torrust/storage/caddy/etc/Caddyfile)
- [../../../server/opt/torrust/docker-compose.yml](../../../server/opt/torrust/docker-compose.yml)

## Checks Performed

- Confirmed configured virtual hosts: `api.torrust-tracker-demo.com`,
  `http1.torrust-tracker-demo.com`, `http2.torrust-tracker-demo.com`, and
  `grafana.torrust-tracker-demo.com`.
- Confirmed Caddy proxies the tracker API to `tracker:1212` and Grafana to
  `grafana:3000`.
- Confirmed no catch-all site block is present in the committed Caddyfile.

## Findings or Non-Findings

- No confirmed finding yet. Repository config shows a deliberate public HTTPS
  surface for the tracker API and Grafana.

## Open Questions

- Does the live Caddy runtime differ from the committed Caddyfile?
- Does the public Grafana route expose a login page or only public dashboards?

## Next Actions

- Validate live host and path behavior from the public endpoints.
- Review the tracker API source to understand which routes are reachable through
  the public API host.
