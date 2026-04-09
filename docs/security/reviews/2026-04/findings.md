# Security Review Findings - 2026-04

**Summary**: [README.md](README.md)

Use this file only for confirmed findings and explicitly accepted risks.
Hypotheses, dead ends, and exploratory notes belong in the per-surface review
files.

## Confirmed Findings

### Finding: Mutable container tags reduce deployment traceability

- Severity: Low
- Surface: Supply chain and deployment provenance
- Preconditions: Access to the deployment process or routine image refresh,
  redeploy, or host rebuild
- Attack path: Reuse the committed compose configuration as-is and pull
  `torrust/tracker:develop` or `torrust/tracker-backup:latest` at a later time;
  the host can receive different image contents without any configuration-file
  change, leaving operators unable to identify the exact deployed code from the
  tracked server config alone
- Evidence:
  - [../../../server/opt/torrust/docker-compose.yml](../../../server/opt/torrust/docker-compose.yml)
    sets the tracker image to `torrust/tracker:develop`
  - The same compose file sets the backup image to
    `torrust/tracker-backup:latest`
  - The tracker service block includes an inline comment stating that the
    `develop` tag is mutable and introduces deployment non-reproducibility
  - Other core services in the same compose file are pinned to explicit version
    tags, which shows the mutable tags are an exception rather than the general
    deployment pattern
- Impact: Mutable tags weaken release traceability, make rollback and incident
  response harder, and increase the chance of unintentionally deploying code
  that differs from what operators believe is running.
- Remediation: Pin deployed images to immutable digests or at least fixed
  release tags, and record the exact deployed revision in the review evidence.
- Status: Open

### Finding: Public tracker API host returns 500 with internal auth error text

- Severity: Low
- Surface: Tracker API
- Preconditions: Unauthenticated access to the public API hostname
- Attack path: Send an unauthenticated request to the public API hostname on a
  protected route or even an apparently unrelated path such as
  `https://api.torrust-tracker-demo.com/api/v1/stats` or
  `https://api.torrust-tracker-demo.com/swagger`
- Evidence:
  - `http://api.torrust-tracker-demo.com/` redirects to
    `https://api.torrust-tracker-demo.com/` with `HTTP/1.1 308 Permanent Redirect`
  - `GET /api/v1/stats`, `/api/v1/torrents`, `/api/v1/whitelist`, and
    `/api/v1/keys` all return `HTTP/2 500`
  - Exact `GET /api/health_check` returns `HTTP/2 200`, but
    `GET /api/health_check/` and `GET /api/health_check/foo` return the same
    auth-shaped `HTTP/2 500`
  - `GET /api/v1/notfound`, `/api/v1/foo/bar`, `/api/notfound`, `/swagger`,
    and `/` also return `HTTP/2 500`
  - Response bodies expose distinct internal auth failure strings:
    `unauthorized`, `token not valid`, and `unknown token provided`
  - The HTTPS API responses are served through the public Caddy edge and
    include public-facing headers such as `via: 1.1 Caddy` and `x-request-id`
  - Upstream router composition adds the versioned API routes first, wraps that
    router with auth middleware, and only then adds the exact public
    `/api/health_check` route
  - Upstream auth middleware returns `Unauthorized`, `TokenNotValid`, and
    `UnknownTokenProvided` through `unhandled_rejection_response(...)`
  - The same middleware returns early on missing or invalid auth data instead
    of always calling `next.run(request).await`
  - Upstream router exposes `GET /api/health_check` separately, and the live
    deployment returns `HTTP/2 200` for that path
- Invalid bearer tokens also change unmatched-path responses from
  `unauthorized` to `token not valid`, which is consistent with the current
  auth-wrapped router intercepting requests before a downstream `404`
- Impact: The service exposes internal error text and uses a server error for
  authorization failures, which leaks implementation behavior and complicates
  monitoring, alerting, incident triage, and client-side handling of auth
  errors.
- Remediation: Map unauthorized requests to the appropriate client error
  response and avoid returning internal exception text in the response body.
- Status: Open. Public-edge behavior is confirmed, and current upstream router
  composition likely explains the broad auth-shaped failures; the remaining
  runtime question is whether the deployed image matches that upstream layout.

## Accepted Risks

No accepted risks recorded yet.

## Finding Template

### Finding: <title>

- Severity:
- Surface:
- Preconditions:
- Attack path:
- Evidence:
- Impact:
- Remediation:
- Status:
