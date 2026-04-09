# Security Review Findings - 2026-04

**Summary**: [README.md](README.md)

Use this file only for confirmed findings and explicitly accepted risks.
Hypotheses, dead ends, and exploratory notes belong in the per-surface review
files.

## Confirmed Findings

### Finding: Public tracker v1 API returns 500 with internal unauthorized error text

- Severity: Low
- Surface: Tracker API
- Preconditions: Unauthenticated access to the public API hostname
- Attack path: Send an unauthenticated request to a protected v1 API path such
  as `https://api.torrust-tracker-demo.com/api/v1/stats`
- Evidence:
  - `GET /api/v1/stats`, `/api/v1/torrents`, `/api/v1/whitelist`, and
    `/api/v1/keys` all return `HTTP/2 500`
  - Response bodies expose distinct internal auth failure strings:
    `unauthorized`, `token not valid`, and `unknown token provided`
  - Upstream auth middleware returns `Unauthorized`, `TokenNotValid`, and
    `UnknownTokenProvided` through `unhandled_rejection_response(...)`
  - Upstream router exposes `GET /api/health_check` separately, and the live
    deployment returns `HTTP/2 200` for that path
- Impact: The service exposes internal error text and uses a server error for
  authorization failures, which leaks implementation behavior and complicates
  monitoring, alerting, incident triage, and client-side handling of auth
  errors.
- Remediation: Map unauthorized requests to the appropriate client error
  response and avoid returning internal exception text in the response body.
- Status: Open

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
