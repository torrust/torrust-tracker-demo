# Security Review Progress - 2026-04

**Plan**: [../../security-review-plan.md](../../security-review-plan.md)
**Summary**: [README.md](README.md)
**Findings**: [findings.md](findings.md)

## Review Status

| Surface | Status | Notes |
| ------- | ------ | ----- |
| Caddy and HTTPS | In progress | Repository config reviewed; runtime validation pending |
| Tracker API | In progress | Public exposure confirmed; source review pending |
| HTTP and UDP tracker | In progress | Public endpoints identified from config |
| Grafana | In progress | Public exposure confirmed; auth details pending |
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

## Working Notes

- Public surfaces visible from repo config: Caddy on `80/443`, SSH on `22`,
  UDP tracker on `6969` and `6868`, public Grafana through Caddy, and tracker
  API through Caddy.
- The tracker container uses the mutable image tag `torrust/tracker:develop`.
- The backup service uses `torrust/tracker-backup:latest`, which is also
  mutable.
- Tracker, Caddy, Grafana, and backup all rely on mounted persistent storage.
- HTTP tracker routes trust reverse-proxy headers for client IP attribution.

## Blockers

- Live runtime evidence has not been collected yet.
- The deployed tracker source revision is still unknown.

## Next Actions

- Request live runtime evidence from the operator.
- Obtain the tracker source repository and deployed revision.
- Start source-backed review of Caddy, tracker API, and tracker protocol
  handling.
