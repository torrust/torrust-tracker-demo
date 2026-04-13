# ISSUE-19 Evidence: Prometheus 3h Summaries (2026-04-13)

<!-- cspell:ignore promql inet6 iptype memstats urlencode -->

## Context

Initial Prometheus pull for UDP and tracker activity over a 3-hour window.

Note: some metric names queried from `tracker_stats` do not end in `_total` and
Prometheus warns they may not be counters. Treat those results as directional
only, not exact event counts.

## Command

```bash
ssh demotracker 'set -e; echo "=== prometheus_up_targets ==="; curl -s "http://127.0.0.1:9090/api/v1/query?query=up"; echo; echo "=== metric_name_sample_tracker_udp ==="; curl -s "http://127.0.0.1:9090/api/v1/label/__name__/values" | tr "," "\n" | grep -Ei "tracker|udp|process_cpu|process_resident|go_memstats|http_tracker|udp_tracker|announce" | head -n 120'

ssh demotracker 'set -e; echo "=== metric_name_sample_process ==="; curl -s "http://127.0.0.1:9090/api/v1/label/__name__/values" | tr "," "\n" | grep -Ei "process_|go_memstats|go_gc|scrape_duration|scrape_samples" | head -n 120; echo; q(){ expr="$1"; echo "--- $expr"; curl -sG "http://127.0.0.1:9090/api/v1/query" --data-urlencode "query=$expr"; echo; }; echo "=== promql_3h_summaries ==="; q "increase(udp4_requests[3h])"; q "increase(udp6_requests[3h])"; q "increase(udp4_errors_handled[3h])"; q "increase(udp6_errors_handled[3h])"; q "increase(udp_requests_aborted[3h])"; q "increase(udp_tracker_server_requests_received_total[3h])"; q "increase(udp_tracker_server_responses_sent_total[3h])"; q "increase(udp_tracker_server_errors_total[3h])"; q "increase(http_tracker_core_requests_received_total[3h])"; q "sum(rate(process_cpu_seconds_total{job=~\"tracker_metrics|tracker_stats\"}[5m])) by (job)"; q "max(process_resident_memory_bytes{job=~\"tracker_metrics|tracker_stats\"}) by (job)"; q "sum(increase(scrape_samples_post_metric_relabeling[3h])) by (job)"'
```

## Key Output (excerpt)

```text
=== prometheus_up_targets ===
{"status":"success","data":{"resultType":"vector","result":[{"metric":{"__name__":"up","instance":"tracker:1212","job":"tracker_metrics"},"value":[1776091089.395,"1"]},{"metric":{"__name__":"up","instance":"tracker:1212","job":"tracker_stats"},"value":[1776091089.395,"1"]}]}}

=== metric_name_sample_tracker_udp ===
"udp4_announces_handled"
"udp4_connections_handled"
"udp4_errors_handled"
"udp4_requests"
"udp4_responses"
"udp6_announces_handled"
"udp6_connections_handled"
"udp6_errors_handled"
"udp6_requests"
"udp6_responses"
"udp_requests_aborted"
"udp_tracker_core_requests_received_total"
"udp_tracker_server_connection_id_errors_total"
"udp_tracker_server_errors_total"
"udp_tracker_server_requests_aborted_total"
"udp_tracker_server_requests_accepted_total"
"udp_tracker_server_requests_banned_total"
"udp_tracker_server_requests_received_total"
"udp_tracker_server_responses_sent_total"

=== promql_3h_summaries ===
--- increase(udp6_requests[3h])
... "value":[1776091152.049,"16720497.711908164"] ...
PromQL info: metric might not be a counter ... "udp6_requests"

--- increase(udp6_errors_handled[3h])
... "value":[1776091152.091,"248728.4916400069"] ...
PromQL info: metric might not be a counter ... "udp6_errors_handled"

--- increase(udp_tracker_server_requests_received_total[3h])
... port="6969" ... "value":[1776091152.140,"16722828.272908567"] ...

--- increase(udp_tracker_server_responses_sent_total[3h])
... request_kind="announce",result="ok",port="6969" ... "value":[1776091152.167,"7712018.825752926"] ...
... request_kind="connect",result="ok",port="6969" ... "value":[1776091152.167,"1940213.299857093"] ...
... request_kind="scrape",result="ok",port="6969" ... "value":[1776091152.167,"41339.018735422665"] ...
... result="error",port="6969" ... "value":[1776091152.167,"248618.45192461362"] ...

--- increase(udp_tracker_server_errors_total[3h])
... request_kind="announce",port="6969" ... "value":[1776091152.193,"163041.73026457502"] ...
... request_kind="scrape",port="6969" ... "value":[1776091152.193,"368.21393911740387"] ...
... (unlabeled-kind series),port="6969" ... "value":[1776091152.193,"85208.50772092119"] ...

--- increase(http_tracker_core_requests_received_total[3h])
... request_kind="announce",port="7070" ... "value":[1776091152.220,"14897280.595901787"] ...
... request_kind="scrape",port="7070" ... "value":[1776091152.220,"56095.592578095144"] ...

--- sum(rate(process_cpu_seconds_total{job=~"tracker_metrics|tracker_stats"}[5m])) by (job)
... "result":[]

--- max(process_resident_memory_bytes{job=~"tracker_metrics|tracker_stats"}) by (job)
... "result":[]
```

## Notes

- Prometheus targets are up for both tracker jobs.
- Useful counter-style metrics are available under
  `udp_tracker_server_*_total` and `http_tracker_core_requests_received_total`.
- `process_*` resource metrics are not present in either `tracker_stats` or
  `tracker_metrics` (`process_*` queries returned empty results for both jobs).
- Source split confirmed: `udp6_requests` is from `tracker_stats`, while
  `udp_tracker_server_*_total` comes from `tracker_metrics`.
- Next step: use `query_range` over 3h for selected `_total` series and export
  time series into dedicated files (suitable for graphing and CSV-like analysis).
