---
name: run-linters
description: Run linters for the torrust-tracker-demo repository. Covers running the canonical lint script, installing the lint wrapper and prerequisites, and troubleshooting markdown, YAML, spelling, shellcheck, npm permission, and Node/cspell compatibility issues. Triggers on "run linters", "lint", "check lint", "run lint", "linting", "spell check", "check markdown", "check yaml", "lint script", "install linter", "lint troubleshooting".
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

This is the canonical repository lint command.

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
- **npm EACCES while installing tools**: use a user-local npm prefix:

  ```sh
  export NPM_CONFIG_PREFIX="$HOME/.local"
  export PATH="$HOME/.local/bin:$PATH"
  ```

- **Unsupported NodeJS version from cspell**: either upgrade Node.js or install a
  compatible cspell version explicitly, for example:

  ```sh
  npm install -g cspell@8.17.5
  ```

- **`yamllint` or `shellcheck` missing**: install them before rerunning the script.

## Prerequisites

Install once:

```sh
cargo install torrust-linting --locked
```

Also requires `yamllint` and `shellcheck` on `$PATH`.

Recommended install on Ubuntu:

```sh
sudo apt-get update
sudo apt-get install -y yamllint shellcheck
```

If you want reliable non-root npm installs for the Node-based lint tools:

```sh
export NPM_CONFIG_PREFIX="$HOME/.local"
export PATH="$HOME/.local/bin:$PATH"
npm install -g markdownlint-cli cspell@8.17.5
```

## Reference

For full repository-specific guidance, see [docs/linting.md](../../docs/linting.md).
