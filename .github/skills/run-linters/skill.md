---
name: run-linters
description: Run linters for the torrust-tracker-demo repository. Covers running all linters at once or a single linter. Triggers on "run linters", "lint", "check lint", "run lint", "linting", "spell check", "check markdown", "check yaml".
metadata:
  author: torrust
  version: "1.0"
---

# Running Linters

## Run All Linters

```sh
./scripts/lint.sh
```

Runs markdown, YAML, spell check, and shell script linters in sequence.
Stops on first failure.

## Run a Single Linter

```sh
linter markdown   # Markdown (uses .markdownlint.json)
linter yaml       # YAML (uses .yamllint-ci.yml)
linter cspell     # Spell check (uses cspell.json)
linter shellcheck # Shell scripts
```

## Fix Common Issues

- **Spell check false positive**: add the word to `project-words.txt` (one word per line).
- **Markdown error**: check the rule ID in the output against `.markdownlint.json`.
- **YAML error**: check `.yamllint-ci.yml` for the relevant rule.

## Prerequisites

Install once:

```sh
cargo install torrust-linting --locked
```

Also requires `yamllint` and `shellcheck` on `$PATH`.
