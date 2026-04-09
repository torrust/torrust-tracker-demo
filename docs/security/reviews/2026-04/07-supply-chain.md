# Supply Chain - 2026-04

**Summary**: [README.md](README.md)
**Progress**: [progress.md](progress.md)

## Scope

- Image provenance and digests
- Mutable tags and version pinning
- Upstream revisions and release mapping
- Known CVEs affecting deployed versions
- Build and deployment traceability

## Hypotheses

- Mutable image tags reduce deployment reproducibility and complicate incident
  response.
- The exact source revision backing the deployed tracker image may be unknown.

## Evidence Reviewed

- [../../../server/opt/torrust/docker-compose.yml](../../../server/opt/torrust/docker-compose.yml)
- [../../../docs/infrastructure.md](../../../docs/infrastructure.md)

## Checks Performed

- Confirmed the tracker image is `torrust/tracker:develop`.
- Confirmed the backup image is `torrust/tracker-backup:latest`.
- Confirmed other core services are version-pinned by tag in compose: Caddy,
  Prometheus, Grafana, and MySQL.

## Findings or Non-Findings

- Confirmed finding recorded: the deployed compose config uses mutable image
  tags for the tracker and backup services, which reduces deployment
  reproducibility and weakens rollback and incident-response traceability.

## Open Questions

- Which image digests are currently deployed?
- Which tracker source revision corresponds to the deployed `develop` image?
- Are there known CVEs affecting the exact deployed image digests?

## Next Actions

- Collect live image digests and deployed revisions.
- Review upstream release and image provenance for the deployed services.
- Verify which digests are currently cached or running on the live host.
