# Grafana Public Dashboard URLs Use `localhost` Instead of Real Domain

**Issue**: [#9](https://github.com/torrust/torrust-tracker-demo/issues/9)
**Related**: [torrust/torrust-tracker-deployer#415](https://github.com/torrust/torrust-tracker-deployer/issues/415) — fix should also be applied upstream in the deployer

## Problem

When sharing a Grafana dashboard publicly via **Share → Public dashboard**, Grafana
generates a URL with `localhost:3000` as the base. For example, sharing the
Tracker Overview dashboard produced:

```text
http://localhost:3000/public-dashboards/186b355b56cd482d9c441a0affdb8ecd
```

This URL is not reachable from outside the server.

## Root Cause

Grafana builds share URLs using its `root_url` server setting. The default value is
`http://localhost:3000/`. Because `GF_SERVER_ROOT_URL` was not set in the Grafana
container environment, Grafana fell back to this default when constructing the
public dashboard link.

See the Grafana documentation:
[Externally shared dashboards](https://grafana.com/docs/grafana/next/visualizations/dashboards/share-dashboards-panels/shared-dashboards/)

## Workaround — Manual URL Reconstruction

The access token in the generated URL is valid; only the base URL is wrong. The
corrected URL for the Tracker Overview dashboard is:

```text
https://grafana.torrust-tracker-demo.com/public-dashboards/186b355b56cd482d9c441a0affdb8ecd
```

This was verified and confirmed to work. The pattern for fixing any generated URL is:

| Replace                 | With                                       |
| ----------------------- | ------------------------------------------ |
| `http://localhost:3000` | `https://grafana.torrust-tracker-demo.com` |

The remaining two dashboards still need public sharing enabled in the Grafana UI so
their access tokens can be collected:

| Dashboard        | File                                                  | UID                        | Public URL               |
| ---------------- | ----------------------------------------------------- | -------------------------- | ------------------------ |
| Tracker Overview | `backups/grafana/dashboards/01-tracker-overview.json` | `torrust-tracker-overview` | _(see workaround above)_ |
| UDP Tracker 1    | `backups/grafana/dashboards/02-udp-tracker-1.json`    | `torrust-udp-tracker-1`    | _(not yet enabled)_      |
| HTTP Tracker 1   | `backups/grafana/dashboards/03-http-tracker-1.json`   | `torrust-http-tracker-1`   | _(not yet enabled)_      |

## Proper Fix

Add `GF_SERVER_ROOT_URL` to the Grafana service in `docker-compose.yml`, following
the existing environment variable injection pattern — value in `.env`, reference in
`docker-compose.yml`, no hardcoded URLs.

### Change 1 — `server/opt/torrust/docker-compose.yml`

```yaml
grafana:
  environment:
    - GF_SECURITY_ADMIN_USER=${GF_SECURITY_ADMIN_USER}
    - GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD}
    - GF_SERVER_ROOT_URL=${GF_SERVER_ROOT_URL}
```

### Change 2 — `server/opt/torrust/.env`

Add the following entry in the Grafana section:

```dotenv
# Grafana server root URL — used to generate correct public dashboard share links
GF_SERVER_ROOT_URL='https://grafana.torrust-tracker-demo.com'
```

After deploying, restart the Grafana container:

```sh
docker compose up -d grafana
```

New public dashboard share links will automatically use the correct base URL.
Existing access tokens remain valid — only the base URL changes.

## Additional Work

As part of this fix, also:

### 1. Enable public sharing for all three dashboards

In the Grafana UI, open each dashboard and go to **Share → Public dashboard** to
enable public access and obtain the access token. Collect all three final
public URLs:

| Dashboard        | Expected public URL pattern                                                   |
| ---------------- | ----------------------------------------------------------------------------- |
| Tracker Overview | `https://grafana.torrust-tracker-demo.com/public-dashboards/<access-token-1>` |
| UDP Tracker 1    | `https://grafana.torrust-tracker-demo.com/public-dashboards/<access-token-2>` |
| HTTP Tracker 1   | `https://grafana.torrust-tracker-demo.com/public-dashboards/<access-token-3>` |

### 2. Create a combined dashboard preview image

Individual screenshots for all three dashboards already exist alongside their JSON
exports in `backups/grafana/dashboards/`:

| Dashboard        | Screenshot                                           |
| ---------------- | ---------------------------------------------------- |
| Tracker Overview | `backups/grafana/dashboards/01-tracker-overview.png` |
| UDP Tracker 1    | `backups/grafana/dashboards/02-udp-tracker-1.png`    |
| HTTP Tracker 1   | `backups/grafana/dashboards/03-http-tracker-1.png`   |

Compose those three into a single side-by-side (or grid) image and save it to
`docs/media/grafana-dashboards.webp`. This composite will be the hero image
shown in the README. The individual screenshots in `backups/grafana/dashboards/`
serve as detailed references and can be linked from the README section as well.

### 3. Update `README.md`

Add a **Grafana Dashboards** section to the README that shows the composite preview
image, links to all three public dashboards, and links to the individual detailed
screenshots in `backups/grafana/dashboards/`. Suggested placement: after the existing
live demo endpoints block and before the Background section.

Example structure:

```markdown
## Grafana Dashboards

Live public dashboards are available without a Grafana account:

[![Grafana dashboards preview](docs/media/grafana-dashboards.webp)](https://grafana.torrust-tracker-demo.com)

| Dashboard        | Public link                                                                         | Screenshot                                                 |
| ---------------- | ----------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Tracker Overview | [open](https://grafana.torrust-tracker-demo.com/public-dashboards/<access-token-1>) | [view](backups/grafana/dashboards/01-tracker-overview.png) |
| UDP Tracker 1    | [open](https://grafana.torrust-tracker-demo.com/public-dashboards/<access-token-2>) | [view](backups/grafana/dashboards/02-udp-tracker-1.png)    |
| HTTP Tracker 1   | [open](https://grafana.torrust-tracker-demo.com/public-dashboards/<access-token-3>) | [view](backups/grafana/dashboards/03-http-tracker-1.png)   |
```
