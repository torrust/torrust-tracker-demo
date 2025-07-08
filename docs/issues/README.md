# Issues Documentation

This directory contains detailed implementation plans and documentation for GitHub issues
related to the Torrust Tracker Demo project.

## Structure

Each implementation plan follows a consistent structure:

- **Overview**: Clear objective and context
- **Implementation Steps**: Detailed step-by-step implementation guide
- **Testing Strategy**: Comprehensive testing approach
- **Implementation Order**: Phased approach for safe deployment
- **Risk Assessment**: Potential issues and mitigation strategies
- **Success Criteria**: Clear validation requirements

## Current Issues

- [Phase 1: MySQL Migration Implementation Plan](12-use-mysql-instead-of-sqlite-by-default.md)
  - Database migration from SQLite to MySQL
  - Part of the Hetzner migration initiative

## Contributing

When creating new issue implementation plans:

1. Follow the established naming convention: `{issue-number}-{short-description}.md`
2. Use the structure from existing plans as a template
3. Ensure all markdown passes linting with `./scripts/lint.sh --markdown`
4. Link to parent issues and related documentation
5. Include comprehensive testing strategies
6. Document all file changes and configuration updates

## Related Documentation

- [Migration Plans](../plans/) - High-level migration strategies
- [Architecture Decision Records](../adr/) - Design decisions and rationale
- [Infrastructure Documentation](../../infrastructure/docs/) - Infrastructure setup guides
- [Application Documentation](../../application/docs/) - Application deployment guides
