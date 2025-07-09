---
# Prometheus Configuration Template
# Generated from environment variables for ${ENVIRONMENT}
#
# NOTE: Admin token is stored in plain text in this config file after template processing.
# This is a limitation of Prometheus configuration - it does not support runtime environment
# variable substitution like other services.
#
# TODO: Research safer secret injection methods for Prometheus:
#   - Prometheus file_sd_configs with dynamic token refresh
#   - External authentication proxy (oauth2-proxy, etc.)
#   - Vault integration or secret management solutions
#   - Init containers to generate configs with short-lived tokens

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

