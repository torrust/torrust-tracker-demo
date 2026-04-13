# Pre vs Post Resize Comparison

## Goal

Confirm whether resizing from CCX23 to CCX33 improved UDP uptime to >= 99.0%
and reduced sustained reliability pressure.

## Summary Table

| Metric                | Pre-resize | Post-resize | Change | Interpretation |
| --------------------- | ---------- | ----------- | ------ | -------------- |
| HTTP1 req/s           |            |             |        |                |
| UDP1 req/s            |            |             |        |                |
| Total req/s           |            |             |        |                |
| Req/s per vCPU        |            |             |        |                |
| UDP newTrackon uptime |            |             |        |                |
| UDP errors            |            |             |        |                |
| UDP aborted           |            |             |        |                |
| Host load             |            |             |        |                |

## Decision

- [ ] Success: target met and sustained
- [ ] Partial: improved but below target
- [ ] No improvement: continue with next bottleneck path

## Follow-up Actions

1.
2.
3.
