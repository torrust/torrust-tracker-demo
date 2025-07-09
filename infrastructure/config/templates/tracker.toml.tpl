# Generated Torrust Tracker configuration for ${ENVIRONMENT}
# Generated on: ${GENERATION_DATE}

[metadata]
app = "torrust-tracker"
purpose = "configuration"
schema_version = "2.0.0"

[logging]
threshold = "info"

[core]
inactive_peer_cleanup_interval = 600
listed = false
private = true
tracker_usage_statistics = true

[core.announce_policy]
interval = 120
interval_min = 120

[core.database]
driver = "mysql"
# URL will be set via environment variable: TORRUST_TRACKER_DATABASE_URL
url = ""

[core.net]
external_ip = "0.0.0.0"
on_reverse_proxy = true

[core.tracker_policy]
max_peer_timeout = 900
persistent_torrent_completed_stat = false
remove_peerless_torrents = true

# Health check API (internal only)
[health_check_api]
bind_address = "127.0.0.1:1313"

# Main HTTP API
[http_api]
bind_address = "0.0.0.0:1212"

# Admin token will be set via environment variable: TORRUST_TRACKER_API_ADMIN_TOKEN
[http_api.access_tokens]
# admin = ""

# UDP Trackers - Port 6868
[[udp_trackers]]
bind_address = "0.0.0.0:6868"

# UDP Trackers - Port 6969
[[udp_trackers]]
bind_address = "0.0.0.0:6969"

# HTTP Trackers - Port 7070
[[http_trackers]]
bind_address = "0.0.0.0:7070"
