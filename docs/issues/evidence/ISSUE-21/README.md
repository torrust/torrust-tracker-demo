# ISSUE-21 Evidence: Server Scale-Up (CCX23 -> CCX33)

Related issue: [#21](https://github.com/torrust/torrust-tracker-demo/issues/21)

This folder contains structured evidence for the resize experiment.

## Files

- `00-pre-resize-baseline.md` — baseline before resizing
- `01-resize-execution.md` — resize action log and immediate checks
- `02-post-resize-daily-checks.md` — 7-day observation log
- `03-pre-post-comparison.md` — final outcome summary
- `data/` — exported metric artifacts (JSON/CSV)

## Success Target

- UDP newTrackon uptime >= 99.0% over rolling 7 days.
