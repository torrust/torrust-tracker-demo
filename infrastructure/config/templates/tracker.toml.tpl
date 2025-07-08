[logging]
threshold = "${TORRUST_TRACKER_LOG_LEVEL}"

[core]
inactive_peer_cleanup_interval = ${TORRUST_TRACKER_CLEANUP_INTERVAL}
listed = ${TORRUST_TRACKER_LISTED}
private = ${TORRUST_TRACKER_PRIVATE}
tracker_usage_statistics = ${TORRUST_TRACKER_STATS}

[core.announce_policy]
interval = ${TORRUST_TRACKER_ANNOUNCE_INTERVAL}
interval_min = ${TORRUST_TRACKER_ANNOUNCE_INTERVAL_MIN}

[core.database]
driver = "${TORRUST_TRACKER_DATABASE_DRIVER}"
# Database connection will be determined by driver type
# For MySQL: uses environment variable or falls back to default MySQL settings
# For SQLite: uses path specified in TORRUST_TRACKER_DATABASE_PATH

[core.net]
external_ip = "${TORRUST_TRACKER_EXTERNAL_IP}"
on_reverse_proxy = ${TORRUST_TRACKER_ON_REVERSE_PROXY}

[core.tracker_policy]
max_peer_timeout = ${TORRUST_TRACKER_MAX_PEER_TIMEOUT}
persistent_torrent_completed_stat = ${TORRUST_TRACKER_PERSISTENT_COMPLETED_STAT}
remove_peerless_torrents = ${TORRUST_TRACKER_REMOVE_PEERLESS}

# Health check API (separate from main API)
[health_check_api]
bind_address = "127.0.0.1:${TORRUST_TRACKER_HEALTH_CHECK_PORT}"

# Main HTTP API
[http_api]
bind_address = "0.0.0.0:${TORRUST_TRACKER_API_PORT}"

[http_api.access_tokens]
admin = "${TORRUST_TRACKER_API_TOKEN}"

# UDP Trackers - Port 6868
[[udp_trackers]]
bind_address = "0.0.0.0:6868"

# UDP Trackers - Port 6969
[[udp_trackers]]
bind_address = "0.0.0.0:6969"

# HTTP Trackers
[[http_trackers]]
bind_address = "0.0.0.0:${TORRUST_TRACKER_HTTP_PORT}"
