#!/bin/bash

# Linting script for Torrust Tracker Demo
# Runs yamllint, ShellCheck, and markdownlint on all relevant files

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
    "SUCCESS")
        echo -e "${GREEN}[SUCCESS]${NC} $message"
        ;;
    "ERROR")
        echo -e "${RED}[ERROR]${NC} $message"
        ;;
    "WARNING")
        echo -e "${YELLOW}[WARNING]${NC} $message"
        ;;
    "INFO")
        echo -e "${YELLOW}[INFO]${NC} $message"
        ;;
    esac
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to run yamllint
run_yamllint() {
    print_status "INFO" "Running yamllint on YAML files..."

    if ! command_exists yamllint; then
        print_status "ERROR" "yamllint not found. Install with: sudo apt-get install yamllint"
        return 1
    fi

    # Use yamllint config if it exists
    if [ -f ".yamllint-ci.yml" ]; then
        if yamllint -c .yamllint-ci.yml .; then
            print_status "SUCCESS" "yamllint passed"
            return 0
        else
            print_status "ERROR" "yamllint failed"
            return 1
        fi
    else
        if yamllint .; then
            print_status "SUCCESS" "yamllint passed"
            return 0
        else
            print_status "ERROR" "yamllint failed"
            return 1
        fi
    fi
}

# Function to run ShellCheck
run_shellcheck() {
    print_status "INFO" "Running ShellCheck on shell scripts..."

    if ! command_exists shellcheck; then
        print_status "ERROR" "shellcheck not found. Install with: sudo apt-get install shellcheck"
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
        print_status "WARNING" "No shell scripts found"
        return 0
    fi

    if shellcheck "${shell_files[@]}"; then
        print_status "SUCCESS" "shellcheck passed"
        return 0
    else
        print_status "ERROR" "shellcheck failed"
        return 1
    fi
}

# Function to run markdownlint
run_markdownlint() {
    print_status "INFO" "Running markdownlint on Markdown files..."

    if ! command_exists markdownlint; then
        print_status "ERROR" "markdownlint not found. Install with: npm install -g markdownlint-cli"
        return 1
    fi

    # Use markdownlint with glob pattern to find markdown files
    # markdownlint can handle glob patterns and will exclude .git directories by default
    if markdownlint "**/*.md"; then
        print_status "SUCCESS" "markdownlint passed"
        return 0
    else
        print_status "ERROR" "markdownlint failed"
        return 1
    fi
}

# Main function
main() {
    print_status "INFO" "Starting linting process..."

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
        print_status "SUCCESS" "All linting checks passed!"
    else
        print_status "ERROR" "Some linting checks failed!"
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
