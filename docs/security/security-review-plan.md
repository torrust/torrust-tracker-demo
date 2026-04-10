# Security Review Plan

This document defines a repeatable security review process for the live Torrust
Tracker Demo deployment. The goal of the review is to identify realistic paths
an attacker could use to gain initial access to the demo server, a running
container, or privileged application functionality, and to document the
evidence, impact, and remediation for each finding.

This is a living document. It should be re-evaluated periodically and updated
after meaningful infrastructure or application changes.

## Review Goal

The primary question for this review is:

> How could an external attacker obtain meaningful access to the demo server or
> its deployed services?

For this plan, meaningful access includes any of the following outcomes:

- Host shell access.
- Access to a running container with useful persistence or secrets.
- Access to privileged application functionality such as admin APIs or Grafana
  administration.
- Access to sensitive data such as credentials, tokens, database contents, or
  configuration not intended to be public.
- The ability to modify service behavior, deployed configuration, or persistent
  state.

## Scope

The review covers the full public-facing tracker demo deployment described in
[README.md](../../README.md), [infrastructure.md](../infrastructure.md), and
the configuration under [server/](../../server/README.md).

### In scope

- Public HTTP and HTTPS endpoints served through Caddy.
- Public UDP tracker endpoints.
- Public Grafana exposure and dashboard-sharing configuration.
- Public tracker API exposure and authentication model.
- SSH access and host-level hardening.
- Docker Compose topology, container isolation, volumes, and network exposure.
- Secret handling through environment variables, mounted files, and backups.
- Supply-chain risks in container images and deployment artifacts.
- Misconfiguration that enables lateral movement from one service to another.

### Out of scope by default

- Denial-of-service resistance and capacity testing.
- Social engineering.
- Third-party provider compromise such as Hetzner control-plane compromise.
- Vulnerabilities in services not deployed on this demo server.

These items can be added explicitly when needed, but they are not required for
the baseline recurring review.

## Review Cadence

Run this review at the following times:

- Quarterly.
- After major infrastructure changes.
- After public exposure of a new endpoint, hostname, or port.
- After changes to authentication, secrets, Docker networking, or firewall
  rules.
- After upgrading core services such as the tracker, Caddy, Grafana, Docker,
  MySQL, or the OS.
- After any security incident, suspicious activity, or near miss.

## Current Deployment Summary

At the time this plan was written, the deployment exposes the following public
surfaces:

- HTTPS via Caddy on ports `80` and `443`.
- UDP tracker on port `6969`.
- UDP tracker on port `6868`.
- SSH on port `22`.
- Public Grafana through Caddy.
- Public tracker API through Caddy.

Relevant configuration references:

- [server/opt/torrust/docker-compose.yml](../../server/opt/torrust/docker-compose.yml)
- [server/opt/torrust/storage/caddy/etc/Caddyfile](../../server/opt/torrust/storage/caddy/etc/Caddyfile)
- [server/opt/torrust/storage/tracker/etc/tracker.toml](../../server/opt/torrust/storage/tracker/etc/tracker.toml)
- [server/etc/ufw/user.rules](../../server/etc/ufw/user.rules)
- [server/etc/ufw/user6.rules](../../server/etc/ufw/user6.rules)
- [server/etc/ufw/before6.rules](../../server/etc/ufw/before6.rules)
- [infrastructure.md](../infrastructure.md)

## Review Method

The review should proceed in phases so that configuration review, source review,
and runtime validation reinforce each other.

## Review Workspace Layout

Each review cycle should have its own folder under `docs/security/reviews/` so
that in-progress work and final reporting stay grouped together.

Recommended structure:

```text
docs/security/reviews/
└── <review-cycle>/
    ├── README.md
    ├── progress.md
    ├── findings.md
    ├── 01-caddy-and-https.md
    ├── 02-tracker-api.md
    ├── 03-http-and-udp-tracker.md
    ├── 04-grafana.md
    ├── 05-ssh-and-host.md
    ├── 06-container-and-persistence.md
    └── 07-supply-chain.md
```

Naming convention:

- Use one folder per review cycle.
- Prefer a time-based folder name such as `2026-04` or `2026-q2`.
- Keep raw sensitive evidence out of git. Only commit sanitized excerpts,
  conclusions, and references to privately stored evidence when needed.

