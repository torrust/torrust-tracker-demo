# Pre vs Post Resize Comparison

## Goal

Confirm whether resizing from CCX23 to CCX33 improved UDP uptime to >= 99.0%
and reduced sustained reliability pressure.

## Summary Table

| Metric                | Pre-resize (CCX23) | Post-resize D+1 (CCX33) | Change  | Interpretation                                                                      |
| --------------------- | ------------------ | ----------------------- | ------- | ----------------------------------------------------------------------------------- |
| HTTP1 req/s           | ~1350              | ~1564                   | +16%    | Traffic grew during observation gap                                                 |
| UDP1 req/s            | ~1507              | ~1015                   | -33%    | Traffic lower on D+1; conntrack overflow may have been suppressing visible count    |
| Total req/s           | ~2857              | ~2579                   | -10%    | Overall lower on D+1                                                                |
| Req/s per vCPU        | ~714 (4 vCPU)      | ~322 (8 vCPU)           | -55%    | Significant headroom gained from resize                                             |
| UDP newTrackon uptime | 92.20%             | 83.9% (D+1, pre-fix)    | -8.3 pp | Degraded — resize alone was insufficient; conntrack overflow was actual bottleneck  |
| UDP errors            | ~52984/h           | ~37474/h (pre-fix)      | -29%    | Lower but still high; dropped after conntrack fix applied                           |
| UDP aborted           | ~283/h             | 0                       | -100%   | Gone after resize                                                                   |
| Host load             | 6.57/6.54/6.66     | 6.05/5.49/4.80          | Lower   | Load spread over 8 vCPUs vs 4; normalized load dropped from ~1.65 to ~0.76 per vCPU |

## Decision

- [ ] Success: target met and sustained
- [x] Partial: improved but below target — resize alone was insufficient; conntrack overflow was the actual bottleneck
- [ ] No improvement: continue with next bottleneck path

**Status (2026-04-21):** Conntrack fix applied on D+1 and appears active. Rolling UDP
uptime on newTrackon is still 85.70% on D+2, while recent probes in
[newTrackon raw](https://newtrackon.com/raw) are currently successful. This
supports a lagging rolling-window effect; 7-day monitoring must complete before
a final pass/fail decision.

## Follow-up Actions

1. Monitor D+2 through D+7 UDP uptime on newTrackon to confirm fix holds.
2. Verify conntrack fix survives a server reboot (module pre-load + sysctl applied).
3. If uptime >= 99.0% by D+7 close issue as resolved.
4. Document in post-mortem if UDP uptime does not recover after fix.
