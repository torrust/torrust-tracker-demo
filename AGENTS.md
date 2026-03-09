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
- Run: `npx markdownlint-cli2 "**/*.md"`

### Spell Checking

- All files must pass CSpell spell checking.
- Run: `npx cspell --no-progress`
- Add project-specific terms to `project-words.txt`.

## Pull Request Guidelines

- Title must follow the Conventional Commits format: `<type>[scope]: <description>`
- Run the markdown linter and spell checker before opening a PR.
- Reference related issues in the PR body using `Refs: #<issue>`.
