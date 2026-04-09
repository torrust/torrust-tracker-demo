# HTTP and UDP Tracker - 2026-04

**Summary**: [README.md](README.md)
**Progress**: [progress.md](progress.md)

## Scope

- HTTP announce and scrape behavior
- UDP announce and scrape behavior
- Parser robustness and malformed input handling
- IP attribution and spoofing risks
- Abuse controls and rate limits

## Hypotheses

- The public tracker endpoints may accept malformed requests that reveal parser
  or bounds-handling weaknesses.
- Proxy-header trust for HTTP trackers may allow incorrect client IP
  attribution if upstream trust is weak.

## Evidence Reviewed

- [../../../server/opt/torrust/docker-compose.yml](../../../server/opt/torrust/docker-compose.yml)
- [../../../server/opt/torrust/storage/caddy/etc/Caddyfile](../../../server/opt/torrust/storage/caddy/etc/Caddyfile)
- [../../../server/opt/torrust/storage/tracker/etc/tracker.toml](../../../server/opt/torrust/storage/tracker/etc/tracker.toml)
- [../../../docs/infrastructure.md](../../../docs/infrastructure.md)

## Checks Performed

- Confirmed UDP ports `6969` and `6868` are published directly from the tracker
  container.
- Confirmed HTTP tracker ports `7070` and `7071` are exposed internally and
  published through Caddy virtual hosts.
- Confirmed `on_reverse_proxy = true` is enabled globally in the tracker
  configuration.

## Findings or Non-Findings

- No confirmed finding yet. The committed configuration establishes the exposed
  protocol surfaces but not their parser safety.

## Open Questions

- How does the deployed tracker handle malformed HTTP and UDP announce or scrape
  requests?
- Are there request-size or rate controls in the tracker implementation?

## Next Actions

- Review tracker source for HTTP and UDP request parsing and error handling.
- Validate live endpoint behavior with non-destructive protocol probes.
