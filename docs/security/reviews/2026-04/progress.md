# Security Review Progress - 2026-04

**Plan**: [../../security-review-plan.md](../../security-review-plan.md)
**Summary**: [README.md](README.md)
**Findings**: [findings.md](findings.md)

## Review Status

| Surface | Status | Notes |
| ------- | ------ | ----- |
| Caddy and HTTPS | In progress | Confirmed low-severity finding: public hosts redirect HTTP to HTTPS but do not advertise HSTS |
| Tracker API | In progress | Public exact `/api/health_check` returns 200; most other tested API-host paths, including path variants and unmatched paths, return auth-shaped 500 responses |
| HTTP and UDP tracker | In progress | Both HTTP tracker hosts mirror expected announce and health behavior; UDP IPv4 responds to connect probes and some malformed packets get bounded error frames; IPv6 timed out |
| Grafana | In progress | Public hostname exposes `/login` and `/api/health`; login form is enabled while anonymous browsing is disabled |
| SSH and host | Not started | Needs host runtime evidence |
| Container and persistence | In progress | Compose topology and mounts reviewed |
| Supply chain | In progress | Confirmed low-severity finding: tracker and backup images use mutable tags in deployed compose config |

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
- Upstream tracker source snippets for HTTP announce extraction and UDP packet,
  connect, and error handling

## Working Notes

- Public surfaces visible from repo config: Caddy on `80/443`, SSH on `22`,
  UDP tracker on `6969` and `6868`, public Grafana through Caddy, and tracker
  API through Caddy.
- The tracker container uses the mutable image tag `torrust/tracker:develop`.
- The backup service uses `torrust/tracker-backup:latest`, which is also
  mutable.
- The supply-chain review now has a confirmed low-severity finding because the
  deployed compose config uses mutable tags for the tracker and backup
  services, weakening deployment traceability.
- Tracker, Caddy, Grafana, and backup all rely on mounted persistent storage.
- HTTP tracker routes trust reverse-proxy headers for client IP attribution.
- The latest edge review pass promoted missing HSTS on the public HTTPS hosts
  from an open hardening question to a confirmed low-severity finding.
