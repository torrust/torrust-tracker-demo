# Generated Torrust Tracker configuration for ${ENVIRONMENT}
# Generated on: ${GENERATION_DATE}
#
# Configuration Override with Environment Variables:
# The Torrust Tracker uses the Figment crate for configuration management.
# Any configuration value can be overridden using environment variables with the pattern:
# TORRUST_TRACKER_CONFIG_OVERRIDE_<SECTION>__<SUBSECTION>__<KEY>
#
# Examples:
# [core.database]
# path = "..." -> TORRUST_TRACKER_CONFIG_OVERRIDE_CORE__DATABASE__PATH
#
# [http_api.access_tokens]
# admin = "..." -> TORRUST_TRACKER_CONFIG_OVERRIDE_HTTP_API__ACCESS_TOKENS__ADMIN
#
# [logging]
# threshold = "..." -> TORRUST_TRACKER_CONFIG_OVERRIDE_LOGGING__THRESHOLD
#
# Rules:
# - Use double underscores "__" to separate nested sections/keys
# - Convert section names to UPPERCASE
# - Dots in TOML become double underscores in env vars
# - This follows Figment's environment variable override conventions
#
# Example TOML Configuration (output from tracker after merging all sources):
# [metadata]
# app = "torrust-tracker"
# purpose = "configuration"
# schema_version = "2.0.0"
# 
# [logging]
# threshold = "info"
# 
# [core]
# inactive_peer_cleanup_interval = 120
# listed = false
# private = false
# tracker_usage_statistics = true
# 
#   [core.announce_policy]
#   interval = 120
#   interval_min = 120
# 
#   [core.database]
#   driver = "sqlite3"
#   path = "./storage/tracker/lib/database/sqlite3.db"
# 
#   [core.net]
#   external_ip = "0.0.0.0"
#   on_reverse_proxy = false
# 
#   [core.tracker_policy]
#   max_peer_timeout = 60
#   persistent_torrent_completed_stat = true
#   remove_peerless_torrents = true
# 
# [[udp_trackers]]
# bind_address = "0.0.0.0:6868"
# tracker_usage_statistics = true
# 
#   [udp_trackers.cookie_lifetime]
#   secs = 120
#   nanos = 0
# 
# [[udp_trackers]]
# bind_address = "0.0.0.0:6969"
# tracker_usage_statistics = true
# 
#   [udp_trackers.cookie_lifetime]
#   secs = 120
#   nanos = 0
# 
# [[http_trackers]]
# bind_address = "0.0.0.0:7070"
# tracker_usage_statistics = true
# 
# [[http_trackers]]
# bind_address = "0.0.0.0:7171"
# tracker_usage_statistics = true
# 
# [http_api]
# bind_address = "0.0.0.0:1212"
# 
#   [http_api.access_tokens]
#   admin = "***"
# 
# [health_check_api]
# bind_address = "127.0.0.1:1313"
#
# Documentation: https://docs.rs/torrust-tracker-configuration/latest/torrust_tracker_configuration/

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
# Path will be overridden via environment variable:
# TORRUST_TRACKER_CONFIG_OVERRIDE_CORE__DATABASE__PATH
path = ""

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

# Admin token will be overridden via environment variable:
# TORRUST_TRACKER_CONFIG_OVERRIDE_HTTP_API__ACCESS_TOKENS__ADMIN
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
