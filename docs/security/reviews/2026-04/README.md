# Security Review Summary - 2026-04

**Plan**: [../../security-review-plan.md](../../security-review-plan.md)
**Issue**: [#13](https://github.com/torrust/torrust-tracker-demo/issues/13)
**Status**: In progress

## Review Metadata

- Review cycle: `2026-04`
- Reviewer: GitHub Copilot with repository maintainer input
- Start date: 2026-04-09
- End date:

## Scope Covered

- [ ] Caddy and HTTPS routing
- [ ] Tracker API
- [ ] HTTP and UDP tracker protocol surface
- [ ] Grafana
- [ ] SSH and host exposure
- [ ] Container, persistence, and lateral movement
- [ ] Supply chain and deployment provenance

## Deployment Summary

- Repository revision: `7e57cddf091fc8e388b0acb891a66154f456a296`
- Deployed tracker revision:
- Container image digests reviewed:
- Host runtime summary: Repository configuration reviewed only. Live runtime
  evidence not collected yet.

## Evidence Reviewed

- Repository configuration in `server/`
- [README.md](../../../README.md)
- [../../security-review-plan.md](../../security-review-plan.md)
- [../../../server/opt/torrust/docker-compose.yml](../../../server/opt/torrust/docker-compose.yml)
- [../../../server/opt/torrust/storage/caddy/etc/Caddyfile](../../../server/opt/torrust/storage/caddy/etc/Caddyfile)
- [../../../server/opt/torrust/storage/tracker/etc/tracker.toml](../../../server/opt/torrust/storage/tracker/etc/tracker.toml)
- [../../../docs/infrastructure.md](../../../docs/infrastructure.md)
- [../../../server/etc/ufw/user.rules](../../../server/etc/ufw/user.rules)
- [../../../server/etc/ufw/user6.rules](../../../server/etc/ufw/user6.rules)
- [../../../server/etc/ufw/before6.rules](../../../server/etc/ufw/before6.rules)

## Confirmed Findings

- The public HTTPS hosts redirect HTTP to HTTPS but do not advertise HSTS,
  leaving a low-severity edge-hardening gap for first-visit clients.
- The deployed compose config uses mutable image tags for the tracker and
  backup services, which reduces deployment traceability and rollback
  confidence.
- Public tracker API host requests return `500` and expose internal auth error
  text instead of proper client errors, including on apparently unrelated paths.

## Rejected Hypotheses

- None recorded yet.

## Follow-Up Actions

- Request live runtime evidence listed in `progress.md`.
- Obtain the exact deployed tracker revision.
- Collect the exact image digests currently deployed for the tracker and backup
  services.
- Continue source-backed review of the public API, edge behavior, and tracker
  request handling.
- Confirm whether the deployed tracker image matches the current upstream API
  router and auth middleware layout.

## Open Questions

- Which exact tracker source revision backs the deployed `torrust/tracker:develop`
  image?
- Which exact image digests are currently running for the tracker and backup
  services?
- What SSH authentication policy is active on the host?
