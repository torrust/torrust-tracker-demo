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

# Tracker Database Configuration
TORRUST_TRACKER_CONFIG_OVERRIDE_CORE__DATABASE__DRIVER=${TRACKER_DATABASE_DRIVER}
TORRUST_TRACKER_CONFIG_OVERRIDE_CORE__DATABASE__PATH=${TRACKER_DATABASE_URL}

# Tracker API Token
TRACKER_ADMIN_TOKEN=${TRACKER_ADMIN_TOKEN}

# Docker Runtime Configuration
USER_ID=${USER_ID}

# Grafana Admin Credentials
GF_SECURITY_ADMIN_USER=${GF_SECURITY_ADMIN_USER}
GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD}

# Backup Configuration (used by backup scripts)
ENABLE_DB_BACKUPS=${ENABLE_DB_BACKUPS}
BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS}
