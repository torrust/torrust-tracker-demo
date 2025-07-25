#!/bin/bash

# Linting script for Torrust Tracker Demo
# Runs yamllint, ShellCheck, and markdownlint on all relevant files

set -euo pipefail

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared shell utilities
# shellcheck source=./shell-utils.sh
source "${SCRIPT_DIR}/shell-utils.sh"

# Function to run yamllint
run_yamllint() {
    log_info "Running yamllint on YAML files..."

    if ! command_exists yamllint; then
        log_error "yamllint not found. Install with: sudo apt-get install yamllint"
        return 1
    fi

    # Use yamllint config if it exists
    if [ -f ".yamllint-ci.yml" ]; then
        if yamllint -c .yamllint-ci.yml .; then
            log_success "yamllint passed"
            return 0
        else
            log_error "yamllint failed"
            return 1
        fi
    else
        if yamllint .; then
            log_success "yamllint passed"
            return 0
        else
            log_error "yamllint failed"
            return 1
        fi
    fi
}

# Function to run ShellCheck
run_shellcheck() {
    log_info "Running ShellCheck on shell scripts..."

    if ! command_exists shellcheck; then
        log_error "shellcheck not found. Install with: sudo apt-get install shellcheck"
        return 1
    fi

    # Use glob pattern to find shell scripts, excluding .git and .terraform directories
    # Enable globstar for ** patterns
    shopt -s globstar nullglob

    # Find shell scripts with common extensions
    shell_files=()
    for pattern in "**/*.sh" "**/*.bash"; do
        for file in $pattern; do
            # Skip files in .git and .terraform directories
            if [[ "$file" != *".git"* && "$file" != *".terraform"* ]]; then
                shell_files+=("$file")
            fi
        done
    done

    if [ ${#shell_files[@]} -eq 0 ]; then
        log_warning "No shell scripts found"
        return 0
    fi

    # Add source-path to help shellcheck find sourced files
    if shellcheck --source-path=SCRIPTDIR "${shell_files[@]}"; then
        log_success "shellcheck passed"
        return 0
    else
        log_error "shellcheck failed"
        return 1
    fi
}

# Function to run markdownlint
run_markdownlint() {
    log_info "Running markdownlint on Markdown files..."

    if ! command_exists markdownlint; then
        log_error "markdownlint not found. Install with: npm install -g markdownlint-cli"
        return 1
    fi

    # Use markdownlint with glob pattern to find markdown files
    # markdownlint can handle glob patterns and will exclude .git directories by default
    if markdownlint "**/*.md"; then
        log_success "markdownlint passed"
        return 0
    else
        log_error "markdownlint failed"
        return 1
    fi
}

# Main function
main() {
    log_info "Starting linting process..."

    local exit_code=0

    # Run yamllint
    if ! run_yamllint; then
        exit_code=1
    fi

    echo ""

    # Run ShellCheck
    if ! run_shellcheck; then
        exit_code=1
    fi

    echo ""

    # Run markdownlint
    if ! run_markdownlint; then
        exit_code=1
    fi

    echo ""

    if [ $exit_code -eq 0 ]; then
        log_success "All linting checks passed!"
    else
        log_error "Some linting checks failed!"
    fi

    return $exit_code
}

# Show help
show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Linting script for Torrust Tracker Demo project.
Runs yamllint, ShellCheck, and markdownlint on all relevant files.

Options:
  -h, --help    Show this help message
  --yaml        Run only yamllint
  --shell       Run only ShellCheck
  --markdown    Run only markdownlint

Examples:
  $0              # Run all linters
  $0 --yaml       # Run only yamllint
  $0 --shell      # Run only ShellCheck
  $0 --markdown   # Run only markdownlint

EOF
}

# Parse command line arguments
case "${1:-}" in
-h | --help)
    show_help
    exit 0
    ;;
--yaml)
    run_yamllint
    exit $?
    ;;
--shell)
    run_shellcheck
    exit $?
    ;;
--markdown)
    run_markdownlint
    exit $?
    ;;
"")
    main
    exit $?
    ;;
*)
    echo "Unknown option: $1"
    show_help
    exit 1
    ;;
esac
