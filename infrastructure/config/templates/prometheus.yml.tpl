---
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'torrust-tracker'
    static_configs:
      - targets: ['tracker:${TORRUST_TRACKER_API_PORT}']
    metrics_path: '/metrics'
    scrape_interval: 30s
