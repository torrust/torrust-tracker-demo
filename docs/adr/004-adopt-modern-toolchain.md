### **ADR-004: Proposal to Adopt a Modernized Automation Toolchain**

*   **Status:** Proposed for Review
*   **Date:** 2025-07-09
*   **Proposer:** Cameron
*   **Reviewers:** [List of project maintainers/core contributors]

#### **1. Context and Problem Statement**

The project's current automation toolchain, based on `Makefile` and POSIX-compliant shell scripts, has provided a simple and conventional interface for developers. It is pragmatic and effective for its stated purpose.

However, as we formally adopt the Twelve-Factor App methodology for the application itself, an analysis of our automation tooling reveals a philosophical misalignment. Specifically, the current tooling does not fully adhere to the principles it helps enforce:

1.  **Implicit Dependencies (Violation of Factor II):** The toolchain implicitly relies on the existence and version of system-wide tools like `make`, `awk`, `grep`, and `curl`. Their presence is not explicitly declared or verified in a manifest, leading to a non-deterministic setup environment.
2.  **Blurred Build/Run Stages (Violation of Factor V):** Running a command like `make apply` mixes infrastructure planning, building, and execution. There is no distinct "build" or "setup" stage for the automation logic that validates its own dependencies before running.
3.  **Brittle Logic:** The current shell scripts rely on parsing the text output of command-line tools (e.g., `virsh domifaddr | awk ...`). This creates a fragile contract that is less stable across OS versions than using a formal, versioned API.

This proposal seeks to address these shortcomings by evolving our automation toolchain to be a first-class, Twelve-Factor-compliant component of the project, thereby increasing its long-term robustness and maintainability.

#### **2. Proposed Change**

It is proposed that the project adopt a new technology stack for its automation, based on the following core decisions:

1.  **Adopt Meson as the Unified Automation Interface:** Meson will serve as the primary user-facing tool for running all project tasks. It will provide a single, declarative entry point for developers and CI/CD systems.
2.  **Adopt Modern Perl for Core Automation Logic:** The imperative logic currently in shell scripts will be migrated to a new, structured Perl codebase.
3.  **Adopt a "System-Package-Only" Dependency Policy:** To ensure maximum stability and a simple, curated "supply chain," this proposal mandates that all Perl module dependencies be fulfilled **exclusively through the system's native package manager** (e.g., `apt install libsys-virt-perl`). The direct use of language-specific, uncurated package managers like `cpanm` will be explicitly disallowed in the project's setup and CI workflows.
4.  **Establish a Stable Target Platform Benchmark:** All tooling and dependencies will target versions that are officially maintained for the **current Debian Stable release**. This includes packages from the official `backports` repository, as they are specifically compiled and certified for use with the stable base system. The critical guiding principle is: *Is the package officially provided for Debian Stable by the Debian maintainers?*
    *   *As of this writing, this sets our target versions to **Perl `5.36.0`** (from `bookworm`) and **Meson `1.7.0`** (from `bookworm-backports`).*

#### **3. Rationale for Proposed Change**

This strategic evolution will bring our automation toolchain into stronger alignment with the Twelve-Factor methodology and yield significant long-term benefits:

*   **Explicit, Verifiable Dependencies (Factor II):** The `meson.build` file will serve as an explicit dependency manifest. It will programmatically check for `perl`, `opentofu`, `libvirt-client`, and all required `perl-*` packages. This provides a single, deterministic command (`meson setup`) to validate a contributor's environment, failing hard and early with clear error messages if the environment is incorrect.
*   **Clear Build/Run Separation (Factor V):** The Meson workflow naturally separates our processes. `meson setup` becomes our distinct "build" stage, which configures the project and validates all dependencies. `meson test` or `meson compile` becomes the "run" stage, executing tasks in a pre-validated environment.
*   **Increased Robustness and Maintainability:** Migrating from brittle text-parsing in shell to using formal Perl modules (like `Sys::Virt`) allows us to depend on more stable, versioned APIs. Perl also provides superior error handling, data structures, and code organization, which will make the automation easier to maintain and extend.

#### **4. Scope and Relationship to Other Proposals**

This document's scope is strictly limited to the **strategic decision to adopt Meson and Perl**. It establishes the core "why" and "what" of the change.

All further details are explicitly deferred to subsequent proposals, which will build upon this foundational decision:

*   **Implementation Strategy & Structure (`ADR-005`):** Will detail the "how" of this migration, including the specific repository structure, the plan for an atomic cutover (a "flag day" migration), and the deprecation of the `Makefile`.
*   **Coding & Quality Standards (`ADR-006` and `ADR-007`):** Will define the "rules of the road" for the new Perl and Meson codebase, including mandatory pragmas, security hardening, linting policies, and style conventions.

#### **5. Consequences and Acknowledged Trade-offs**

*   **Primary Benefit:** The project's automation tooling will become a more reliable, maintainable, and professionally engineered component, in full alignment with the principles it helps to deploy.
*   **Acknowledged Trade-off 1: Loss of "Zero-Prerequisite" Setup.** The single greatest trade-off is sacrificing the convenience of `make` being pre-installed. A contributor's first action will now be to install the Meson/Perl toolchain via their system package manager. This is a conscious decision to prioritize explicit, verifiable correctness over "zero-setup" convenience.
*   **Acknowledged Trade-off 2: Dependency on a Curated Ecosystem.** By committing to system packages benchmarked against Debian Stable (including its official backports), we gain stability at the cost of immediate access to bleeding-edge tool and library features. This is a deliberate choice to favor long-term stability and reliability.

#### **6. Next Steps**

If this strategic proposal is accepted, the maintainers will proceed with a formal review of `ADR-005`, `ADR-006`, and `ADR-007` to finalize the implementation plan and quality standards for the new toolchain.
