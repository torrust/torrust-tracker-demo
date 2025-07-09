### **ADR-005: Proposal for a Test-Driven Implementation and Structure**

*   **Status:** Proposed for Review
*   **Date:** 2025-07-09
*   **Proposer:** Cameron
*   **Reviewers:** [List of project maintainers/core contributors]
*   **Depends On:** [ADR-004: Proposal to Adopt a Modernized Automation Toolchain](./004-adopt-modern-toolchain.md)
*   **Supersedes:** [ADR-001: Keep Makefile at Repository Root Level](./001-makefile-location.md)

#### **1. Context and Problem Statement**

Following the strategic decision in `ADR-004` to adopt a Meson/Perl toolchain, we must now define a concrete implementation plan. A simple one-to-one replacement of scripts would fail to capitalize on the full benefits of the new toolchain and could lead to a disorganized codebase.

This proposal addresses the "how" and "where" of the migration. It recommends a specific code structure and implementation methodology designed to maximize the reliability, maintainability, and testability of our new automation system. It also proposes an atomic migration strategy to ensure a clean and unambiguous transition.

#### **2. Proposed Change**

It is proposed that the new toolchain be implemented using the following structured approach:

1.  **Centralize Automation Logic:** A new top-level `automation/` directory will be created. This directory will become the single, authoritative home for all imperative automation code (Perl scripts and modules) and their corresponding tests. This cleanly separates the project's declarative artifacts (in `infrastructure/` and `application/`) from the imperative code that acts upon them.

2.  **Adopt a Test-Driven Standard:** All new Perl logic will be accompanied by a formal test suite located in `automation/t/`. The project's primary test command, `meson test`, will validate the correctness of the automation logic itself, enabling unit tests that can run without requiring a live, deployed environment.

3.  **Execute an Atomic "Flag Day" Migration:** The transition from the legacy `Makefile`/`sh` system will be performed in a single, comprehensive changeset. This "clean break" approach avoids a confusing transitional period with two competing systems. The `Makefile` and old scripts will be removed entirely, and the Meson/Perl system will be introduced as the sole, official standard.

#### **3. Proposed Repository Structure**

The following structure is recommended to support this change. It is designed for clarity and a strong separation of concerns.

```text
torrust-tracker-demo/
├── application/                # Application deployment artifacts (e.g., compose.yaml)
├── infrastructure/             # Infrastructure-as-Code declarations (Terraform, cloud-init)
├── docs/                       # Project documentation
├── automation/                 # NEW: All automation logic and its tests
│   ├── lib/                    # Reusable Perl modules (e.g., Torrust::Demo::*)
│   ├── t/                      # Test suite for automation logic (*.t files)
│   └── meson.build             # Defines all automation targets
├── .gitignore
└── meson.build                 # ROOT INTERFACE: Orchestrates all tasks
```

#### **4. Rationale for Proposed Change**

This structured and test-driven approach is recommended because it allows us to build a truly professional-grade automation toolchain:

*   **Reliability Through Testing:** Implementing a test suite for our automation code is a transformative step. It allows us to verify complex logic (e.g., parsing configuration, generating template files) in isolation, leading to fewer bugs and faster, more confident development of our tooling.
*   **Improved Maintainability:** The proposed structure creates a clear "home" for all automation code. This makes the system easier for new contributors to understand and easier for maintainers to extend. Separating logic into reusable Perl modules (`.pm` files) will reduce code duplication and improve overall quality.
*   **Clarity of Implementation:** An atomic migration, while disruptive, provides immediate and total clarity. There is no ambiguity about which system to use or how tasks should be run. All documentation and workflows can be updated to reflect a single, consistent standard from day one.

#### **5. Scope and Relationship to Other Proposals**

This document's scope is strictly limited to the **implementation strategy, repository structure, and testing philosophy** of the new toolchain. It defines the "how" and "where" of the migration.

It explicitly defers the definition of specific coding conventions to the next document:
*   **Coding & Quality Standards (`ADR-006`):** Will define the specific rules for the Perl code itself, such as mandatory pragmas (`use strict;`), security hardening (`-T`), and static analysis (`Perl::Critic`) policies.

#### **6. Acknowledged Trade-offs**

*   **One-Time Contributor Effort:** The primary trade-off is that an atomic migration requires every contributor to learn and adapt to the new `meson`-based workflow simultaneously. The legacy `make` commands they are familiar with will cease to exist.
*   **Mitigation Strategy:** This cost is deemed acceptable for the long-term benefit of a single, superior system. The migration will be supported by a comprehensive update to all documentation (`README.md`, contributing guides) and clear project-level communication to prepare contributors for the change.

#### **7. Next Steps**

If this proposal for the implementation strategy is accepted, the maintainers will proceed with a final review of `ADR-006` to establish the formal coding standards before beginning the migration work outlined herein.
