# AGENTS.md

## Project Overview

This repository contains the configuration needed to run the live
[Torrust Tracker](https://github.com/torrust/torrust-tracker) demo. It is
tracker-only; the index demo lives in a separate repository.

**Live demo endpoints:**

- HTTP: <https://http1.torrust-tracker-demo.com:443/announce>
- UDP: `udp://udp1.torrust-tracker-demo.com:6969/announce`

For a more complete reference of the combined Index + Tracker setup, see the
original [torrust/torrust-demo](https://github.com/torrust/torrust-demo) repo.

## Repository Structure

### `server/`

Contains **only files that are actually deployed on the live server**, mirroring
their exact paths (e.g. `server/etc/...`, `server/opt/...`). These are static
configuration files managed in version control and deployed to the server.

Do **not** place generated artifacts, dashboards, or documentation here.
Files that live in application databases (e.g. Grafana dashboards stored in
Grafana's own database) must **not** go in `server/` even if they relate to
a server-side service.

### `docs/`

Documentation only: architecture decision records, issue notes, post-mortems,
and other reference material. Do **not** place backup exports here.

### `backups/`

Versioned backup exports of data managed by server-side applications
(i.e. data that lives in application databases, not in config files).
Examples: Grafana dashboards exported from the Grafana UI.
Organized by application: `backups/grafana/dashboards/`, etc.

These backups are **not deployed to the server** — they exist solely for
recovery and sharing purposes.

## Code Conventions

### Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` — new features or configuration
- `fix:` — bug fixes
- `docs:` — documentation-only changes
- `chore:` — maintenance, dependency updates
- `refactor:` — restructuring without behaviour change

Format:

```text
<type>[optional scope]: <short description>

[optional body]

[optional footer(s)]
```

### Markdown

- All Markdown files must pass the markdown linter.
- Preferred command: `./scripts/lint.sh`
- Direct command: `npx markdownlint-cli2 "**/*.md"`

### Spell Checking

- All files must pass CSpell spell checking.
- Preferred command: `./scripts/lint.sh`
- Direct command: `npx cspell --no-progress`
- Add project-specific terms to `project-words.txt`.

### Linting Summary

- The canonical lint entry point is `./scripts/lint.sh`.
- Install the wrapper with `cargo install torrust-linting --locked`.
- Install `yamllint` and `shellcheck` on `$PATH` before running the script.
- If npm install steps fail with `EACCES`, use a user-local npm prefix.
- See [docs/linting.md](docs/linting.md) for installation and troubleshooting.

## Pull Request Guidelines

- Title must follow the Conventional Commits format: `<type>[scope]: <description>`
- Run `./scripts/lint.sh` before opening a PR.
- Reference related issues in the PR body using `Refs: #<issue>`.
