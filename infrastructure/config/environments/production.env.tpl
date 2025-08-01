# Production Environment Configuration Template for Hetzner Cloud
# Copy this file to production.env and replace placeholder values
# Location: infrastructure/config/environments/production.env

# === ENVIRONMENT IDENTIFICATION ===
ENVIRONMENT=production

# === VM CONFIGURATION ===
# These values will be used with Hetzner server types
VM_NAME=torrust-tracker-prod
VM_MEMORY=8192              # Maps to cx31 server type (2 vCPU, 8GB RAM, 80GB SSD)
VM_VCPUS=2                  # Informational - actual vCPUs determined by server type
VM_DISK_SIZE=80             # Informational - actual storage determined by server type

# For higher performance, consider:
# VM_MEMORY=16384           # Maps to cx41 server type (4 vCPU, 16GB RAM, 160GB SSD)
# VM_MEMORY=32768           # Maps to cx51 server type (8 vCPU, 32GB RAM, 320GB SSD)

# === APPLICATION SECRETS ===
# CRITICAL: Replace these with secure, randomly generated passwords
MYSQL_ROOT_PASSWORD=REPLACE_WITH_SECURE_ROOT_PASSWORD_32_CHARS_MIN
MYSQL_PASSWORD=REPLACE_WITH_SECURE_USER_PASSWORD_32_CHARS_MIN
TRACKER_ADMIN_TOKEN=REPLACE_WITH_SECURE_ADMIN_TOKEN_32_CHARS_MIN
GF_SECURITY_ADMIN_PASSWORD=REPLACE_WITH_SECURE_GRAFANA_PASSWORD

# Generate secure passwords with:
# openssl rand -base64 32

# === SSL CONFIGURATION ===
# Replace with your actual domain and email
DOMAIN_NAME=REPLACE_WITH_YOUR_DOMAIN  # e.g., tracker.example.com
CERTBOT_EMAIL=REPLACE_WITH_YOUR_EMAIL # e.g., admin@example.com
ENABLE_SSL=true

# === DATABASE CONFIGURATION ===
MYSQL_DATABASE=torrust_tracker
MYSQL_USER=torrust

# === BACKUP CONFIGURATION ===
ENABLE_DB_BACKUPS=true
BACKUP_RETENTION_DAYS=7

# === RUNTIME CONFIGURATION ===
USER_ID=1000

# === PRODUCTION HARDENING ===
# Enable additional security features for production
FAIL2BAN_ENABLED=true
UFW_STRICT_MODE=true
AUTO_SECURITY_UPDATES=true

# === MONITORING CONFIGURATION ===
# Grafana configuration for production monitoring
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_DISABLE_GRAVATAR=true
GF_USERS_ALLOW_SIGN_UP=false
GF_USERS_ALLOW_ORG_CREATE=false

# === PERFORMANCE TUNING ===
# MySQL performance settings for production
MYSQL_INNODB_BUFFER_POOL_SIZE=512M
MYSQL_MAX_CONNECTIONS=100

# === HETZNER-SPECIFIC SETTINGS ===
# These can override provider defaults
# HETZNER_SERVER_TYPE=cx41    # Uncomment for higher performance (4 vCPU, 16GB RAM)
# HETZNER_LOCATION=fsn1       # Uncomment to use Falkenstein instead of Nuremberg

# === MAINTENANCE SETTINGS ===
# Backup and maintenance schedules
BACKUP_SCHEDULE="0 2 * * *"      # Daily at 2 AM
CLEANUP_SCHEDULE="0 3 * * 0"     # Weekly on Sunday at 3 AM

# === EXAMPLE PRODUCTION VALUES ===
# Here's an example of what a production configuration might look like:
#
# DOMAIN_NAME=tracker.torrust.com
# CERTBOT_EMAIL=admin@torrust.com
# MYSQL_ROOT_PASSWORD=5K3$9mN#pQ2@vX8!wL6zR4$Y7*tE1nH9
# MYSQL_PASSWORD=8mW#2pQ@5X$7!nL3zR6*Y9tE4H$K1vB@
# TRACKER_ADMIN_TOKEN=2Q@5X$7mW#pL3nz6*Y9tE4H$K1vB8@R
# GF_SECURITY_ADMIN_PASSWORD=X$7mW#pQ@5L3nz6*Y9tE4H$1vB
