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
- Upstream tracker source:
  - `packages/axum-http-tracker-server/src/v1/extractors/announce_request.rs`
  - `packages/udp-tracker-server/src/handlers/mod.rs`
  - `packages/udp-tracker-server/src/handlers/connect.rs`
  - `packages/udp-tracker-server/src/handlers/error.rs`
  - `packages/udp-tracker-server/src/error.rs`
  - `packages/udp-tracker-core/src/services/connect.rs`

## Checks Performed

- Confirmed UDP ports `6969` and `6868` are published directly from the tracker
  container.
- Confirmed HTTP tracker ports `7070` and `7071` are exposed internally and
  published through Caddy virtual hosts.
- Confirmed `on_reverse_proxy = true` is enabled globally in the tracker
  configuration.
- Confirmed live HTTP tracker behavior:
  - `/` returns `HTTP 404`
  - `/announce` returns `HTTP 200`
  - `/health_check` returns `HTTP 200` with body `{"status":"Ok"}`
  - `/stats`, `/metrics`, and `/robots.txt` return `HTTP 404`
  - `/announce` without query params returns a bencoded failure response
    explaining that query params are missing
  - `http2.torrust-tracker-demo.com` mirrors `http1.torrust-tracker-demo.com`
    for `/announce` and `/health_check`
  - `HEAD /announce` returns `HTTP 200`
  - `POST /announce` returns `HTTP 405` with `Allow: GET,HEAD`
  - `OPTIONS /announce` returns `HTTP 405` with `Allow: GET,HEAD`
  - Malformed announce query params still return tracker-level bencoded parse
    errors rather than generic server failures
- Confirmed upstream HTTP announce extractor behavior:
  - Missing or invalid announce query parameters are converted into
    tracker-format bencoded error bodies
  - Those parser errors are intentionally returned with `HTTP 200`, not a
    generic `5xx` response
- Confirmed live UDP tracker behavior with a standard BitTorrent connect probe:
  - IPv4 on `udp1.torrust-tracker-demo.com:6969` returns a valid 16-byte
    connect response with matching transaction ID
  - Short malformed packets can trigger explicit UDP error frames with action
    `3`, transaction ID `0`, and parser messages such as `Couldn't parse
    action` and `Invalid action`
  - Some other malformed but parseable-looking datagrams still timed out during
    probing, including invalid-action and wrong-protocol connect-sized payloads
  - IPv6 on `udp1.torrust-tracker-demo.com:6969` timed out from this review
    environment
- Confirmed upstream UDP connect and error-handling behavior:
  - Connect requests are parsed centrally through `Request::parse_bytes(...)`
    before dispatch
  - Successful connect responses echo the client transaction ID and return a
    generated connection cookie derived from the remote socket fingerprint and
    current issue time
  - Parse failures are routed into the UDP error handler, which builds a
    protocol error response even when no transaction ID is available

## Findings or Non-Findings

- No confirmed finding yet. The committed configuration establishes the exposed
  protocol surfaces but not their parser safety.
- No new finding yet. The public HTTP tracker appears to expose only the
  expected tracker route plus a health endpoint.
- The HTTP tracker route behavior looks comparatively well-bounded: unsupported
  methods are rejected with `405`, and malformed requests return tracker-level
  error content instead of a generic server failure.
- No new finding yet. The second HTTP tracker host appears to mirror the first
  rather than exposing a meaningfully different HTTP surface.
- No confirmed security finding yet from the UDP probe. IPv4 behavior looks like
  a normal tracker, and at least some malformed UDP inputs are converted into
  bounded protocol error frames instead of crashing or exposing a generic
  server failure.
- The live UDP surface does not yet appear fully characterized: some malformed
  datagrams received structured error replies, while others timed out despite
  the current upstream handler being capable of emitting error responses for
  parse failures.

## Open Questions

- How does the deployed tracker handle malformed HTTP and UDP announce or scrape
  requests?
- Are there request-size or rate controls in the tracker implementation?
- Is the public HTTP health endpoint an intentional part of the demo exposure?
- Why do some invalid UDP datagrams receive explicit error frames while others
  time out on the live service?
- Is the UDP IPv6 timeout an intentional deployment constraint or an
  availability issue on the advertised host?

## Next Actions

- Review tracker source for HTTP and UDP request parsing and error handling.
- Validate live endpoint behavior with non-destructive protocol probes.
- Compare additional malformed UDP request classes against the current upstream
  parser and error path.
- Avoid broader active probing unless new evidence suggests parser weakness.
