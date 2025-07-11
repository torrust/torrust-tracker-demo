# Production Environment Configuration Template
# Copy this file to production.env and replace placeholder values with secure secrets

ENVIRONMENT=production
GENERATION_DATE=$(date '+%Y-%m-%d %H:%M:%S')

# === SECRETS (Only these variables will be in Docker environment) ===
# IMPORTANT: Replace ALL placeholder values with actual secure secrets before deployment!

# Database Secrets
MYSQL_ROOT_PASSWORD=REPLACE_WITH_SECURE_ROOT_PASSWORD
MYSQL_DATABASE=torrust_tracker
MYSQL_USER=torrust
MYSQL_PASSWORD=REPLACE_WITH_SECURE_PASSWORD

# Tracker API Token (Used for administrative API access)
TRACKER_ADMIN_TOKEN=REPLACE_WITH_SECURE_ADMIN_TOKEN

# Grafana Admin Credentials
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=REPLACE_WITH_SECURE_GRAFANA_PASSWORD

# === DOCKER CONFIGURATION ===

# User ID for file permissions (match host user)
USER_ID=1000
