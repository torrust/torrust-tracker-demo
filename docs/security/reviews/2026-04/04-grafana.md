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
- Live responses from `/`, `/login`, `/public-dashboards/`, `/api/health`, and
  `/robots.txt` on the public Grafana host
- Frontend boot-data settings embedded in the unauthenticated `/login` page

## Checks Performed

- Confirmed the public hostname `grafana.torrust-tracker-demo.com` proxies to
  `grafana:3000`.
- Confirmed Grafana admin user and password are injected through environment
  variables.
- Confirmed the README intentionally advertises public dashboards.
- Confirmed live route behavior:
  - `/` returns `302` to `/login`
  - `/login` returns `200`
  - `/public-dashboards/` returns `302`
  - `/api/health` returns `200`
  - `/robots.txt` returns `200`
- Confirmed `/api/health` body exposes `database: ok`, version `12.3.1`, and
  commit `3a1c80ca7ce612f309fdc99338dd3c5e486339be`.
- Confirmed unauthenticated route behavior:
  - `/api/live/ws` returns `401`
  - `/api/frontend/settings` returns `401`
  - `/api/search` returns `401`
  - `/signup` and `/user/password/send-reset-email` are routable and return `200`
- Confirmed unauthenticated protected JSON routes return normal Grafana auth
  errors rather than internal server errors:
  - `/api/frontend/settings` returns JSON `401` with `auth.unauthorized`
  - `/api/search` returns JSON `401` with `auth.unauthorized`
- Confirmed frontend boot data on `/login` includes:
  - `anonymousEnabled: false`
  - `disableLoginForm: false`
  - `disableUserSignUp: true`
  - `publicDashboardsEnabled: true`
- Confirmed the same boot data also exposes additional operational details:
  - `buildInfo.latestVersion: 12.4.2`
  - `buildInfo.hasUpdate: true`
  - `pluginAdminEnabled: true`
  - Preinstalled app/plugin identifiers for logs, traces, metrics, and
    pyroscope drilldown apps
- Confirmed the three public dashboard URLs documented in the repository are
  reachable without authentication, although one required a longer timeout.

## Findings or Non-Findings

- Confirmed finding recorded: the public Grafana host exposes operational
  metadata before auth through `/api/health` and login-page boot data.
- No confirmed finding yet. Current evidence suggests that anonymous Grafana UI
  browsing is disabled, self-sign-up is disabled, and public dashboards are the
  intended unauthenticated surface.
- Non-finding so far: protected JSON API routes return proper `401` responses
  rather than leaking the same data through error handling.

## Open Questions

- Is anonymous browsing limited strictly to public dashboards?
- Are any plugins installed beyond the base image?
- Should `/api/health` remain publicly reachable on the demo hostname?
- Does the public password reset route create unnecessary account-management
  surface for a demo that does not intend public users to log in?
- Should the login-page boot-data disclosure be reduced for the demo, given
  that it reveals upgrade status and preinstalled plugin/app metadata?

## Next Actions

- Collect live Grafana auth configuration and plugin details.
- Review the public host behavior and login exposure.
- Decide whether `/api/health` and the login bootstrap data should be reduced
  or accepted as part of the public demo design.