Purpose of each file:

- `README.md` is the final summary report for the review cycle.
- `progress.md` tracks work in progress, evidence requested, status by attack
  surface, and open questions.
- `findings.md` is the consolidated list of confirmed findings and accepted
  risks.
- The numbered surface files hold the detailed review notes for each exposed
  service or attack surface.

## Phase 1: Baseline Inventory

Build an inventory of the live environment before testing assumptions.

Checklist:

- Confirm all public DNS records and host names.
- Confirm all listening ports on the host.
- Confirm all Docker-published ports.
- Confirm which services are intentionally public and which are internal only.
- Record exact container image tags and image digests.
- Record exact deployed application revisions where available.
- Record OS version, Docker version, and package update status.

Primary evidence to collect:

- `docker ps`
- `docker inspect <container>`
- `docker network inspect <network>`
- `ss -tulpn`
- `ufw status verbose`
- `iptables-save`
- `ip6tables-save`
- Exact deployment `.env` variable names with secret values redacted

## Phase 2: External Attack Surface Review

Review every network-reachable entry point as if no credentials are available.

### Caddy and HTTPS routes

Review goals:

- Confirm only intended virtual hosts are exposed.
- Confirm no administrative interface is reachable.
- Confirm header trust boundaries are correct.
- Confirm reverse proxy configuration does not unintentionally expose backend
  endpoints.

Checks:

- Enumerate configured host names and path routing.
- Review how `X-Forwarded-For` and related headers are trusted by the tracker.
- Check whether unexpected host headers or fallback routes reach a backend.
- Check TLS configuration, redirects, and certificate handling.

### Tracker API

Review goals:

- Identify all public endpoints.
- Confirm which endpoints require authentication.
- Confirm whether admin token use is minimal and correctly scoped.

Checks:

- Review all routes and methods in the tracker source code.
- Review token parsing, storage, comparison, and logging behavior.
- Identify any debug, diagnostics, metrics, or file-serving endpoints.
- Verify whether malformed requests can trigger panics, unexpected disclosure,
  or state changes.

### Grafana

Review goals:

- Confirm that public access is limited to the intended dashboard-sharing model.
- Confirm admin access is not exposed accidentally.
- Confirm secrets and plugins do not expand the attack surface unnecessarily.

Checks:

- Review Grafana authentication and anonymous-access configuration.
- Review public dashboard exposure.
- Confirm whether login is enabled on the public hostname.
- Review installed plugins and their provenance.
- Review known security advisories for the deployed Grafana version.

### HTTP and UDP tracker endpoints

Review goals:

- Identify parser, protocol, and request-handling risks.
- Confirm that tracker endpoints do not expose administrative behavior.

Checks:

- Review announce and scrape handling in the tracker source.
- Review request parsing, bounds handling, and error paths.
- Review whether peer IP handling can be spoofed through proxy headers.
- Review rate limiting and abuse controls.
- Review whether malformed UDP or HTTP requests can crash the service or lead
  to unexpected state.

### SSH

Review goals:

- Confirm the host does not present a low-effort initial access path.

Checks:

- Review `sshd_config`.
- Confirm whether password authentication is disabled.
- Confirm whether root login is disabled.
- Confirm which users have shell access and sudo rights.
- Confirm whether rate limiting, logging, and alerting are in place.

## Phase 3: Source Code Review

Configuration review alone is not enough. Review the source code for every
publicly reachable custom service or custom wrapper.

Priority order:

1. Tracker source code.
2. Any custom deployment scripts or wrappers that handle secrets, backups, or
   service startup.
3. Any custom Grafana provisioning or Caddy templating logic if the deployed
   runtime differs from this repository.

Source review goals:

- Identify authentication and authorization boundaries.
- Identify unsafe parsing and deserialization paths.
- Identify sensitive endpoints not obvious from configuration.
- Identify filesystem, shell, subprocess, SSRF, SQL, or template injection
  risks.
- Identify unsafe assumptions about proxy headers and client identity.

## Phase 4: Container and Host Hardening Review

Assume one internet-facing service is compromised and determine how far an
attacker can go.

Checks:

- Confirm container user IDs and whether services run as root.
- Confirm dropped and added Linux capabilities.
- Confirm whether any container has access to the Docker socket.
- Review writable host mounts and persistent volumes.
- Review whether secrets are exposed through environment variables, mounted
  files, logs, or backups.
