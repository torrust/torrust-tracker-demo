# Security Review Progress - 2026-04

**Plan**: [../../security-review-plan.md](../../security-review-plan.md)
**Summary**: [README.md](README.md)
**Findings**: [findings.md](findings.md)

## Review Status

| Surface | Status | Notes |
| ------- | ------ | ----- |
| Caddy and HTTPS | In progress | Root-path and focused path checks completed on public HTTP hosts |
| Tracker API | In progress | Public `/api/health_check` returns 200; protected v1 routes return 500 with internal unauthorized error text |
| HTTP and UDP tracker | In progress | `/announce` and `/health_check` confirmed reachable over HTTPS |
| Grafana | In progress | Public hostname exposes `/login` and `/api/health` |
| SSH and host | Not started | Needs host runtime evidence |
| Container and persistence | In progress | Compose topology and mounts reviewed |
| Supply chain | In progress | Mutable tags identified from compose |

## Evidence Requested

- [ ] Tracker source repository and deployed revision
- [ ] Redacted `.env`
- [ ] `docker ps`
- [ ] `docker inspect` output
- [ ] `docker network inspect` output
- [ ] `ss -tulpn`
- [ ] `ufw status verbose`
- [ ] `sshd_config`
- [ ] Grafana auth and plugin details
- [ ] OS package update status

## Evidence Received

- Repository configuration under `server/`
- [../../../README.md](../../../README.md)
- [../../../docs/infrastructure.md](../../../docs/infrastructure.md)
- [../../../server/opt/torrust/docker-compose.yml](../../../server/opt/torrust/docker-compose.yml)
- [../../../server/opt/torrust/storage/caddy/etc/Caddyfile](../../../server/opt/torrust/storage/caddy/etc/Caddyfile)
- [../../../server/opt/torrust/storage/tracker/etc/tracker.toml](../../../server/opt/torrust/storage/tracker/etc/tracker.toml)
- [../../../server/etc/ufw/user.rules](../../../server/etc/ufw/user.rules)
- [../../../server/etc/ufw/user6.rules](../../../server/etc/ufw/user6.rules)
- [../../../server/etc/ufw/before6.rules](../../../server/etc/ufw/before6.rules)
- Live HTTP response headers and bodies for `api.torrust-tracker-demo.com`,
  `grafana.torrust-tracker-demo.com`, and `http1.torrust-tracker-demo.com`
- Focused path enumeration results for the API host, Grafana host, and HTTP
  tracker host
- Upstream tracker source snippets for the API router, auth middleware, and
  health-check handler

## Working Notes

- Public surfaces visible from repo config: Caddy on `80/443`, SSH on `22`,
  UDP tracker on `6969` and `6868`, public Grafana through Caddy, and tracker
  API through Caddy.
- The tracker container uses the mutable image tag `torrust/tracker:develop`.
- The backup service uses `torrust/tracker-backup:latest`, which is also
  mutable.
- Tracker, Caddy, Grafana, and backup all rely on mounted persistent storage.
- HTTP tracker routes trust reverse-proxy headers for client IP attribution.
- Live checks observed:
  - `https://api.torrust-tracker-demo.com/` returns `HTTP/2 500`
  - `https://api.torrust-tracker-demo.com/health_check` returns `HTTP/2 500`
  - `https://api.torrust-tracker-demo.com/api/health_check` returns `HTTP/2 200`
  - API root body exposes `Unhandled rejection: Err { reason: "unauthorized" }`
  - Tested API paths `/login`, `/api`, `/api/`, `/stats`, `/metrics`,
    `/health_check`, `/announce`, `/swagger`, `/openapi.json`, and
    `/robots.txt` all return `HTTP 500`
  - Tested protected API paths `/api/v1/stats`, `/api/v1/torrents`,
    `/api/v1/whitelist`, and `/api/v1/keys` all return `HTTP 500` without a
    token
  - `/api/v1/stats` also returns distinct internal error strings for different
    auth failures: `unauthorized`, `token not valid`, and
    `unknown token provided`
  - `https://grafana.torrust-tracker-demo.com/` returns `HTTP/2 302` with
    `Location: /login`
  - `https://grafana.torrust-tracker-demo.com/login` returns `HTTP/2 200`
  - `https://grafana.torrust-tracker-demo.com/api/health` returns `HTTP/2 200`
  - Grafana `/api/health` body exposes database status, version `12.3.1`, and
    commit `3a1c80ca7ce612f309fdc99338dd3c5e486339be`
  - Grafana frontend boot data on `/login` exposes:
    - `anonymousEnabled: false`
    - `disableLoginForm: false`
    - `disableUserSignUp: true`
    - `publicDashboardsEnabled: true`
    - `buildInfo.latestVersion: 12.4.2`
    - `buildInfo.hasUpdate: true`
    - `pluginAdminEnabled: true`
  - Two documented public dashboard URLs returned `HTTP 200`
  - The third documented public dashboard URL loaded after a longer timeout
  - Grafana unauthenticated routes `/api/live/ws`, `/api/frontend/settings`,
    and `/api/search` returned `401`
  - Grafana protected JSON routes return standard JSON `401` responses with
    `auth.unauthorized`, not internal server errors
  - `https://http1.torrust-tracker-demo.com/` returns `HTTP/2 404`
  - `https://http1.torrust-tracker-demo.com/announce` returns `HTTP/2 200`
  - `https://http1.torrust-tracker-demo.com/health_check` returns `HTTP/2 200`
    with body `{"status":"Ok"}`
  - `https://http1.torrust-tracker-demo.com/announce` without query params
    returns a bencoded failure response describing missing query params
  - `OPTIONS https://http1.torrust-tracker-demo.com/announce` returns `HTTP/2 405`
    with `Allow: GET,HEAD`
  - `OPTIONS https://api.torrust-tracker-demo.com/` still returns `HTTP/2 500`
- Upstream API source observations:
  - `packages/axum-rest-tracker-api-server/src/routes.rs` exposes public
    `GET /api/health_check`
  - The same router applies auth middleware across the v1 API routes
  - `packages/axum-rest-tracker-api-server/src/v1/middlewares/auth.rs` maps
    missing or invalid tokens to `unhandled_rejection_response(...)`
  - The current upstream behavior therefore explains the live `500`
    unauthorized response on protected v1 paths
  - Axum `Router::layer` only applies to existing routes and runs after routing,
    so unrelated-path `500` responses still need an explanation beyond default
    framework behavior
  - The committed Caddy config does not rewrite the API-host request path

## Blockers

- Live runtime evidence has not been collected yet.
- The deployed tracker source revision is still unknown.

## Next Actions

- Request live runtime evidence from the operator.
- Obtain the exact deployed tracker revision.
- Start source-backed review of Caddy, tracker API, and tracker protocol
  handling.
- Determine whether the API-host `500 unauthorized` behavior for unrelated paths
  is only router-layer behavior or also involves fallback routing.
- Decide whether the public Grafana `/api/health` exposure should be treated as
  acceptable observability or unnecessary public information disclosure.
- Decide whether the public Grafana `/api/health` and boot-data disclosure are
  acceptable for this demo or should be reduced.
