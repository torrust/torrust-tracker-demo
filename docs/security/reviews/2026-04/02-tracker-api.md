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

## Checks Performed

- Confirmed the public API hostname proxies directly to `tracker:1212`.
- Confirmed an admin access token is injected through the environment variable
  `TORRUST_TRACKER_CONFIG_OVERRIDE_HTTP_API__ACCESS_TOKENS__ADMIN`.
- Confirmed repository config alone does not identify the full public route
  surface; source review is required.

## Findings or Non-Findings

- No confirmed finding yet. Public API exposure is intentional and requires
  source review to judge risk.

## Open Questions

- Which API routes exist on the deployed tracker revision?
- Which routes require the admin token, and how is token comparison performed?

## Next Actions

- Obtain the tracker source repository and deployed revision.
- Review all HTTP API routes, auth boundaries, and error handling paths.