- Live checks observed:
  - `https://api.torrust-tracker-demo.com/` returns `HTTP/2 500`
  - `https://api.torrust-tracker-demo.com/health_check` returns `HTTP/2 500`
  - `https://api.torrust-tracker-demo.com/api/health_check` returns `HTTP/2 200`
  - `https://api.torrust-tracker-demo.com/api/health_check/` returns `HTTP/2 500`
  - `https://api.torrust-tracker-demo.com/api/health_check/foo` returns `HTTP/2 500`
  - `http://api.torrust-tracker-demo.com/` returns `HTTP/1.1 308 Permanent Redirect`
  - API root body exposes `Unhandled rejection: Err { reason: "unauthorized" }`
  - Tested API paths `/login`, `/api`, `/api/`, `/stats`, `/metrics`,
    `/health_check`, `/announce`, `/swagger`, `/openapi.json`, and
    `/robots.txt` all return `HTTP 500`
  - Tested protected API paths `/api/v1/stats`, `/api/v1/torrents`,
    `/api/v1/whitelist`, and `/api/v1/keys` all return `HTTP 500` without a
    token
  - Clearly unmatched paths `/api/v1/notfound`, `/api/v1/foo/bar`,
    `/api/notfound`, `/swagger`, and `/` also return `HTTP 500`
  - `/api/v1/stats` also returns distinct internal error strings for different
    auth failures: `unauthorized`, `token not valid`, and
    `unknown token provided`
  - Invalid bearer tokens also change the response bodies on unmatched paths
    from `unauthorized` to `token not valid`
  - `https://grafana.torrust-tracker-demo.com/` returns `HTTP/2 302` with
    `Location: /login`
  - `http://grafana.torrust-tracker-demo.com/` returns `HTTP/1.1 308 Permanent Redirect`
  - `https://grafana.torrust-tracker-demo.com/login` returns `HTTP/2 200`
  - `https://grafana.torrust-tracker-demo.com/api/health` returns `HTTP/2 200`
  - Grafana `/api/health` body exposes database status, version `12.3.1`, and
    commit `3a1c80ca7ce612f309fdc99338dd3c5e486339be`
  - Grafana root responses include `x-content-type-options: nosniff` and
    `x-frame-options: deny`
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
  - `http://http1.torrust-tracker-demo.com/` returns `HTTP/1.1 308 Permanent Redirect`
  - `https://http1.torrust-tracker-demo.com/announce` returns `HTTP/2 200`
  - `https://http1.torrust-tracker-demo.com/health_check` returns `HTTP/2 200`
    with body `{"status":"Ok"}`
  - `https://http2.torrust-tracker-demo.com/announce` returns `HTTP/2 200`
  - `https://http2.torrust-tracker-demo.com/health_check` returns `HTTP/2 200`
    with body `{"status":"Ok"}`
  - `https://http1.torrust-tracker-demo.com/announce` without query params
    returns a bencoded failure response describing missing query params
  - `HEAD https://http1.torrust-tracker-demo.com/announce` returns `HTTP/2 200`
  - `OPTIONS https://http1.torrust-tracker-demo.com/announce` returns `HTTP/2 405`
    with `Allow: GET,HEAD`
  - `POST https://http1.torrust-tracker-demo.com/announce` returns `HTTP/2 405`
    with `Allow: GET,HEAD`
  - Malformed announce query params return bencoded parser errors, including
    invalid `info_hash` length diagnostics
  - Upstream HTTP announce extraction intentionally returns those parser errors
    as tracker-formatted bencoded bodies on `HTTP 200`
  - A valid BitTorrent UDP connect probe to IPv4 `udp1.torrust-tracker-demo.com:6969`
    returns a 16-byte connect response with the expected transaction ID
  - Additional UDP probes showed more specific malformed-input behavior:
    - An 8-byte garbage packet returned a UDP error response with action `3`,
      transaction ID `0`, and parser text `Couldn't parse action`
    - A 12-byte garbage packet returned a UDP error response with action `3`,
      transaction ID `0`, and parser text `Invalid action`
    - Invalid-action, wrong-protocol, and random 16-byte payloads timed out in
      this review environment
  - The same valid UDP connect probe to the advertised IPv6 address timed out
  - Upstream UDP `handle_packet(...)` parses requests through
    `Request::parse_bytes(...)` and routes parse failures into the UDP error
    handler
  - Upstream UDP connect handling echoes the request transaction ID and derives
    the returned connection cookie from the remote socket fingerprint and issue
    time
  - No `Strict-Transport-Security` header was observed on the tested root
    responses for the API, HTTP tracker, or Grafana hosts
  - `OPTIONS https://api.torrust-tracker-demo.com/` still returns `HTTP/2 500`
- Upstream API source observations:
  - `packages/axum-rest-tracker-api-server/src/routes.rs` exposes public
    `GET /api/health_check`
  - The same router adds the versioned API routes first, wraps that router with
    auth middleware, and only then adds the exact public
    `GET /api/health_check` route
  - `packages/axum-rest-tracker-api-server/src/v1/middlewares/auth.rs` maps
    missing or invalid tokens to `unhandled_rejection_response(...)`
  - The auth middleware returns early on missing or invalid auth data instead
    of always calling `next.run(request).await`
  - The current upstream behavior therefore explains the live `500`
    unauthorized response on protected v1 paths and on API-host paths that fall
    into the auth-wrapped router instead of the exact public health route
  - The committed Caddy config does not rewrite the API-host request path
  - The remaining runtime question is narrower: whether the deployed image
    matches the current upstream router and middleware layout

## Blockers

- Live runtime evidence has not been collected yet.
- The deployed tracker source revision is still unknown.

## Next Actions

- Request live runtime evidence from the operator.
- Obtain the exact deployed tracker revision.
- Collect the exact image digests currently deployed for the tracker and backup
  services.
- Continue source-backed review where runtime behavior still diverges from the
  current upstream code.
- Confirm whether the deployed tracker image matches the current upstream API
  router and auth middleware layout.
- Decide whether HSTS should be added directly in Caddy or through the
  deployer-generated template path.
- Decide whether the public Grafana `/api/health` exposure should be treated as
  acceptable observability or unnecessary public information disclosure.
- Decide whether the public Grafana `/api/health` and boot-data disclosure are
  acceptable for this demo or should be reduced.
- Determine whether the live UDP timeout cases reflect expected parser or
  request-class handling, packet loss, or deployed-runtime divergence from
  current upstream behavior.
- Determine whether the UDP IPv6 timeout is an intentional limitation or an
  operational regression on the public tracker host.
