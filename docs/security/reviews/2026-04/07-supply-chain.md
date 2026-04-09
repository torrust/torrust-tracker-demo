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
- Upstream issue: `torrust/torrust-tracker-deployer#254`

## Checks Performed

- Confirmed the tracker image is `torrust/tracker:develop`.
- Confirmed the backup image is `torrust/tracker-backup:latest`.
- Confirmed other core services are version-pinned by tag in compose: Caddy,
  Prometheus, Grafana, and MySQL.
- Confirmed upstream deployer issue `#254` explicitly plans to replace
  `torrust/tracker:develop` with `torrust/tracker:v4.0.0` after the stable
  tracker release.
- Confirmed the upstream rationale for that change matches this review: the
  `develop` tag is considered unsuitable for production because it can change
  unexpectedly and should only be updated after manual compatibility
  verification.
- Confirmed a quick upstream issue search did not reveal a backup-image pinning
  issue equivalent to tracker issue `#254`; the closest related results were
  the broader Docker image refresh issue `#317` and backup-image CVE follow-up
  issue `#431`.

## Findings or Non-Findings

- Confirmed finding recorded: the deployed compose config uses mutable image
  tags for the tracker and backup services, which reduces deployment
  reproducibility and weakens rollback and incident-response traceability.
- The tracker-tag portion of this finding is not speculative; the deployer
  project already tracks it as a blocked follow-up awaiting a stable tracker
  release.

## Open Questions

- Which image digests are currently deployed?
- Which tracker source revision corresponds to the deployed `develop` image?
- Are there known CVEs affecting the exact deployed image digests?
- Should a dedicated upstream task be opened to pin
  `torrust/tracker-backup:latest` with the same level of traceability as the
  tracker image?

## Next Actions

- Collect live image digests and deployed revisions.
- Review upstream release and image provenance for the deployed services.
- Verify which digests are currently cached or running on the live host.
- Track whether `torrust/torrust-tracker-deployer#254` is implemented and
  whether a corresponding backup-image pinning task should be added upstream.
