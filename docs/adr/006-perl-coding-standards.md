### **ADR-006: Proposal for Perl Coding and Security Standards**

*   **Status:** Proposed for Review
*   **Date:** 2025-07-09
*   **Proposer:** Cameron
*   **Reviewers:** [List of project maintainers/core contributors]
*   **Depends On:** [ADR-005: Proposal for a Test-Driven Implementation and Structure](./005-test-driven-implementation.md)

#### **1. Context and Problem Statement**

Having established the strategy (`ADR-004`) and structure (`ADR-005`) for our new Meson/Perl automation toolchain, it is imperative that we define a clear and enforceable set of standards for the code itself. Without agreed-upon conventions, the new codebase could quickly accumulate technical debt, becoming inconsistent, insecure, or difficult to maintain.

This proposal aims to establish a baseline of quality, security, and convention for all Perl code within the `automation/` directory, ensuring the long-term health and clarity of our internal tooling.

#### **2. Proposed Standards**

It is proposed that the project adopt the following set of standards for all Perl code contributed:

1.  **Mandatory Pragmas for Code Safety:** It is recommended that all Perl scripts (`.pl`) and modules (`.pm`) enable `use strict;`, `use warnings;`, and `use autodie;`. This combination is foundational for modern, safe Perl, as it catches common errors, enforces good scoping, and ensures that failed system calls result in a predictable, immediate script failure.

2.  **Minimum Perl Version Benchmark:** To ensure broad compatibility and stability, it is proposed that the codebase target the version of Perl shipped in the **current Debian Stable release**. This provides an objective benchmark that aligns development with common server environments. The corresponding `use vX.XX;` pragma should be included in all Perl files to enforce this minimum version.
    *   *As of this writing, Debian 12 ("Bookworm") ships with Perl 5.36.0. The current standard would therefore be **`use v5.36;`**.*

3.  **Static Analysis via Perl::Critic:** It is suggested that `Perl::Critic` be adopted as the official linter. By integrating it into the `meson test` suite, we can provide automated feedback on code style and quality for all contributions, ensuring consistency.

4.  **Security Hardening by Default:** It is recommended that all executable Perl scripts be run with taint mode (`-T`). This is a proven security feature that prevents insecure data passed from outside the program (e.g., environment variables, command-line arguments) from being used in commands that interact with the shell.

5.  **Consistent Command-Line Interface:** To create a predictable user experience for developers, it is proposed that all public-facing scripts adopt a standard CLI argument style, implemented using Perl's core `Getopt::Long` module.

#### **3. Rationale for Proposed Standards**

Adopting this comprehensive set of standards offers clear, long-term engineering advantages:

*   **Reliability:** The chosen pragmas create code that is robust by default. `autodie` ensures that a failed `open()` or `mkdir()` will halt execution immediately, which is critical for deterministic automation.
*   **Security:** Taint mode (`-T`) provides a strong, language-level defense against a class of command-injection vulnerabilities, which is a professional standard for any tool that orchestrates system commands.
*   **Maintainability:** A consistent style enforced by `Perl::Critic` reduces the cognitive overhead required to read, review, and maintain the codebase. Code reviews can focus on logic, not formatting.
*   **Stability:** Pegging the language version to Debian Stable provides a durable and predictable platform, avoiding both rapid churn from chasing the latest features and stagnation from targeting old versions.

#### **4. Recommended Implementation**

**1. Standard Boilerplate for `.pl` and `.pm` files:**
The following header could serve as a template for all new Perl files.

```perl
#!/usr/bin/env perl -T
# The -T flag enables taint mode for security hardening.

use strict;
use warnings;
# The autodie pragma automatically promotes failed system calls into exceptions.
use autodie;

# Enforce a minimum Perl version pegged to the current Debian Stable release.
# As of Q3 2025, this is Perl 5.36 (from Debian 12 'Bookworm').
use v5.36;
```

**2. Centralized `Perl::Critic` Configuration:**
To manage our linting policy, a configuration file should be created at `automation/.perlcriticrc`.

```ini
# A gentle starting point that focuses on the most important issues.
# It avoids being overly pedantic about minor style nits.
severity = gentle

# Example of disabling a specific, often-controversial policy.
# Subroutine prototypes are used less often in modern Perl styles.
[-Subroutines::ProhibitSubroutinePrototypes]
```

**3. Proposed Meson Integration:**
The `meson.build` file can define clear, separate targets for testing and linting.

```meson
# In meson.build

perlcritic_prog = find_program('perlcritic', required: true)
prove_prog = find_program('prove', required: true)

# Test Target 1: Code Style & Quality. Implicitly uses .perlcriticrc.
test('Perl::Critic Linting', perlcritic_prog, args: ['automation/'])

# Test Target 2: Unit Test Execution via the 'prove' TAP harness.
test('Automation Unit Tests', prove_prog, args: ['-vr', 'automation/t/'])
```

#### **5. Acknowledged Trade-offs**

*   **Increased Formality:** This proposal introduces a more formal development process. Contributors will need to adhere to these standards, which is more restrictive than writing simple shell scripts. This is presented as a beneficial trade-off for the gains in long-term quality and security.
*   **Exclusion of Newer Language Features:** The project would intentionally be unable to use Perl features newer than what is available in the benchmarked Debian Stable release. This is a deliberate choice prioritizing stability and compatibility.

#### **6. Next Steps**

If this proposal is accepted, it will serve as the official quality standard for all code developed during the migration outlined in `ADR-005`. All new Perl contributions will be expected to adhere to these rules, which will be enforced automatically by the CI pipeline.
