# Tracker API - 2026-04

**Summary**: [README.md](README.md)
**Progress**: [progress.md](progress.md)

## Scope

- Public API routes
- Authentication and token handling
- Sensitive or administrative operations
- Error handling and information disclosure

## Hypotheses

- The public API host may expose privileged endpoints guarded only by a static
  admin token.
- The deployed tracker image may contain debug or diagnostics endpoints not
  obvious from the repository config.

## Evidence Reviewed

- [../../../server/opt/torrust/storage/caddy/etc/Caddyfile](../../../server/opt/torrust/storage/caddy/etc/Caddyfile)
- [../../../server/opt/torrust/storage/tracker/etc/tracker.toml](../../../server/opt/torrust/storage/tracker/etc/tracker.toml)
- [../../../server/opt/torrust/docker-compose.yml](../../../server/opt/torrust/docker-compose.yml)
- Live responses from `https://api.torrust-tracker-demo.com/`,
  `https://api.torrust-tracker-demo.com/api/health_check`, and
  `https://api.torrust-tracker-demo.com/api/v1/*`
- Live responses from additional tested API paths such as `/api`, `/stats`,
  `/metrics`, `/swagger`, and `/openapi.json`
- Upstream tracker source for `packages/axum-rest-tracker-api-server`

## Checks Performed

- Confirmed the public API hostname proxies directly to `tracker:1212`.
- Confirmed the committed Caddy config does not rewrite or strip path prefixes on
  the API hostname.
- Confirmed an admin access token is injected through the environment variable
  `TORRUST_TRACKER_CONFIG_OVERRIDE_HTTP_API__ACCESS_TOKENS__ADMIN`.
- Confirmed repository config alone does not identify the full public route
  surface; source review was required to distinguish `/api/health_check` from
  the versioned API routes.
- Confirmed live unauthenticated `GET /api/health_check` returns `HTTP/2 200`
  with the expected health payload.
- Confirmed live unauthenticated requests to `/`, `/health_check`, and `/api`
  return `HTTP/2 500`.
- Confirmed the API root response body exposes internal error text:
  `Unhandled rejection: Err { reason: "unauthorized" }`.
- Confirmed unauthenticated versioned API routes also return the same `HTTP 500`
  behavior, including `/api/v1/stats`, `/api/v1/torrents`,
  `/api/v1/whitelist`, and `/api/v1/keys`.
- Confirmed the same `HTTP 500` behavior across additional tested API-host
  paths: `/login`, `/api`, `/api/`, `/stats`, `/metrics`, `/health_check`,
  `/announce`, `/swagger`, `/openapi.json`, and `/robots.txt`.
- Confirmed `/swagger` also returns the same body text:
  `Unhandled rejection: Err { reason: "unauthorized" }`.
- Confirmed `OPTIONS /` also returns `HTTP/2 500`, which suggests the problem is
  not limited to one specific GET route.
- Confirmed upstream source defines a public `GET /api/health_check` handler
  outside the auth middleware.
- Confirmed upstream source applies the v1 auth middleware at router level and
  maps missing tokens, invalid tokens, and malformed auth headers to
  `unhandled_rejection_response(...)`, which returns `500` with internal error
  text such as `unauthorized`.
- Confirmed axum `Router::layer` applies only to existing routes and runs after
  routing, so unrelated-path `500` responses are not explained by default axum
  layer behavior alone.
- Confirmed the live deployment exposes all three internal auth failure strings
  on `/api/v1/stats`:
  - No token: `Unhandled rejection: Err { reason: "unauthorized" }`
  - Invalid bearer token: `Unhandled rejection: Err { reason: "token not valid" }`
  - Unsupported auth scheme: `Unhandled rejection: Err { reason: "unknown token provided" }`

## Findings or Non-Findings

- Confirmed finding recorded: unauthenticated access to the versioned tracker
  API currently returns `500` and exposes internal error text instead of a
  proper client error.
- Non-finding: the dedicated public API health endpoint at `/api/health_check`
  is reachable and returns `200`, which is consistent with the upstream route
  table.

## Open Questions

- Which exact tracker revision backs the deployed `torrust/tracker:develop`
  image?
- Is the current API-host `500` behavior for unrelated paths caused entirely by
  router-level auth layering, or is there also a fallback-route issue in the
  deployed build?
- Should the public API hostname expose only `/api/health_check` and `/api/v1/*`,
  or are there additional intended routes that are not documented here?

## Next Actions

- Map the deployed behavior against the exact upstream commit shipped in the
  running image.
- Review whether non-versioned and clearly unrelated API-host paths should be
  reaching the auth middleware at all.
- Check whether unauthorized responses should map to `401`, `403`, or `404`
  instead of `500`.
- Continue probing only the documented `/api/health_check` and `/api/v1/*`
  surfaces unless new evidence suggests extra routes.
