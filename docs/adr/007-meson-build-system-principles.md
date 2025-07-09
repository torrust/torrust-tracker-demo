
### **ADR-007: Proposal for Meson Build System Principles and Conventions**

*   **Status:** Proposed for Review
*   **Date:** 2025-07-11
*   **Proposer:** Cameron
*   **Reviewers:** [List of project maintainers/core contributors]
*   **Depends On:** [ADR-005: Proposal for a Test-Driven Implementation and Structure](./005-test-driven-implementation.md)

#### **1. Context and Problem Statement**

With the adoption of Meson as our primary automation interface (`ADR-005`), we must establish a clear set of principles for its use. A build system without guiding conventions can become as unmaintainable as the scripting it replaces. This document proposes a set of high-level standards to ensure our Meson build system remains clean, readable, robust, and aligned with the project's long-term goals.

Its scope is to define the *philosophy* and *usage expectations* for our Meson build files, not the specific implementation details.

#### **2. Proposed Principles and Conventions**

It is proposed that our use of Meson be governed by the following core principles:

1.  **Principle of a Stable Build Environment:** The project's build system shall target a stable, predictable, and publicly benchmarked version of Meson. We will adopt the version shipped in the **current Debian Stable release** as our official minimum required version. This ensures that the features available to our build system are consistent with common, stable server environments and change on a slow, predictable cycle.

2.  **Principle of Modularity:** The build logic must be organized into modular sub-projects using Meson's `subdir()` functionality. The root `meson.build` file shall serve only as a high-level orchestrator, defining global project options and including component-specific build definitions. This keeps the main entry point clean and delegates complexity to the relevant sub-systems (e.g., an `automation/meson.build`).

3.  **Principle of Explicit Dependency Management:** All external tools, libraries, or `pkg-config` dependencies required by the automation toolchain must be declared and located exclusively through Meson’s native functions (`dependency()` and `find_program()`). The use of `run_command()` or other brittle methods to manually locate dependencies is explicitly disallowed. The `meson setup` phase is the single, authoritative gatekeeper for all system dependencies.

4.  **Principle of a Unified Quality Gate:** All quality assurance tasks—including static analysis, linting, and unit tests—must be integrated as runnable targets within the Meson build definition. This establishes `meson test` as the single, canonical command for a contributor to validate the full spectrum of their changes against project standards.

5.  **Principle of Consistent Style:** All `meson.build` files must adhere to a consistent, documented style to ensure readability and maintainability across the project. The specific style guide will be maintained separately in a `CONTRIBUTING.md` document, but its existence and enforcement are mandated by this principle.

#### **3. Rationale for Adopting These Principles**

These principles are not arbitrary rules; they are designed to cultivate a professional and durable build system:

*   **Stability and Predictability:** The Debian Stable benchmark prevents dependency churn and ensures our automation is compatible with long-term support operating systems.
*   **Readability and Scalability:** A modular structure prevents the build definition from becoming a monolithic file, making it easier for new contributors to understand and for maintainers to extend over time.
*   **Robustness and Reliability:** By enforcing the use of Meson's native dependency functions, we get clear, immediate, and user-friendly error messages when a required tool is missing, which is vastly superior to a script failing mid-execution.
*   **Developer Efficiency:** A unified quality gate (`meson test`) simplifies the contribution workflow. A developer knows that if `meson test` passes, their changes meet the project's quality standards.

#### **4. Next Steps**

If this proposal is accepted, it will serve as the guiding architectural standard for all Meson build system code contributed to the project. The implementation of the migration (as detailed in `ADR-005`) will be engineered to adhere to these principles. The specific style conventions will be documented in a relevant contributor guide.
