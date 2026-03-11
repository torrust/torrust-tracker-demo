#!/usr/bin/env bash
#
# Run all linters for this repository.
#
# Usage: ./scripts/lint.sh
#
# Requires: cargo install torrust-linting --locked
#
# TODO: Replace with a single call once torrust-linting supports multiple
#       linter arguments, e.g. `linter markdown yaml cspell shellcheck`.
#       See: https://github.com/torrust/torrust-linting (open a feature request)

set -euo pipefail

linter markdown
linter yaml
linter cspell
linter shellcheck
