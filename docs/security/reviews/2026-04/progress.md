# Security Review Progress - 2026-04

**Plan**: [../../security-review-plan.md](../../security-review-plan.md)
**Summary**: [README.md](README.md)
**Findings**: [findings.md](findings.md)

## Review Status

| Surface | Status | Notes |
| ------- | ------ | ----- |
| Caddy and HTTPS | In progress | Live root-path checks completed for API, Grafana, and HTTP tracker |
| Tracker API | In progress | Live unauthenticated requests return 500 with internal error text |
| HTTP and UDP tracker | In progress | `/announce` confirmed reachable over HTTPS |
| Grafana | In progress | Public hostname redirects to `/login` |
| SSH and host | Not started | Needs host runtime evidence |
| Container and persistence | In progress | Compose topology and mounts reviewed |
| Supply chain | In progress | Mutable tags identified from compose |

## Evidence Requested

- [ ] Tracker source repository and deployed revision
- [ ] Redacted `.env`
- [ ] `docker ps`
- [ ] `docker inspect` output
- [ ] `docker network inspect` output
- [ ] `ss -tulpn`
- [ ] `ufw status verbose`
- [ ] `sshd_config`
- [ ] Grafana auth and plugin details
- [ ] OS package update status

## Evidence Received

- Repository configuration under `server/`
- [../../../README.md](../../../README.md)
- [../../../docs/infrastructure.md](../../../docs/infrastructure.md)
- [../../../server/opt/torrust/docker-compose.yml](../../../server/opt/torrust/docker-compose.yml)
- [../../../server/opt/torrust/storage/caddy/etc/Caddyfile](../../../server/opt/torrust/storage/caddy/etc/Caddyfile)
- [../../../server/opt/torrust/storage/tracker/etc/tracker.toml](../../../server/opt/torrust/storage/tracker/etc/tracker.toml)
- [../../../server/etc/ufw/user.rules](../../../server/etc/ufw/user.rules)
- [../../../server/etc/ufw/user6.rules](../../../server/etc/ufw/user6.rules)
- [../../../server/etc/ufw/before6.rules](../../../server/etc/ufw/before6.rules)
- Live HTTP response headers and bodies for `api.torrust-tracker-demo.com`,
  `grafana.torrust-tracker-demo.com`, and `http1.torrust-tracker-demo.com`

## Working Notes

- Public surfaces visible from repo config: Caddy on `80/443`, SSH on `22`,
  UDP tracker on `6969` and `6868`, public Grafana through Caddy, and tracker
  API through Caddy.
- The tracker container uses the mutable image tag `torrust/tracker:develop`.
- The backup service uses `torrust/tracker-backup:latest`, which is also
  mutable.
- Tracker, Caddy, Grafana, and backup all rely on mounted persistent storage.
- HTTP tracker routes trust reverse-proxy headers for client IP attribution.
- Live checks observed:
  - `https://api.torrust-tracker-demo.com/` returns `HTTP/2 500`
  - `https://api.torrust-tracker-demo.com/health_check` returns `HTTP/2 500`
  - API root body exposes `Unhandled rejection: Err { reason: "unauthorized" }`
  - `https://grafana.torrust-tracker-demo.com/` returns `HTTP/2 302` with
    `Location: /login`
  - `https://http1.torrust-tracker-demo.com/` returns `HTTP/2 404`
  - `https://http1.torrust-tracker-demo.com/announce` returns `HTTP/2 200`

## Blockers

- Live runtime evidence has not been collected yet.
- The deployed tracker source revision is still unknown.

## Next Actions

- Request live runtime evidence from the operator.
- Obtain the tracker source repository and deployed revision.
- Start source-backed review of Caddy, tracker API, and tracker protocol
  handling.
- Determine whether the API `500 unauthorized` behavior is expected router
  behavior or a bug in upstream error handling.
