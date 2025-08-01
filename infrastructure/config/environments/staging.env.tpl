# Staging Environment Configuration Template for Hetzner Cloud  
# Copy this file to staging.env and replace placeholder values
# Location: infrastructure/config/environments/staging.env

# === ENVIRONMENT IDENTIFICATION ===
ENVIRONMENT=staging

# === VM CONFIGURATION ===
# Smaller instance for staging to save costs
VM_NAME=torrust-tracker-staging
VM_MEMORY=4096              # Maps to cx21 server type (2 vCPU, 8GB RAM, 40GB SSD)
VM_VCPUS=2                  # Informational - actual vCPUs determined by server type  
VM_DISK_SIZE=40             # Informational - actual storage determined by server type

# === APPLICATION SECRETS ===
# Use different passwords than production but still secure
MYSQL_ROOT_PASSWORD=REPLACE_WITH_STAGING_ROOT_PASSWORD
MYSQL_PASSWORD=REPLACE_WITH_STAGING_USER_PASSWORD
TRACKER_ADMIN_TOKEN=REPLACE_WITH_STAGING_ADMIN_TOKEN
GF_SECURITY_ADMIN_PASSWORD=REPLACE_WITH_STAGING_GRAFANA_PASSWORD

# === SSL CONFIGURATION ===
# Use staging subdomain
DOMAIN_NAME=REPLACE_WITH_STAGING_DOMAIN    # e.g., staging.tracker.example.com
CERTBOT_EMAIL=REPLACE_WITH_YOUR_EMAIL      # e.g., admin@example.com
ENABLE_SSL=true

# === DATABASE CONFIGURATION ===
MYSQL_DATABASE=torrust_tracker
MYSQL_USER=torrust

# === BACKUP CONFIGURATION ===
# Shorter retention for staging
ENABLE_DB_BACKUPS=true
BACKUP_RETENTION_DAYS=3

# === RUNTIME CONFIGURATION ===
USER_ID=1000

# === STAGING-SPECIFIC SETTINGS ===
# Less strict security for staging (easier debugging)
FAIL2BAN_ENABLED=true
UFW_STRICT_MODE=false
AUTO_SECURITY_UPDATES=true

# === MONITORING CONFIGURATION ===
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_DISABLE_GRAVATAR=true
GF_USERS_ALLOW_SIGN_UP=false
GF_USERS_ALLOW_ORG_CREATE=false

# === PERFORMANCE TUNING ===
# Lighter settings for staging
MYSQL_INNODB_BUFFER_POOL_SIZE=256M
MYSQL_MAX_CONNECTIONS=50

# === HETZNER-SPECIFIC SETTINGS ===
# Use smaller, cheaper server type for staging
# HETZNER_SERVER_TYPE=cx21    # 2 vCPU, 8GB RAM, 40GB SSD (~€5.83/month)
# HETZNER_LOCATION=nbg1       # Nuremberg (default)

# === MAINTENANCE SETTINGS ===
# More frequent cleanup for staging
BACKUP_SCHEDULE="0 3 * * *"      # Daily at 3 AM
CLEANUP_SCHEDULE="0 4 * * *"     # Daily at 4 AM
