# Local Development Environment Configuration
ENVIRONMENT=local
GENERATION_DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Template processing variables
DOLLAR=$

# === SECRETS (DOCKER SERVICES) ===

# Database Secrets
MYSQL_ROOT_PASSWORD=root_secret_local
MYSQL_DATABASE=torrust_tracker
MYSQL_USER=torrust
MYSQL_PASSWORD=tracker_secret_local

# Tracker API Token
TRACKER_ADMIN_TOKEN=MyAccessToken

# Grafana Admin Credentials
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=admin_secret_local

# === SSL CERTIFICATE CONFIGURATION ===
# Domain name for SSL certificates (local testing with fake domains)
DOMAIN_NAME=test.local
# Email for certificate registration (test email for local)
CERTBOT_EMAIL=test@test.local
# Enable SSL certificates (false for local testing)
ENABLE_SSL=false

# === BACKUP CONFIGURATION ===
# Enable daily database backups (disabled for local testing)
ENABLE_DB_BACKUPS=false
# Backup retention period in days
BACKUP_RETENTION_DAYS=3

# === DEPLOYMENT AUTOMATION CONFIGURATION ===
# These variables control deployment scripts and automation, not service configuration.
# They are consumed by infrastructure scripts (deploy-app.sh, SSL generation, backup automation)
# rather than individual Docker services. This follows 12-factor principles for deployment automation.

# === DOCKER CONFIGURATION ===

# User ID for file permissions
USER_ID=1000
