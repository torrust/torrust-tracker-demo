# Infrastructure Resize and Traffic History

Tracks server sizing changes and observed traffic levels over time.

Use this file to keep historical context for capacity decisions and uptime
investigations (especially for UDP uptime on newTrackon).

## How to Use This Log

1. Add one row before each resize (baseline).
2. Add one row after each resize (same observation method/time window).
3. Keep request-rate observations comparable (for example same dashboard window).
4. Link related issue/PR and note whether uptime improved.

## Observation Method

- HTTP request rate source: Grafana HTTP1 dashboard
- UDP request rate source: Grafana UDP1 dashboard
- Total request rate: `HTTP1 req/s + UDP1 req/s`
- Normalized load: `total req/s / vCPU`
- Suggested window: `from=now-3h` to `to=now`
- Uptime source: newTrackon public tracker status

## Timeline

| Date (UTC) | Change type           | Server plan | vCPU | RAM   | HTTP1 req/s | UDP1 req/s | Total req/s | Req/s per vCPU | UDP newTrackon uptime | Notes                                                                                | Related                                                          |
| ---------- | --------------------- | ----------- | ---- | ----- | ----------- | ---------- | ----------- | -------------- | --------------------- | ------------------------------------------------------------------------------------ | ---------------------------------------------------------------- |
| 2026-04-13 | Baseline (pre-resize) | CCX23       | 4    | 16 GB | ~1300       | ~1500      | ~2800       | ~700           | 92.20%                | High combined load. Capacity pressure suspected at current normalized request rate.  | [#19](https://github.com/torrust/torrust-tracker-demo/issues/19) |
| 2026-04-13 | Planned target resize | CCX33       | 8    | 32 GB | ~1300       | ~1500      | ~2800       | ~350           | 92.20%                | Selected next plan: 30 TB traffic, €0.100/h - €62.49/mo. Value assumes similar load. | [#21](https://github.com/torrust/torrust-tracker-demo/issues/21) |

## Decision Criteria (Suggested)

- Target UDP uptime: >= 99.0% over a 7-day rolling window.
- Compare 3-7 days pre-resize vs 3-7 days post-resize.
- Consider resize successful if uptime improves materially and sustained error
  pressure decreases.

## Follow-up Checks After Each Resize

1. Track UDP uptime daily for at least 7 days.
2. Re-check host load and UDP receive buffer errors.
3. Compare tracker error/aborted counters before vs after resize.
4. Record final conclusion in this file and in the related issue.
