#!/bin/bash

# Backup the Index SQLite database

# Define the directory where backups will be stored
BACKUP_DIR="/home/torrust/backups"

# Define the SQLite database file's path
DATABASE_FILE="/home/torrust/github/torrust/torrust-demo/storage/index/lib/database/sqlite3.db"

# Create a timestamped backup filename
BACKUP_FILE="$BACKUP_DIR/backup_$(date +%Y-%m-%d_%H-%M-%S).db"

# Copy the SQLite database file to create a backup
cp $DATABASE_FILE "$BACKUP_FILE"

# Find and remove backups older than 7 days
find $BACKUP_DIR -type f -name "backup_*.db" -mtime +7 -exec rm -f {} \;

