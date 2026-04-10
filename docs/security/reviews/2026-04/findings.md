# Security Review Findings - 2026-04

**Summary**: [README.md](README.md)

Use this file only for confirmed findings and explicitly accepted risks.
Hypotheses, dead ends, and exploratory notes belong in the per-surface review
files.

## Confirmed Findings

### Finding: Public Grafana host discloses operational metadata before auth

- Severity: Low
- Surface: Grafana public exposure
- Preconditions: Unauthenticated access to the public Grafana hostname
- Attack path: Request public routes such as `/api/health` and `/login` on
  `https://grafana.torrust-tracker-demo.com/` and inspect the returned JSON and
  frontend boot data
- Evidence:
  - `GET https://grafana.torrust-tracker-demo.com/api/health` returns
    `HTTP/2 200` and exposes `database: ok`, version `12.3.1`, and commit
    `3a1c80ca7ce612f309fdc99338dd3c5e486339be`
  - The unauthenticated `/login` page exposes Grafana boot-data flags showing
    `anonymousEnabled: false`, `disableLoginForm: false`,
    `disableUserSignUp: true`, `publicDashboardsEnabled: true`,
    `pluginAdminEnabled: true`, `latestVersion: 12.4.2`, and `hasUpdate: true`
  - The same boot data exposes edition and plugin/app metadata, including the
    preinstalled drilldown apps
  - Protected JSON routes such as `/api/frontend/settings` and `/api/search`
    return proper `401` responses, which shows the disclosure is coming from
    intentionally public routes rather than from a server error path
- Impact: The public host gives unauthenticated visitors a clearer fingerprint
  of the Grafana deployment, including exact version, commit, update lag, and
  enabled feature or plugin surface, which can help attackers prioritize known
  issues or tailor follow-on probing.
- Remediation: Restrict or proxy-filter public Grafana routes that are not
  needed for the demo, especially `/api/health`, and reduce unauthenticated
  boot-data exposure where practical.
- Status: Open

### Finding: Public HTTPS hosts do not advertise HSTS

- Severity: Low
- Surface: Edge HTTPS hardening
- Preconditions: A user's first or non-pinned visit to one of the public HTTPS
  hosts over an attacker-controlled or hostile network
- Attack path: Induce the client to connect over plaintext HTTP first or strip
  the upgrade before HSTS has ever been cached; because the public hosts do not
  advertise `Strict-Transport-Security`, the browser is not instructed to pin
  HTTPS for future visits
- Evidence:
  - [../../../server/opt/torrust/docker-compose.yml](../../../server/opt/torrust/docker-compose.yml)
    explicitly publishes port `80` as `# HTTP (ACME HTTP-01 challenge)` for the
    Caddy service
  - `http://api.torrust-tracker-demo.com/`,
    `http://http1.torrust-tracker-demo.com/`,
    `http://http2.torrust-tracker-demo.com/`, and
    `http://grafana.torrust-tracker-demo.com/` all redirect to HTTPS with
    `HTTP 308`
  - Tested HTTPS root responses for `api.torrust-tracker-demo.com`,
    `http1.torrust-tracker-demo.com`, `http2.torrust-tracker-demo.com`, and
    `grafana.torrust-tracker-demo.com` did not include a
    `Strict-Transport-Security` header
  - [../../../server/opt/torrust/storage/caddy/etc/Caddyfile](../../../server/opt/torrust/storage/caddy/etc/Caddyfile)
    contains reverse-proxy site blocks for the public hosts and automatic
    Let's Encrypt handling, but no header directive that would add HSTS
- Impact: Plaintext-to-HTTPS redirect behavior is present, but first-visit
  users remain more exposed to downgrade or SSL-stripping attacks than they
  would be with HSTS enabled.
- Remediation: Add an HSTS policy on the public HTTPS hosts, ideally with a
  conservative initial max-age that can be increased after verification. This
  does not require closing port `80`; the current config explicitly keeps port
  `80` open for ACME HTTP-01 certificate issuance and renewal.
- Status: Open

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
  - Upstream deployer issue `torrust/torrust-tracker-deployer#254` explicitly
    tracks replacing `torrust/tracker:develop` with `torrust/tracker:v4.0.0`
    after the stable tracker release, and documents that `develop` is not a
    good choice for production deployments because it can introduce breaking
    changes at any time
  - Other core services in the same compose file are pinned to explicit version
    tags, which shows the mutable tags are an exception rather than the general
    deployment pattern
- Impact: Mutable tags weaken release traceability, make rollback and incident
  response harder, and increase the chance of unintentionally deploying code
  that differs from what operators believe is running.
- Remediation: Pin deployed images to immutable digests or at least fixed
  release tags, and record the exact deployed revision in the review evidence.
  The already-open upstream path is to switch the tracker image from
  `develop` to `v4.0.0` once that stable release is available.
- Status: Open. Upstream already tracks the tracker-tag remediation in
  `torrust/torrust-tracker-deployer#254`, but the live demo config still uses a
  mutable tracker tag today and the backup image remains on `latest`.

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
