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

- Public tracker v1 API unauthenticated requests return `500` and expose
  internal unauthorized error text instead of a proper client error.

## Rejected Hypotheses

- None recorded yet.

## Follow-Up Actions

- Request live runtime evidence listed in `progress.md`.
- Obtain the exact deployed tracker revision.
- Continue source-backed review of the public API and tracker request handling.
- Validate whether the current API authorization error mapping and routing on
  unrelated paths are both upstream behaviors.

## Open Questions

- Which exact tracker source revision backs the deployed `torrust/tracker:develop`
  image?
- Why do unrelated API-host paths such as `/` and `/swagger` still hit the same
  unauthorized `500` path instead of a clean `404`?
- Is Grafana login enabled on the public hostname or restricted to public
  dashboards only?
- What SSH authentication policy is active on the host?
