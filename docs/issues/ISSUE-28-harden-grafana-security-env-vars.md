# Harden Grafana Configuration with Missing Security Environment Variables

**Issue**: [#28](https://github.com/torrust/torrust-tracker-demo/issues/28)
**Related**: [#27](https://github.com/torrust/torrust-tracker-demo/issues/27)

## Overview

During a Grafana log investigation on 2026-04-20 we audited the Grafana service configuration
in `server/opt/torrust/docker-compose.yml`. Comparing the current environment against the
[Grafana security hardening guide](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-security-hardening/)
revealed several variables that should be explicitly set rather than left to their defaults.

Grafana is served exclusively over HTTPS (Caddy handles TLS termination) with no OAuth or
SAML configured, so all the recommended hardening options apply without caveats.

This issue tracks adding the missing variables and documenting the decisions made for each one.

## Current State

The Grafana service in `server/opt/torrust/docker-compose.yml` currently sets:

```yaml
environment:
  - GF_SECURITY_ADMIN_USER=${GF_SECURITY_ADMIN_USER}
  - GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD}
  - GF_SERVER_ROOT_URL=${GF_SERVER_ROOT_URL}
```

No security hardening variables are present.

## Identified Gaps

The following variables are absent and their defaults leave the instance less secure.

### Cookie hardening

| Variable                      | Default | Recommended | Reason                                                                                                                                                              |
| ----------------------------- | ------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `GF_SECURITY_COOKIE_SECURE`   | `false` | `true`      | Sets the `Secure` attribute on the session cookie. Required when Grafana is behind an HTTPS reverse proxy; prevents the cookie from being sent over plaintext HTTP. |
| `GF_SECURITY_COOKIE_SAMESITE` | `lax`   | `strict`    | Sets the `SameSite=Strict` attribute to mitigate CSRF attacks. Safe to use when no OAuth or SAML login is configured (those require `lax`).                         |

### Version disclosure

| Variable                         | Default | Recommended | Reason                                                                                                                           |
| -------------------------------- | ------- | ----------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `GF_AUTH_ANONYMOUS_HIDE_VERSION` | `false` | `true`      | Hides the running Grafana version from unauthenticated users. Prevents trivial fingerprinting to find known-vulnerable versions. |

### DNS rebinding protection

| Variable                   | Default | Recommended | Reason                                                                                                        |
| -------------------------- | ------- | ----------- | ------------------------------------------------------------------------------------------------------------- |
| `GF_SERVER_ENFORCE_DOMAIN` | `false` | `true`      | Redirects requests whose `Host` header does not match the configured domain. Mitigates DNS rebinding attacks. |

### Variables confirmed safe at their defaults

| Variable                       | Default | Notes                                         |
| ------------------------------ | ------- | --------------------------------------------- |
| `GF_USERS_ALLOW_SIGN_UP`       | `false` | Self-registration disabled. No change needed. |
| `GF_AUTH_ANONYMOUS_ENABLED`    | `false` | Anonymous access disabled. No change needed.  |
| `GF_SECURITY_DISABLE_GRAVATAR` | `false` | Cosmetic only; no security impact.            |

### Variables to decide as part of this issue

- `GF_SECURITY_CONTENT_SECURITY_POLICY` — Grafana's built-in CSP header. Caddy does not
  set a CSP header by default, so this could be enabled. Needs testing to confirm Grafana
  dashboards and plugins render correctly under the default CSP template.
- `GF_SECURITY_STRICT_TRANSPORT_SECURITY` — HSTS via Grafana. Caddy already sends HSTS
  headers on the HTTPS listener, so enabling this in Grafana too is redundant. Recommend
  leaving it disabled and documenting the decision.
- `GF_AUTH_LOGIN_COOKIE_NAME` with a `__Host-` prefix — cookie-prefix hardening (prevents
  overwriting the session cookie in a MITM scenario even with HTTPS). More invasive change;
  worth evaluating separately.
- Metrics endpoint auth (`GF_METRICS_BASIC_AUTH_USERNAME` / `GF_METRICS_BASIC_AUTH_PASSWORD`)
  — the `/metrics` endpoint is accessible without auth by default. Needs confirming whether
  this endpoint is reachable from outside the Docker network before deciding.

## Proposed Change

Add the confirmed variables to the Grafana service environment in
`server/opt/torrust/docker-compose.yml`:

```yaml
environment:
  - GF_SECURITY_ADMIN_USER=${GF_SECURITY_ADMIN_USER}
  - GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD}
  - GF_SERVER_ROOT_URL=${GF_SERVER_ROOT_URL}
  - GF_SECURITY_COOKIE_SECURE=true
  - GF_SECURITY_COOKIE_SAMESITE=strict
  - GF_AUTH_ANONYMOUS_HIDE_VERSION=true
  - GF_SERVER_ENFORCE_DOMAIN=true
```

After updating the file in the repository, apply the change to the live server:

```bash
cd /opt/torrust
# pull updated docker-compose.yml from repo
docker compose up -d grafana
```

Grafana does not need a full image pull — `up -d` recreates the container with the new
environment and reconnects to the existing data volume.

## Implementation Plan

- [ ] Add `GF_SECURITY_COOKIE_SECURE=true` to the Grafana service env.
- [ ] Add `GF_SECURITY_COOKIE_SAMESITE=strict` to the Grafana service env.
- [ ] Add `GF_AUTH_ANONYMOUS_HIDE_VERSION=true` to the Grafana service env.
- [ ] Add `GF_SERVER_ENFORCE_DOMAIN=true` to the Grafana service env.
- [ ] Decide on `GF_SECURITY_CONTENT_SECURITY_POLICY` — test and document the decision.
- [ ] Decide on `GF_SECURITY_STRICT_TRANSPORT_SECURITY` — document the decision (likely:
      leave disabled; Caddy already sends HSTS).
- [ ] Decide on cookie-prefix hardening and metrics endpoint auth — scope or defer.
- [ ] Apply the change to the live server (`docker compose up -d grafana`).
- [ ] Verify the session cookie attributes in browser DevTools
      (Application → Cookies: `Secure`, `SameSite=Strict`).
- [ ] Confirm Grafana UI is fully functional after the change (dashboards, login, data sources).

## Acceptance Criteria

- [ ] All confirmed variables are present in `server/opt/torrust/docker-compose.yml`.
- [ ] The live server Grafana container is running with the new variables.
- [ ] The session cookie carries the `Secure` and `SameSite=Strict` attributes (verified
      in browser DevTools).
- [ ] A documented decision exists for each "to decide" variable listed above.
- [ ] All changed files pass `./scripts/lint.sh`.
