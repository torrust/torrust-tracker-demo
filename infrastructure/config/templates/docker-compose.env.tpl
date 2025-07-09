# Generated Docker Compose environment file for ${ENVIRONMENT}
# Generated on: ${GENERATION_DATE}
# 
# This file contains only secrets and Docker-specific configuration.
# Application behavior is configured in config files (tracker.toml, prometheus.yml).

# Database Secrets
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_DATABASE=${MYSQL_DATABASE}
MYSQL_USER=${MYSQL_USER}
MYSQL_PASSWORD=${MYSQL_PASSWORD}

# Tracker API Token
TRACKER_ADMIN_TOKEN=${TRACKER_ADMIN_TOKEN}

# Docker Runtime Configuration
USER_ID=${USER_ID}

# Grafana Admin Credentials
GF_SECURITY_ADMIN_USER=${GF_SECURITY_ADMIN_USER}
GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD}
