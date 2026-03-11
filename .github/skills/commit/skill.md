---
name: commit
description: Guide for committing changes in the torrust-tracker-demo repository. Covers running all linters locally before committing to ensure CI passes. Triggers on "commit", "how to commit", "before committing", "pre-commit checks", "run linters", "check before commit".
metadata:
  author: torrust
  version: "1.0"
---

# Committing Changes

Always run the linters locally before committing to avoid CI failures.

## Prerequisites

Install the linter binary once:

```sh
cargo install torrust-linting --locked
```

Also requires: Node.js ≥ 20, `yamllint`, and `shellcheck` available on `$PATH`.

## Run Linters Before Committing

```sh
./scripts/lint.sh
```

This runs markdown, YAML, spell check, and shell script linters in sequence.
Stops on first failure.

Fix all reported issues before committing. Add any new project-specific words to
`project-words.txt` (one word per line).

## Commit Message Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```text
<type>[optional scope]: <short description>

[optional body]
```

Types: `feat`, `fix`, `docs`, `chore`, `refactor`.
