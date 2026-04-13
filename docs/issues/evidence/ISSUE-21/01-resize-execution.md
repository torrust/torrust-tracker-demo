# Resize Execution Log

## Planned Change

- From: CCX23 (4 vCPU, 16 GB RAM, 20 TB)
- To: CCX33 (8 vCPU, 32 GB RAM, 30 TB)
- Expected monthly cost: €62.49/mo

## Execution Checklist

- [ ] Resize action executed in provider panel
- [ ] Server reachable by SSH after resize
- [ ] `docker compose ps` healthy
- [ ] HTTP endpoint reachable
- [ ] UDP endpoint reachable
- [ ] Prometheus targets up
- [ ] Grafana accessible

## Timeline

- Start (UTC):
- End (UTC):
- Total impact window:

## Immediate Post-Resize Snapshot

- `uptime`:
- `free -h`:
- `docker stats --no-stream` summary:
- Any regressions observed:

## Notes

- Include exact commands and short outputs (or link to files under `data/`).
