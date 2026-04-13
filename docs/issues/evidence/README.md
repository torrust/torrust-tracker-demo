# Issue Investigation Evidence

This folder stores raw investigation artifacts for issue work in progress.

Use this for command transcripts, log extracts, metrics snapshots, and network
captures collected before a root cause is confirmed.

Do not use this folder for final post-mortems. Post-mortems belong in
`docs/post-mortems/` after the incident is understood.

## Layout

- `docs/issues/evidence/ISSUE-<N>/`

## Suggested File Naming

- `YYYY-MM-DD-baseline-<topic>.md`
- `YYYY-MM-DD-logs-<service>.md`
- `YYYY-MM-DD-network-<topic>.md`
- `YYYY-MM-DD-metrics-<topic>.md`

Keep each capture in a separate file with:

1. Context
2. Exact command(s)
3. Raw output
4. Short notes/hypothesis
