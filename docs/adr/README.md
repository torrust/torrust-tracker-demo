# Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records (ADRs) for the Torrust Tracker Demo project.

## What are ADRs?

Architecture Decision Records document important architectural decisions made during the project
lifecycle. They provide context, rationale, and consequences of decisions that affect the
system's structure, behavior, or development process.

## ADR Guidelines

### When to Create an ADR

Create an ADR for decisions that:

- **Affect multiple system components** or development workflows
- **Have significant long-term implications** for the project
- **Involve trade-offs** between different approaches
- **Need to be communicated** to the team and future contributors
- **May be questioned** or reversed in the future

### When NOT to Create an ADR

Avoid creating ADRs for:

- **Implementation details** specific to a single component
- **Temporary workarounds** or quick fixes
- **Obvious technical choices** with no reasonable alternatives
- **Operational procedures** (use operational documentation instead)

### ADR Structure

Each ADR should follow this template:

```markdown
# ADR-XXX: [Decision Title]

## Status

[Proposed | Accepted | Deprecated | Superseded]

## Context

[Describe the problem, constraints, and forces at play]

## Decision

[State the decision clearly and concisely]

## Alternatives Considered

[List other options that were considered and why they were rejected]

## Rationale

[Explain why this decision was made]

## Consequences

### Positive

- [List benefits and positive outcomes]

### Negative

- [List costs, risks, and negative impacts]

### Neutral

- [List neutral consequences and trade-offs]

## Implementation Details

[Optional: Include relevant implementation specifics]

## Monitoring

[How will we measure if this decision is working]

## Related Decisions

[Link to related ADRs]

## References

[Links to supporting documentation, discussions, etc.]
```

## Lessons Learned

### Keep ADRs Focused

**❌ Bad Practice**: Mixing multiple unrelated decisions in a single ADR

**✅ Good Practice**: Each ADR should address a single architectural decision

**Example**: ADR-005 originally mixed sudo cache management with SSH host key verification.
These are separate infrastructure concerns and should be documented separately:

- Sudo cache management → ADR (architectural decision)
- SSH host key verification → Operational documentation (troubleshooting guide)

### Separate Concerns by Type

| Documentation Type       | Purpose                        | Location               | Example             |
| ------------------------ | ------------------------------ | ---------------------- | ------------------- |
| **ADR**                  | Record architectural decisions | `docs/adr/`            | Database choice     |
| **Operational Docs**     | Solve immediate problems       | `docs/infrastructure/` | SSH troubleshooting |
| **Implementation Plans** | Detail feature implementation  | `docs/issues/`         | Development plans   |
| **User Guides**          | End-to-end workflows           | `docs/guides/`         | Testing procedures  |

### Scope and Audience

- **ADRs**: For contributors understanding design decisions
- **Operational Docs**: For users encountering specific problems
- **Guides**: For users following complete procedures

## Current ADRs

### 📋 Active ADRs

- [ADR-001: Makefile Location](001-makefile-location.md) - Decision to keep
  Makefile at repository root level
- [ADR-002: Docker for All Services](002-docker-for-all-services.md) - Decision
  to use Docker for all services including UDP tracker
- [ADR-003: Use MySQL Over MariaDB](003-use-mysql-over-mariadb.md) - Decision
  to use MySQL instead of MariaDB for database backend
- [ADR-004: Configuration Approach Files vs Environment Variables]
  (004-configuration-approach-files-vs-environment-variables.md) -
  Configuration approach decision for application settings
- [ADR-005: Sudo Cache Management for Infrastructure Operations]
  (005-sudo-cache-management-for-infrastructure-operations.md) -
  Proactive sudo cache management for better UX during testing
- [ADR-006: SSL Certificate Generation Strategy]
  (006-ssl-certificate-generation-strategy.md) -
  Generate certificates per deployment vs reusing certificates

### 📊 ADR Statistics

- **Total ADRs**: 6
- **Status**: All Accepted
- **Coverage**: Infrastructure (3), Application (2), Development Workflow (1)

## Contributing

### Creating a New ADR

1. **Identify the decision** that needs documentation
2. **Check existing ADRs** to avoid duplication
3. **Determine ADR number** (next sequential number)
4. **Use the template** provided above
5. **Focus on a single decision** - avoid mixing multiple concerns
6. **Get team review** before marking as "Accepted"
7. **Update this README** to include the new ADR in the list

### Updating Existing ADRs

- **Status changes**: Update status from "Proposed" to "Accepted"
- **Superseding**: When replacing an ADR, update the old one's status to "Superseded"
- **References**: Add references when decisions are implemented or referenced

### Best Practices

1. **Write for the future**: Assume readers don't have current context
2. **Include alternatives**: Show what options were considered
3. **Be honest about trade-offs**: Document both benefits and costs
4. **Keep it concise**: Focus on the decision, not implementation details
5. **Link related decisions**: Cross-reference related ADRs
6. **Update when necessary**: ADRs can evolve as understanding improves

## Templates and Examples

- **Template**: Use the structure outlined in "ADR Structure" above
- **Good Examples**: ADR-001 (clear trade-offs), ADR-003 (thorough alternatives analysis)
- **Lessons Learned**: See ADR-005 for an example of how to keep focused scope

## Related Documentation

- [Main Documentation Guide](../README.md) - Overall documentation structure
- [Infrastructure Documentation](../../infrastructure/docs/) - Infrastructure-specific docs
- [Application Documentation](../../application/docs/) - Application-specific docs
- [Guides](../guides/) - End-to-end procedures and workflows
