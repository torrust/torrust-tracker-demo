# Bug Documentation Archive

This directory contains comprehensive documentation for bugs that have been
investigated and resolved in the Torrust Tracker Demo infrastructure project.

## Purpose

The purpose of this archive is to:

- **Preserve Investigation Process**: Document the complete debugging methodology
  and thought process used to identify and resolve infrastructure issues
- **Enable Knowledge Transfer**: Provide detailed reference material for future
  contributors who encounter similar problems
- **Improve Debugging Skills**: Demonstrate systematic approaches to
  infrastructure troubleshooting
- **Prevent Regression**: Maintain test cases and validation procedures to
  ensure fixes remain effective

## Structure

Each bug is documented in its own numbered directory following this convention:

```text
infrastructure/docs/bugs/
├── README.md                           # This file
├── 001-ssh-authentication-failure/     # First documented bug
│   ├── README.md                       # Bug overview and summary
│   ├── SSH_BUG_ANALYSIS.md            # Initial analysis and hypothesis
│   ├── SSH_BUG_SUMMARY.md             # Complete investigation summary
│   ├── test-configs/                  # Test configurations used
│   │   ├── user-data-test-1.1.yaml.tpl
│   │   ├── user-data-test-2.1.yaml.tpl
│   │   └── ...
│   └── validation/                    # Final validation artifacts
└── 002-next-bug/                      # Future bug documentation
    └── ...
```

## Documentation Standards

When documenting a new bug, create a new numbered directory and include:

### Required Files

1. **README.md** - Bug overview with:

   - Problem description
   - Root cause summary
   - Fix applied
   - Validation results
   - References to related files

2. **Analysis Documentation** - Detailed investigation process:

   - Initial symptoms and error messages
   - Hypothesis formation and testing
   - Step-by-step debugging methodology
   - Dead ends and lessons learned

3. **Test Artifacts** - Evidence and test cases:
   - Configuration files used during testing
   - Test scripts and validation procedures
   - Before/after comparisons
   - Reproducible test cases

### Naming Conventions

- **Directories**: Use format `NNN-short-description` (e.g., `001-ssh-authentication-failure`)
- **Files**: Use descriptive names with consistent prefixes:
  - `ANALYSIS_` for investigation documentation
  - `SUMMARY_` for comprehensive overviews
  - `test-` for test configurations
  - `validation-` for final verification artifacts

### Content Guidelines

- **Be Comprehensive**: Include all relevant information, even failed attempts
- **Document Process**: Explain the reasoning behind each debugging step
- **Include Context**: Provide enough background for newcomers to understand
- **Show Evidence**: Include relevant log outputs, error messages, and test results
- **Explain the Fix**: Detail exactly what was changed and why it works
- **Provide Validation**: Include steps to verify the fix and prevent regression

## Usage Examples

### For Contributors Encountering Similar Issues

1. **Search by Symptoms**: Look through bug directories for similar error messages
   or behavior patterns
2. **Review Methodology**: Study the debugging approach used in similar cases
3. **Adapt Test Procedures**: Use existing test configurations as templates
4. **Apply Lessons Learned**: Benefit from documented pitfalls and solutions

### For Maintainers

1. **Validate Fixes**: Use documented test cases to ensure fixes remain effective
2. **Onboard New Contributors**: Point to relevant bug documentation for learning
3. **Improve Infrastructure**: Identify patterns in bugs to prevent future issues
4. **Review Process**: Use documented methodologies to improve debugging practices

## Quality Standards

All bug documentation should:

- ✅ Be reproducible by following the documented steps
- ✅ Include complete context and background information
- ✅ Demonstrate systematic debugging methodology
- ✅ Provide clear validation procedures
- ✅ Explain both what worked and what didn't work
- ✅ Include timing information and performance impacts
- ✅ Reference related infrastructure components

## Contributing

When adding new bug documentation:

1. **Create New Directory**: Use next available number with descriptive name
2. **Follow Standards**: Use the structure and naming conventions above
3. **Include All Artifacts**: Don't leave out "failed" attempts or test files
4. **Write for Others**: Assume the reader is unfamiliar with the specific issue
5. **Validate Documentation**: Ensure someone else can follow your steps
6. **Update This README**: Add any new patterns or insights to these guidelines

## Index of Documented Bugs

| Bug ID | Description                | Status      | Impact                   | Date Resolved |
| ------ | -------------------------- | ----------- | ------------------------ | ------------- |
| 001    | SSH Authentication Failure | ✅ Resolved | High - Blocked VM access | 2025-07-04    |

---

_This archive serves as a knowledge base for infrastructure debugging and should
be maintained as a valuable resource for the Torrust community._
