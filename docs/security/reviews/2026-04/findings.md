# Security Review Findings - 2026-04

**Summary**: [README.md](README.md)

Use this file only for confirmed findings and explicitly accepted risks.
Hypotheses, dead ends, and exploratory notes belong in the per-surface review
files.

## Confirmed Findings

### Finding: Public tracker API returns 500 with internal unauthorized error text

- Severity: Low
- Surface: Tracker API
- Preconditions: Unauthenticated access to the public API hostname
- Attack path: Send an unauthenticated request to `https://api.torrust-tracker-demo.com/`
  or `https://api.torrust-tracker-demo.com/health_check`
- Evidence:
  - `GET /` returns `HTTP/2 500`
  - `GET /health_check` returns `HTTP/2 500`
  - Tested paths `/login`, `/api`, `/api/`, `/stats`, `/metrics`, `/announce`,
    `/swagger`, `/openapi.json`, and `/robots.txt` also return `HTTP/2 500`
  - API root body exposes `Unhandled rejection: Err { reason: "unauthorized" }`
- Impact: The service exposes internal error text and uses a server error for
  an authorization failure, which leaks implementation behavior and complicates
  monitoring, alerting, and incident triage.
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
