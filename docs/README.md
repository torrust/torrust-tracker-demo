# Documentation Structure

This directory contains general cross-cutting documentation for the Torrust
Tracker Demo project.

For specific documentation:

- **Application documentation**: [`../application/docs/`](../application/docs/)
- **Infrastructure documentation**: [`../infrastructure/docs/`](../infrastructure/docs/)

## Current Structure

This directory currently contains cross-cutting documentation:

### 📋 [`adr/`](adr/) (Architecture Decision Records)

**Current ADRs:**

- [ADR-001: Makefile Location](adr/001-makefile-location.md) - Decision to keep
  Makefile at repository root level
- [ADR-002: Docker for All Services](adr/002-docker-for-all-services.md) - Decision
  to use Docker for all services including UDP tracker
- [ADR-003: Use MySQL Over MariaDB](adr/003-use-mysql-over-mariadb.md) - Decision
  to use MySQL instead of MariaDB for database backend

### 📅 [`plans/`](plans/) (Ongoing Plans and Roadmaps)

**Current Plans:**

- [Hetzner Migration Plan](plans/hetzner-migration-plan.md) - Comprehensive plan
  for migrating from Digital Ocean to Hetzner infrastructure

### 🎯 [`issues/`](issues/) (Implementation Plans)

**Issue Implementation Plans:**

- [Phase 1: MySQL Migration](issues/12-use-mysql-instead-of-sqlite-by-default.md) -
  Detailed implementation plan for database migration from SQLite to MySQL

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
