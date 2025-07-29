#!/bin/bash
# MySQL database backup script for Torrust Tracker
# Creates daily MySQL dumps with automatic cleanup and logging

set -euo pipefail

# Configuration
APP_DIR="/home/torrust/github/torrust/torrust-tracker-demo/application"
BACKUP_DIR="/var/lib/torrust/mysql/backups"
DATE=$(date +%Y%m%d_%H%M%S)
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

# Change to application directory
cd "$APP_DIR"

# Source environment variables from the deployment location
ENV_FILE="/var/lib/torrust/compose/.env"
if [[ -f "$ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
else
    echo "$LOG_PREFIX ERROR: Environment file not found at $ENV_FILE"
    exit 1
fi

# Validate required environment variables
if [[ -z "${MYSQL_ROOT_PASSWORD:-}" ]]; then
    echo "$LOG_PREFIX ERROR: MYSQL_ROOT_PASSWORD not set in environment"
    exit 1
fi

if [[ -z "${MYSQL_DATABASE:-}" ]]; then
    echo "$LOG_PREFIX ERROR: MYSQL_DATABASE not set in environment"
    exit 1
fi

# Use BACKUP_RETENTION_DAYS from environment, default to 7 days
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"

# Validate retention days is numeric
if ! [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]]; then
    echo "$LOG_PREFIX WARNING: BACKUP_RETENTION_DAYS '$RETENTION_DAYS' is not numeric, using default 7 days"
    RETENTION_DAYS=7
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Create backup filename
BACKUP_FILE="torrust_tracker_backup_${DATE}.sql"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILE"

echo "$LOG_PREFIX Starting MySQL backup: $BACKUP_FILE"

# Check if MySQL container is running
if ! docker compose --env-file "$ENV_FILE" ps mysql | grep -q "Up"; then
    echo "$LOG_PREFIX ERROR: MySQL container is not running"
    exit 1
fi

# Create MySQL dump
echo "$LOG_PREFIX Creating database dump..."
if docker compose --env-file "$ENV_FILE" exec -T mysql mysqldump \
    -u root -p"$MYSQL_ROOT_PASSWORD" \
    --single-transaction \
    --routines \
    --triggers \
    --add-drop-database \
    --databases "$MYSQL_DATABASE" > "$BACKUP_PATH"; then
    echo "$LOG_PREFIX Database dump created successfully"
else
    echo "$LOG_PREFIX ERROR: Failed to create database dump"
    rm -f "$BACKUP_PATH"
    exit 1
fi

# Compress the backup
echo "$LOG_PREFIX Compressing backup..."
if gzip "$BACKUP_PATH"; then
    COMPRESSED_BACKUP="${BACKUP_PATH}.gz"
    echo "$LOG_PREFIX Backup compressed: $(basename "$COMPRESSED_BACKUP")"
    echo "$LOG_PREFIX Backup size: $(du -h "$COMPRESSED_BACKUP" | cut -f1)"
else
    echo "$LOG_PREFIX ERROR: Failed to compress backup"
    rm -f "$BACKUP_PATH"
    exit 1
fi

# Clean up old backups
echo "$LOG_PREFIX Cleaning up old backups (retention: $RETENTION_DAYS days)..."
OLD_BACKUPS_COUNT=$(find "$BACKUP_DIR" -name "torrust_tracker_backup_*.sql.gz" -mtime +"$RETENTION_DAYS" | wc -l)

if [[ "$OLD_BACKUPS_COUNT" -gt 0 ]]; then
    find "$BACKUP_DIR" -name "torrust_tracker_backup_*.sql.gz" -mtime +"$RETENTION_DAYS" -delete
    echo "$LOG_PREFIX Removed $OLD_BACKUPS_COUNT old backup(s)"
else
    echo "$LOG_PREFIX No old backups to remove"
fi

# Show current backup status
CURRENT_BACKUPS_COUNT=$(find "$BACKUP_DIR" -name "torrust_tracker_backup_*.sql.gz" | wc -l)
TOTAL_BACKUP_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "unknown")

echo "$LOG_PREFIX Backup completed successfully"
echo "$LOG_PREFIX Current backups: $CURRENT_BACKUPS_COUNT files, total size: $TOTAL_BACKUP_SIZE"
echo "$LOG_PREFIX Backup location: $COMPRESSED_BACKUP"
