---
name: commit
description: Guide for committing changes in the torrust-tracker-demo repository. Covers running all linters locally before committing to ensure CI passes. Triggers on "commit", "how to commit", "before committing", "pre-commit checks", "run linters", "check before commit".
metadata:
  author: torrust
  version: "1.0"
---

# Committing Changes

Always run the linters locally before committing to avoid CI failures.

## Commit Scope Separation

**Critical rule**: Never mix skill/workflow documentation changes (`.github/skills/`, `.github/agents/`, AGENTS.md) with implementation changes in a single commit.

When a change affects both documentation/skills and implementation:

1. **First commit**: Update the skill/documentation files only (type: `docs`)
2. **Second commit**: Implement the feature or fix (type: `feat`, `fix`, etc.)

This keeps changes logically separated and makes the commit history easier to review.

## Prerequisites

Install the linter binary once:

```sh
cargo install torrust-linting --locked
```

Also requires: Node.js ≥ 20, `yamllint`, and `shellcheck` available on `$PATH`.

## Run Linters Before Committing

```sh
./scripts/pre-commit.sh
```

This is the pre-commit entry point and currently delegates to `./scripts/lint.sh`.
It runs markdown, YAML, spell check, and shell script linters in sequence and
stops on first failure.

The repository also provides a tracked Git hook at `.githooks/pre-commit`.
Enable it locally with:

```sh
git config core.hooksPath .githooks
```

Fix all reported issues before committing. Add any new project-specific words to
`project-words.txt` (one word per line).

## Commit Message Format

All commits must be GPG-signed.

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```text
<type>[optional scope]: <short description>

[optional body]
```

Types: `feat`, `fix`, `docs`, `chore`, `refactor`.

When updating documentation for skills or workflows, use `docs` type. Implementation changes use their appropriate type (`feat`, `fix`, etc.) in a separate commit.
