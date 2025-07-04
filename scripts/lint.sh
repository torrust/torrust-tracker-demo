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

    # Find all YAML files, excluding .git directory and .terraform directories
    yaml_files=$(find . -name "*.yml" -o -name "*.yaml" | grep -v ".git" | grep -v ".terraform" | sort)

    if [ -z "$yaml_files" ]; then
        print_status "WARNING" "No YAML files found"
        return 0
    fi

    # Use yamllint config if it exists
    yamllint_args=()
    if [ -f ".yamllint-ci.yml" ]; then
        yamllint_args=("-c" ".yamllint-ci.yml")
    fi

    local failed=0
    for file in $yaml_files; do
        # Skip template files that need variable substitution
        if [[ "$file" == *.tpl ]]; then
            # For template files, create a temporary file with dummy values
            if [[ "$file" == *"user-data"* ]]; then
                temp_file="/tmp/$(basename "$file" .tpl)"
                sed "s/\\\${ssh_public_key}/ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/" "$file" >"$temp_file"
                if [ ${#yamllint_args[@]} -gt 0 ]; then
                    if yamllint "${yamllint_args[@]}" "$temp_file"; then
                        print_status "SUCCESS" "yamllint passed for $file"
                    else
                        print_status "ERROR" "yamllint failed for $file"
                        failed=1
                    fi
                else
                    if yamllint "$temp_file"; then
                        print_status "SUCCESS" "yamllint passed for $file"
                    else
                        print_status "ERROR" "yamllint failed for $file"
                        failed=1
                    fi
                fi
                rm -f "$temp_file"
            else
                print_status "WARNING" "Skipping template file $file (needs variable substitution)"
            fi
        else
            if [ ${#yamllint_args[@]} -gt 0 ]; then
                if yamllint "${yamllint_args[@]}" "$file"; then
                    print_status "SUCCESS" "yamllint passed for $file"
                else
                    print_status "ERROR" "yamllint failed for $file"
                    failed=1
                fi
            else
                if yamllint "$file"; then
                    print_status "SUCCESS" "yamllint passed for $file"
                else
                    print_status "ERROR" "yamllint failed for $file"
                    failed=1
                fi
            fi
        fi
    done

    return $failed
}

# Function to run ShellCheck
run_shellcheck() {
    print_status "INFO" "Running ShellCheck on shell scripts..."

    if ! command_exists shellcheck; then
        print_status "ERROR" "shellcheck not found. Install with: sudo apt-get install shellcheck"
        return 1
    fi

    # Find all shell scripts, excluding .git directory and .terraform directories
    shell_files=$(find . -name "*.sh" -o -name "*.bash" | grep -v ".git" | grep -v ".terraform" | sort)

    if [ -z "$shell_files" ]; then
        print_status "WARNING" "No shell scripts found"
        return 0
    fi

    local failed=0
    for file in $shell_files; do
        if shellcheck "$file"; then
            print_status "SUCCESS" "shellcheck passed for $file"
        else
            print_status "ERROR" "shellcheck failed for $file"
            failed=1
        fi
    done

    return $failed
}

# Function to run markdownlint
run_markdownlint() {
    print_status "INFO" "Running markdownlint on Markdown files..."

    if ! command_exists markdownlint; then
        print_status "ERROR" "markdownlint not found. Install with: npm install -g markdownlint-cli"
        return 1
    fi

    # Find all markdown files, excluding .git directory and .terraform directories
    markdown_files=$(find . -name "*.md" | grep -v ".git" | grep -v ".terraform" | sort)

    if [ -z "$markdown_files" ]; then
        print_status "WARNING" "No Markdown files found"
        return 0
    fi

    local failed=0
    for file in $markdown_files; do
        if markdownlint "$file"; then
            print_status "SUCCESS" "markdownlint passed for $file"
        else
            print_status "ERROR" "markdownlint failed for $file"
            failed=1
        fi
    done

    return $failed
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