- Review inter-container network reachability and whether it is necessary.
- Review whether a compromise of tracker, Caddy, or Grafana can reach MySQL,
  Prometheus, or sensitive files.
- Review cron jobs and backup scripts for privilege escalation or secret
  exposure paths.

## Phase 5: Supply-Chain Review

Review whether the deployment depends on mutable, unpinned, or weakly verified
artifacts.

Checks:

- Confirm exact image digests for all deployed containers.
- Confirm whether images are pinned to immutable versions.
- Confirm whether any service is running from a mutable tag such as `develop` or
  `latest`.
- Review recent CVEs affecting the deployed OS and container images.
- Review how deployment artifacts are produced and whether provenance can be
  reconstructed.

## Phase 6: Validation and Reporting

After reviewing configuration and source, validate realistic attack paths in a
controlled and authorized manner.

Validation principles:

- Prefer non-destructive checks first.
- Avoid denial-of-service testing on production unless explicitly scheduled.
- Test the smallest proof needed to validate a finding.
- Record exact preconditions and evidence.

Each finding should contain:

- Title.
- Severity.
- Affected component.
- Preconditions.
- Attack path.
- Evidence.
- Impact.
- Recommended remediation.
- Whether the issue is configuration-specific, code-specific, or both.

Reporting rules:

- Record hypotheses and partial observations in the surface files while the
  review is in progress.
- Move only confirmed findings into `findings.md`.
- Use `README.md` as the final review summary once the cycle is complete.
- Keep `progress.md` current so another reviewer can continue the work without
  reconstructing context.

## Recurring Review Checklist

Use this checklist for each periodic review.

- [ ] Reconfirm all public endpoints, ports, and DNS records.
- [ ] Reconfirm all Docker-published ports and container image digests.
- [ ] Reconfirm that only intended services are public.
- [ ] Reconfirm SSH hardening and user access.
- [ ] Review changes to Docker Compose, Caddy, tracker, firewall, and netplan.
- [ ] Review changes to secrets, tokens, backup scripts, and mounted volumes.
- [ ] Review tracker source changes affecting HTTP, UDP, API, auth, or proxy
      handling.
- [ ] Review Grafana version, auth mode, plugins, and public dashboard settings.
- [ ] Review CVEs and upstream advisories for OS and deployed images.
- [ ] Re-evaluate any prior accepted risks.
- [ ] Re-run focused validation for all previously high-severity findings.
- [ ] Record new findings, changes in severity, and remediation status.

## Evidence Request Template

When preparing a review, gather the following from the live environment and any
upstream repositories involved:

- Source repository URL and exact deployed revision for the tracker.
- Source repository URL and exact deployed revision for any custom backup,
  startup, or helper service.
- Redacted `.env` file showing variable names.
- `docker ps` output.
- `docker inspect` output for each running container.
- `docker network inspect` output for each compose network.
- `ss -tulpn` output.
- `ufw status verbose` output.
- `sshd_config` and summary of local users with shell access.
- Grafana auth configuration and plugin list.
- OS package update status.

## Known High-Priority Review Topics

The following items should always receive explicit attention until their risk
is reduced or eliminated:

- Mutable tracker image tag in Docker Compose.
- Public Grafana exposure.
- Public tracker API exposure.
- Trust in proxy headers for client IP attribution.
- Docker-published ports bypassing the host firewall model.
- Secret exposure through environment variables, mounted files, logs, or backup
  archives.

## Output of Each Review

Each review cycle should produce a review folder containing:

- `README.md` as the final summary report.
- `progress.md` as the live work tracker.
- `findings.md` as the confirmed findings register.
- One detailed note per reviewed service or attack surface.

The final summary report should contain:

- Review date.
- Reviewer.
- Deployment version summary.
- Scope covered in this cycle.
- Sources of evidence reviewed.
- Confirmed findings.
- Rejected hypotheses.
- Follow-up actions.
- Open questions requiring more information or source access.

The detailed surface files should contain:

- Scope of the surface under review.
- Hypotheses tested.
- Evidence reviewed.
- Checks performed.
- Findings or non-findings.
- Open questions and next actions.

Store review reports under `docs/security/reviews/` and reference this plan from
each review-cycle `README.md`.
