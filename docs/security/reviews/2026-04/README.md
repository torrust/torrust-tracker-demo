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

- None recorded yet.

## Rejected Hypotheses

- None recorded yet.

## Follow-Up Actions

- Request live runtime evidence listed in `progress.md`.
- Obtain the tracker source repository and deployed revision.
- Begin source-backed review of the public API and tracker request handling.

## Open Questions

- Which exact tracker source revision backs the deployed `torrust/tracker:develop`
  image?
- Is Grafana login enabled on the public hostname or restricted to public
  dashboards only?
- What SSH authentication policy is active on the host?
