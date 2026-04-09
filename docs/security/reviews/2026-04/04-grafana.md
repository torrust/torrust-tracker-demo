# Grafana - 2026-04

**Summary**: [README.md](README.md)
**Progress**: [progress.md](progress.md)

## Scope

- Public dashboard exposure
- Login and admin surface
- Anonymous access behavior
- Plugin and version risk
- Secret handling relevant to Grafana

## Hypotheses

- The public Grafana hostname may expose both public dashboards and the login
  surface.
- Grafana configuration may rely on default auth behavior not visible from the
  committed compose file alone.

## Evidence Reviewed

- [../../../server/opt/torrust/docker-compose.yml](../../../server/opt/torrust/docker-compose.yml)
- [../../../server/opt/torrust/storage/caddy/etc/Caddyfile](../../../server/opt/torrust/storage/caddy/etc/Caddyfile)
- [../../../README.md](../../../README.md)

## Checks Performed

- Confirmed the public hostname `grafana.torrust-tracker-demo.com` proxies to
  `grafana:3000`.
- Confirmed Grafana admin user and password are injected through environment
  variables.
- Confirmed the README intentionally advertises public dashboards.

## Findings or Non-Findings

- No confirmed finding yet. Public Grafana exposure is intentional, but the
  exact auth boundary still needs runtime confirmation.

## Open Questions

- Is anonymous browsing limited strictly to public dashboards?
- Is the Grafana login page reachable on the public host?
- Are any plugins installed beyond the base image?

## Next Actions

- Collect live Grafana auth configuration and plugin details.
- Review the public host behavior and login exposure.
