# Security Review Reports

This folder contains recurring security review reports for the live Torrust
Tracker Demo deployment.

## Conventions

- Use one folder per review cycle.
- Prefer time-based names such as `2026-04` or `2026-q2`.
- Keep sensitive raw evidence out of git.
- Commit sanitized summaries, findings, and references to private evidence
  instead.

## Standard Review-Cycle Files

- `README.md` for the final summary report.
- `progress.md` for in-progress tracking.
- `findings.md` for confirmed findings and accepted risks.
- One numbered file per attack surface or service under review.

The reporting model is defined in
[../security-review-plan.md](../security-review-plan.md).
