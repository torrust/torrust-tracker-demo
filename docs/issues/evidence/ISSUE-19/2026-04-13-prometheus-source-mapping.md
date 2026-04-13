# ISSUE-19 Evidence: Prometheus Source Mapping (2026-04-13)

<!-- cspell:ignore urlencode -->

## Context

Validation of which metrics come from `tracker_stats` vs `tracker_metrics`.

## Command

```bash
ssh demotracker 'set -e; q(){ echo "--- $1"; curl -sG "http://127.0.0.1:9090/api/v1/query" --data-urlencode "query=$1"; echo; }; q "count({job=\"tracker_stats\"})"; q "count({job=\"tracker_metrics\"})"; q "count(udp6_requests{job=\"tracker_stats\"})"; q "count(udp6_requests{job=\"tracker_metrics\"})"; q "count(udp_tracker_server_requests_received_total{job=\"tracker_metrics\"})"; q "count(udp_tracker_server_requests_received_total{job=\"tracker_stats\"})"; q "count(process_cpu_seconds_total{job=\"tracker_metrics\"})"; q "count(process_cpu_seconds_total{job=\"tracker_stats\"})"'
```

## Output

```text
--- count({job="tracker_stats"})
{"status":"success","data":{"resultType":"vector","result":[{"metric":{},"value":[1776091339.778,"33"]}]}}
--- count({job="tracker_metrics"})
{"status":"success","data":{"resultType":"vector","result":[{"metric":{},"value":[1776091339.789,"328"]}]}}
--- count(udp6_requests{job="tracker_stats"})
{"status":"success","data":{"resultType":"vector","result":[{"metric":{},"value":[1776091339.804,"1"]}]}}
--- count(udp6_requests{job="tracker_metrics"})
{"status":"success","data":{"resultType":"vector","result":[]}}
--- count(udp_tracker_server_requests_received_total{job="tracker_metrics"})
{"status":"success","data":{"resultType":"vector","result":[{"metric":{},"value":[1776091339.841,"2"]}]}}
--- count(udp_tracker_server_requests_received_total{job="tracker_stats"})
{"status":"success","data":{"resultType":"vector","result":[]}}
--- count(process_cpu_seconds_total{job="tracker_metrics"})
{"status":"success","data":{"resultType":"vector","result":[]}}
--- count(process_cpu_seconds_total{job="tracker_stats"})
{"status":"success","data":{"resultType":"vector","result":[]}}
```

## Findings

- `tracker_stats` and `tracker_metrics` are both active and provide different sets.
- `udp6_requests` is present in `tracker_stats` only.
- `udp_tracker_server_requests_received_total` is present in `tracker_metrics` only.
- `process_cpu_seconds_total` is present in neither job (not exported by these tracker endpoints).

## Implication for Analysis

Use both sources deliberately:

- Use `tracker_metrics` for detailed reliability counters (`*_total`, result labels,
  server binding labels).
- Use `tracker_stats` for aggregate tracker-level counters/gauges.
