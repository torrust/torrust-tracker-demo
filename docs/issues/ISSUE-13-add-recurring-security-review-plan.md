# Add a Recurring Security Review Plan for the Tracker Demo

**Issue**: [#13](https://github.com/torrust/torrust-tracker-demo/issues/13)
**Related**: [docs/security/security-review-plan.md](../security/security-review-plan.md)

## Overview

The tracker demo is a public internet-facing deployment that exposes multiple
entry points, including HTTPS services, UDP tracker endpoints, SSH, and public
Grafana dashboards. The repository already documents infrastructure,
post-deployment steps, monitoring, and operational issues, but it does not yet
have a dedicated, repeatable security review process focused on realistic attack
paths to initial access.

We need a maintained security review plan that can be reused periodically,
rather than a one-off note or an ad hoc checklist. The plan should make it easy
to reassess the same deployment over time, especially after infrastructure,
networking, authentication, or application changes.

The review should answer a practical question:

> How could an external attacker obtain meaningful access to the demo server or
> its deployed services?

For this demo, meaningful access includes host access, privileged container
access, access to admin or sensitive application functionality, or access to
secrets and persistent state.

## Why This Is Needed

- The deployment is intentionally public and should be reviewed as an attacker
  would see it.
- Security assumptions are currently spread across multiple files and are not
  organized into a recurring review workflow.
- Changes to Docker networking, reverse proxy routing, Grafana exposure,
  tracker API behavior, firewall rules, or image versions can change the attack
  surface over time.
- A reusable plan lowers the cost of future reviews and makes the review scope
  explicit for contributors.

## Proposed Deliverable

Add a dedicated security review planning document under `docs/security/` that
defines:

- The review goal and scope.
- The review cadence.
- The current deployment surfaces that must always be reviewed.
- A phased review method covering configuration, source code, runtime
  validation, and supply-chain review.
- A recurring checklist for future review cycles.
- An evidence request template listing the exact runtime and source information
  needed for each review.
- The expected output of each review cycle.

The document should be written as an operational reference, not as a single
incident note.

## Implementation Plan

- [ ] Create `docs/security/security-review-plan.md`.
- [ ] Document the review goal, scope, and recurring cadence.
- [ ] Document the main public entry points and trust boundaries currently
      visible in the demo deployment.
- [ ] Define a phased review process covering external attack surface, source
      review, host and container hardening, and supply-chain review.
- [ ] Add a recurring checklist for future review cycles.
- [ ] Add an evidence request template for the live environment and upstream
      source repositories.
- [ ] Run the Markdown linter on the new documentation.
- [ ] Run the spell checker and add any legitimate project-specific words to
      `project-words.txt`.

## Acceptance Criteria

- [ ] A security review plan exists at
      `docs/security/security-review-plan.md`.
- [ ] The document is clearly written as a reusable and periodically reviewed
      process document.
- [ ] The document includes review phases, recurring checklist items, and an
      evidence request template.
- [ ] The document passes the Markdown linter.
- [ ] The document passes the spell checker.

## Notes

This issue covers the creation of the review plan itself. Actual security review
execution, findings, and follow-up fixes should be tracked in separate issue
documents or dated review notes that reference the plan.
