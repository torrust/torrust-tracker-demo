# Linting

This document describes how linting works in this repository, how to install
the required tools, and how to troubleshoot common failures.

## Canonical Command

Run all linters with:

```sh
./scripts/lint.sh
```

This is the preferred command for local validation before committing or opening
a pull request.

## Pre-commit Script

The repository also provides a pre-commit wrapper:

```sh
./scripts/pre-commit.sh
```

For now this script delegates directly to `./scripts/lint.sh`.

## Git Pre-commit Hook

A tracked Git hook is included at `.githooks/pre-commit` and runs
`./scripts/pre-commit.sh` automatically before `git commit`.

Enable the tracked hooks once per local clone:

```sh
git config core.hooksPath .githooks
```

After that, `git commit` will execute the repository's pre-commit checks
automatically.

The script runs these linters in order:

```sh
linter markdown
linter yaml
linter cspell
linter shellcheck
```

It stops on the first failure.

## What the Script Checks

- Markdown using `.markdownlint.json`
- YAML using `.yamllint-ci.yml`
- Spelling using `cspell.json` and `project-words.txt`
- Shell scripts using ShellCheck

## Installation

### Required tools

Install the Rust wrapper used by the script:

```sh
cargo install torrust-linting --locked
```

Install system tools:

```sh
sudo apt-get update
sudo apt-get install -y yamllint shellcheck
```

### Node-based tools

The `linter` command may try to install Node-based tools automatically, but in
practice it is more reliable to install them explicitly in a user-writable npm
prefix.

Example setup:

```sh
export NPM_CONFIG_PREFIX="$HOME/.local"
export PATH="$HOME/.local/bin:$PATH"
npm install -g markdownlint-cli cspell@8.17.5
```

If you want those settings permanently, add the two `export` lines to your
shell profile.

## Recommended Local Workflow

Run this before committing:

```sh
export NPM_CONFIG_PREFIX="$HOME/.local"
export PATH="$HOME/.local/bin:$PATH"
./scripts/pre-commit.sh
```

If the script passes, the repository is clean for Markdown, YAML, spelling, and
shell script linting.

## Running a Single Linter

You can run individual linters through the same wrapper:

```sh
linter markdown
linter yaml
linter cspell
linter shellcheck
```

This is useful when fixing one class of failures at a time.

## Troubleshooting

### `linter: command not found`

The Rust wrapper is not installed.

Fix:

```sh
cargo install torrust-linting --locked
```

### npm `EACCES` while installing markdownlint or cspell

The wrapper may try to install npm packages globally under `/usr/local`, which
fails for non-root users.

Fix: use a user-local npm prefix.

```sh
export NPM_CONFIG_PREFIX="$HOME/.local"
export PATH="$HOME/.local/bin:$PATH"
```

Then rerun `./scripts/lint.sh`.

### `Unsupported NodeJS version` from cspell

At the time this document was written, the latest `cspell` release required
Node.js `>=22.18.0`, while this repository workflow was being run with Node 20.

Fix options:

- Upgrade Node.js to a compatible version.
- Or install a Node 20-compatible cspell version explicitly:

```sh
npm install -g cspell@8.17.5
```

### `yamllint` triggers a sudo prompt during `./scripts/lint.sh`

The wrapper may try to install `yamllint` itself.

Preferred fix: install it manually ahead of time.

```sh
sudo apt-get install -y yamllint
```

### `shellcheck` is missing

Install it explicitly:

```sh
sudo apt-get install -y shellcheck
```

### Spell checker reports a valid technical term

Add the term to `project-words.txt`, one word per line, then rerun the linter.

Examples already added during recent documentation work include:

- `Mailgun`
- `tulpn`

### Markdown lint fails on indentation or tabs

Markdown linting is strict about formatting details such as tab characters.
Use spaces for wrapped list items and paragraph continuations.

## Files Involved

- [scripts/lint.sh](../scripts/lint.sh)
- [scripts/pre-commit.sh](../scripts/pre-commit.sh)
- [.githooks/pre-commit](../.githooks/pre-commit)
- [project-words.txt](../project-words.txt)
- [cspell.json](../cspell.json)
- [.markdownlint.json](../.markdownlint.json)
- [.yamllint-ci.yml](../.yamllint-ci.yml)

## Notes

- `./scripts/lint.sh` is the canonical repository command.
- `./scripts/pre-commit.sh` is the hook-friendly entry point for commit-time checks.
- If you document new product names, services, or command tokens, update
  `project-words.txt` as part of the same change.
- Run the full script again after fixing targeted issues to ensure the complete
  repository still passes.
