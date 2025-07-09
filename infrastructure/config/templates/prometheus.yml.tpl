---
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'tracker_stats'
    static_configs:
      - targets: ['tracker:1212']
    metrics_path: '/api/v1/stats'
    params:
      token: ['${TRACKER_ADMIN_TOKEN}']
      format: ['prometheus']

  - job_name: 'tracker_metrics'
    static_configs:
      - targets: ['tracker:1212'] 
    metrics_path: '/api/v1/metrics'
    params:
      token: ['${TRACKER_ADMIN_TOKEN}']
      format: ['prometheus']

