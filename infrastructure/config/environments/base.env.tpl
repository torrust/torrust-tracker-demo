# ${ENVIRONMENT_DESCRIPTION}
# ${ENVIRONMENT_INSTRUCTIONS}

ENVIRONMENT=${ENVIRONMENT}
GENERATION_DATE=$(date '+%Y-%m-%d %H:%M:%S')

${TEMPLATE_PROCESSING_VARS}

# === VM CONFIGURATION ===
# Virtual machine configuration for infrastructure provisioning
VM_NAME=${VM_NAME}
VM_MEMORY=${VM_MEMORY}
VM_VCPUS=${VM_VCPUS}
VM_DISK_SIZE=${VM_DISK_SIZE}
PERSISTENT_DATA_SIZE=${PERSISTENT_DATA_SIZE}
SSH_PUBLIC_KEY=${SSH_PUBLIC_KEY}
USE_MINIMAL_CONFIG=${USE_MINIMAL_CONFIG}

# === SECRETS (DOCKER SERVICES) ===
${SECRETS_DESCRIPTION}

# Database Secrets
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_DATABASE=torrust_tracker
MYSQL_USER=torrust
MYSQL_PASSWORD=${MYSQL_PASSWORD}

# Tracker API Token${TRACKER_TOKEN_DESCRIPTION}
TRACKER_ADMIN_TOKEN=${TRACKER_ADMIN_TOKEN}

# Grafana Admin Credentials
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD}

# === SSL CERTIFICATE CONFIGURATION ===
# Domain name for SSL certificates${DOMAIN_NAME_DESCRIPTION}
DOMAIN_NAME=${DOMAIN_NAME}
# Email for ${CERTBOT_EMAIL_DESCRIPTION}
CERTBOT_EMAIL=${CERTBOT_EMAIL}
# Enable SSL certificates${ENABLE_SSL_DESCRIPTION}
ENABLE_SSL=${ENABLE_SSL}

# === BACKUP CONFIGURATION ===
# Enable daily database backups${BACKUP_DESCRIPTION}
ENABLE_DB_BACKUPS=${ENABLE_DB_BACKUPS}
# Backup retention period in days
BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS}

# === DEPLOYMENT AUTOMATION CONFIGURATION ===
# These variables control deployment scripts and automation, not service configuration.
# They are consumed by infrastructure scripts (deploy-app.sh, SSL generation, backup automation)
# rather than individual Docker services. This follows 12-factor principles for deployment automation.

# === DOCKER CONFIGURATION ===

# User ID for file permissions${USER_ID_DESCRIPTION}
USER_ID=${USER_ID}
