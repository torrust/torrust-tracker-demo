docs/README.md# Documentation Structure

This directory contains general cross-cutting documentation for the Torrust
Tracker Demo project.

For specific documentation:

- **Application documentation**: [`../application/docs/`](../application/docs/)
- **Infrastructure documentation**: [`../infrastructure/docs/`](../infrastructure/docs/)

## Current Structure

This directory currently contains cross-cutting documentation:

### 📋 [`adr/`](adr/) (Architecture Decision Records)

**Important architectural decisions** that affect the system structure, behavior, or
development process.

📖 **[See ADR README](adr/README.md)** for complete list, guidelines, and best practices.

### 📅 [`plans/`](plans/) (Ongoing Plans and Roadmaps)

**Current Plans:**

- [Hetzner Migration Plan](plans/hetzner-migration-plan.md) - Comprehensive plan
  for migrating from Digital Ocean to Hetzner infrastructure

### 🎯 [`issues/`](issues/) (Implementation Plans)

**Issue Implementation Plans:**

- [Phase 1: MySQL Migration](issues/12-use-mysql-instead-of-sqlite-by-default.md) -
  Detailed implementation plan for database migration from SQLite to MySQL

### 🏗️ [`infrastructure/`](infrastructure/) (Infrastructure Documentation)

**Cross-cutting infrastructure documentation** - For infrastructure-related
documentation that affects the project as a whole or provides reference materials.

**Current Infrastructure Documentation:**

- [SSH Host Key Verification](infrastructure/ssh-host-key-verification.md) -
  Explains and resolves SSH host key verification warnings in VM development

### 📚 [`guides/`](guides/) (User and Developer Guides)

**High-level guides and end-to-end workflows** - For complete procedures
that span multiple components.

**Current Guides:**

- [Integration Testing Guide](guides/integration-testing-guide.md) - Step-by-step
  guide for running integration tests following twelve-factor methodology
- [Quick Start Guide](guides/quick-start.md) - Fast setup guide for getting
  started quickly
- [Smoke Testing Guide](guides/smoke-testing-guide.md) - End-to-end testing
  using official Torrust client tools

### 🔧 [`refactoring/`](refactoring/) (Refactoring Documentation)

**Major refactoring initiatives and changes** - Documentation of significant
codebase changes, architectural improvements, and migration summaries.

**Current Refactoring Documentation:**

- [Integration Test Refactor Summary](refactoring/integration-test-refactor-summary.md) -
  Summary of changes made to align integration testing with 12-factor configuration principles

### Future Categories

The following directories can be created as needed:

### 🔬 `research/` (Research and Investigations)

**Findings, explorations, and technical investigations** - For documenting
research findings, performance analysis, and technical explorations that
span multiple concerns.

### 📊 `benchmarking/` (Performance Testing)

**Performance testing and benchmarks** - For performance analysis,
optimization data, and benchmark results that evaluate the complete system.

### 🧮 `theory/` (Theoretical Documentation)

**Mathematical and theoretical concepts** - For algorithms, protocols,
and theoretical documentation related to BitTorrent and distributed systems.

## Contributing to Documentation

When adding new documentation:

1. **Check if it belongs in application or infrastructure docs first**

   - See [`../application/README.md`](../application/README.md) for application
     documentation guidelines
   - See [`../infrastructure/README.md`](../infrastructure/README.md) for
     infrastructure documentation guidelines

2. **Use this directory for cross-cutting concerns only**

   - Architecture decisions affecting multiple layers
   - Ongoing plans and roadmaps spanning multiple phases
   - Research spanning infrastructure and application
   - Theoretical concepts and protocols
   - Performance analysis of the complete system

3. **Create appropriate directories** only when you have content to add

4. **Use descriptive filenames** that clearly indicate the content

5. **Follow markdown best practices** and maintain consistency

6. **Update README files** when adding new categories or significant content

7. **Cross-reference** related documentation when appropriate

## Documentation Guidelines

- **Cross-cutting vs Specific**: Keep layer-specific docs in their respective directories
- **Plans**: Should document strategic initiatives, migration plans, and multi-phase projects
- **Research**: Should document findings, methodology, and conclusions
- **ADRs**: Should follow standard ADR template format and affect multiple layers
- **Theory**: Should explain concepts clearly with examples when possible
- **Benchmarks**: Should include methodology, environment, and reproducible results
- **Markdown Tables**: For tables exceeding line length limits, see
  [`.markdownlint.md`](../.markdownlint.md) for proper formatting guidelines
