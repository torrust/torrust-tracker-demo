# Database Backup Testing Guide

This guide explains how to manually test the MySQL database backup automation for the
Torrust Tracker Demo project locally.

## Overview

The database backup automation creates compressed MySQL dumps on a scheduled basis with
automatic cleanup and comprehensive logging. This guide walks through testing the complete
backup workflow from configuration to validation.

## Prerequisites

- Local testing environment set up (see [Quick Start Guide](../infrastructure/quick-start.md))
- VM deployed with backup automation enabled
- SSH access to the deployed VM

## Testing Workflow

### Step 1: Enable Backup Automation

#### 1.1 Configure Environment Files

Enable backups in the local environment configuration:

```bash
# Edit the local environment file
vim infrastructure/config/environments/local.env

# Set backup configuration
ENABLE_DB_BACKUPS=true
BACKUP_RETENTION_DAYS=3
```

#### 1.2 Update Environment Defaults

Also update the defaults file to ensure configuration processing works correctly:

```bash
# Edit the local defaults file
vim infrastructure/config/environments/local.defaults

# Update backup settings
BACKUP_DESCRIPTION=" (enabled for testing backup automation)"
ENABLE_DB_BACKUPS="true"
```

### Step 2: Deploy Infrastructure and Application

Deploy the VM with backup automation enabled:

```bash
# Deploy infrastructure
make infra-apply

# Deploy application with backup automation
make app-deploy
```

**Expected Result**: Deployment logs should show:

```text
[INFO] Backup configuration: Enabled with 3 days retention
[INFO] Setting up automated database backups...
[INFO] Installing MySQL backup cron job
```

### Step 3: Copy Backup Script (Development Testing)

**Note**: This step is only needed during development when the backup script hasn't been
committed yet.

```bash
# Copy the backup script to the VM
VM_IP=$(make infra-status | grep vm_ip | cut -d'"' -f2)
scp application/share/bin/mysql-backup.sh \
    torrust@$VM_IP:/home/torrust/github/torrust/torrust-tracker-demo/application/share/bin/

# Make it executable
ssh torrust@$VM_IP \
    'chmod +x /home/torrust/github/torrust/torrust-tracker-demo/application/share/bin/mysql-backup.sh'
```

### Step 4: Validate Backup Script

#### 4.1 Test Script Syntax

```bash
ssh torrust@$VM_IP \
    'cd /home/torrust/github/torrust/torrust-tracker-demo/application &&
     bash -n share/bin/mysql-backup.sh && echo "✅ Backup script syntax is valid"'
```

#### 4.2 Test Dry-Run Execution

```bash
ssh torrust@$VM_IP \
    'cd /home/torrust/github/torrust/torrust-tracker-demo/application &&
     share/bin/mysql-backup.sh --dry-run'
```

**Expected Output**:

```text
[2025-07-29 15:44:50] Starting MySQL backup: torrust_tracker_backup_20250729_154450.sql
[2025-07-29 15:44:50] Creating database dump...
[2025-07-29 15:44:50] Database dump created successfully
[2025-07-29 15:44:50] Compressing backup...
[2025-07-29 15:44:50] Backup compressed: torrust_tracker_backup_20250729_154450.sql.gz
[2025-07-29 15:44:50] Backup size: 4.0K
[2025-07-29 15:44:50] Cleaning up old backups (retention: 3 days)...
[2025-07-29 15:44:50] No old backups to remove
[2025-07-29 15:44:50] Backup completed successfully
[2025-07-29 15:44:50] Current backups: 1 files, total size: 8.0K
[2025-07-29 15:44:50] Backup location: /var/lib/torrust/mysql/backups/torrust_tracker_backup_20250729_154450.sql.gz
```

### Step 5: Verify Backup File Creation

```bash
# Check backup directory
ssh torrust@$VM_IP 'ls -la /var/lib/torrust/mysql/backups/'
```

**Expected Result**:

```text
total 12
drwxr-xr-x 2 torrust torrust 4096 Jul 29 15:44 .
drwxr-xr-x 4 torrust torrust 4096 Jul 29 15:43 ..
-rw-rw-r-- 1 torrust torrust 1068 Jul 29 15:44 torrust_tracker_backup_20250729_154450.sql.gz
```

### Step 6: Validate Backup Content

#### 6.1 Check Backup File Structure

```bash
# Examine backup file headers
ssh torrust@$VM_IP 'cd /var/lib/torrust/mysql/backups && gunzip -c *.gz | head -20'
```

**Expected Output**: Should show MySQL dump headers with correct database name:

```text
-- MySQL dump 10.13  Distrib 8.0.43, for Linux (x86_64)
--
-- Host: localhost    Database: torrust_tracker
-- ------------------------------------------------------
-- Server version    8.0.43
```

#### 6.2 Verify Database Schema

```bash
# Check for table creation statements
ssh torrust@$VM_IP 'cd /var/lib/torrust/mysql/backups && gunzip -c *.gz | grep -A 5 "CREATE TABLE"'
```

**Expected Result**: Should show all Torrust Tracker tables:

- `keys` (API keys and authentication)
- `torrent_aggregate_metrics` (tracker statistics)
- `torrents` (tracked torrents with completion counts)
- `whitelist` (whitelisted torrents)

#### 6.3 Verify Backup Completeness

```bash
# Check backup file analysis
ssh torrust@$VM_IP 'cd /var/lib/torrust/mysql/backups &&
echo "=== Backup File Analysis ===" &&
echo "Compressed size: $(ls -lh *.gz | awk "{print \$5}" | head -1)" &&
echo "Uncompressed size: $(gunzip -c *.gz | wc -c | head -1) bytes" &&
echo "Line count: $(gunzip -c *.gz | wc -l | head -1) lines" &&
echo "Table count: $(gunzip -c *.gz | grep -c "CREATE TABLE" | head -1)"'
```

**Expected Output**:

```text
=== Backup File Analysis ===
Compressed size: 1.1K
Uncompressed size: 4563 bytes
Line count: 140 lines
Table count: 4
```

#### 6.4 Verify Database Management Statements

```bash
# Check for complete restoration capability
ssh torrust@$VM_IP \
    'cd /var/lib/torrust/mysql/backups &&
     gunzip -c *.gz | grep -E "(DROP DATABASE|CREATE DATABASE)"'
```

**Expected Output**:

```text
/*!40000 DROP DATABASE IF EXISTS `torrust_tracker`*/;
CREATE DATABASE /*!32312 IF NOT EXISTS*/ `torrust_tracker`
    /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci */
    /*!80016 DEFAULT ENCRYPTION='N' */;
```

### Step 7: Test Automated Scheduling

#### 7.1 Check Cron Job Installation

```bash
# Verify cron job is installed
ssh torrust@$VM_IP 'crontab -l'
```

**Expected Output**:

```text
# MySQL Database Backup Crontab Entry
# Runs daily at 3:00 AM as torrust user
# Output is logged to /var/log/mysql-backup.log
# Requires: torrust user in docker group (already configured via cloud-init)

0 3 * * * /home/torrust/github/torrust/torrust-tracker-demo/application/share/bin/mysql-backup.sh \
    >> /var/log/mysql-backup.log 2>&1
```

#### 7.2 Test Rapid Execution (Optional)

For testing purposes, you can temporarily modify the cron job to run every minute:

```bash
# Modify cron to run every minute (FOR TESTING ONLY)
ssh torrust@$VM_IP 'crontab -l | sed "s/0 3 \* \* \*/\* \* \* \* \*/" | crontab -'

# Verify the change
ssh torrust@$VM_IP 'crontab -l'
```

#### 7.3 Monitor Automated Execution

```bash
# Create log file with proper permissions
ssh torrust@$VM_IP \
    'sudo touch /var/log/mysql-backup.log && sudo chown torrust:torrust /var/log/mysql-backup.log'

# Wait for automated execution (if using every-minute schedule)
sleep 90

# Check for new backup files
ssh torrust@$VM_IP 'ls -la /var/lib/torrust/mysql/backups/'
```

**Expected Result**: New backup files should appear with timestamps corresponding to cron
execution times.

#### 7.4 Verify Automated Execution Logs

```bash
# Check backup execution logs
ssh torrust@$VM_IP 'cat /var/log/mysql-backup.log'
```

**Expected Output**: Should show successful backup executions with timestamps.

#### 7.5 Reset Cron Schedule

**Important**: Reset the cron schedule back to daily after testing:

```bash
# Reset to daily schedule
ssh torrust@$VM_IP 'crontab -l | sed "s/\* \* \* \* \*/0 3 \* \* \*/" | crontab -'

# Verify the reset
ssh torrust@$VM_IP 'crontab -l'
```

### Step 8: Test Retention and Cleanup

#### 8.1 Create Multiple Backups

For testing retention, you can create several backup files with different timestamps:

```bash
# Run backup script multiple times
ssh torrust@$VM_IP 'cd /home/torrust/github/torrust/torrust-tracker-demo/application &&
for i in {1..5}; do
    share/bin/mysql-backup.sh
    sleep 1
done'
```

#### 8.2 Test Retention Logic

```bash
# Check backup count
ssh torrust@$VM_IP \
    'find /var/lib/torrust/mysql/backups -name "torrust_tracker_backup_*.sql.gz" | wc -l'

# Simulate old backups (for retention testing)
# Note: In production, files older than BACKUP_RETENTION_DAYS are automatically removed
```

## Validation Checklist

Use this checklist to verify backup automation is working correctly:

### ✅ Configuration

- [ ] `ENABLE_DB_BACKUPS=true` in environment configuration
- [ ] `BACKUP_RETENTION_DAYS` set to desired value
- [ ] Deployment logs show backup automation enabled

### ✅ Script Functionality

- [ ] Backup script syntax is valid
- [ ] Dry-run execution completes successfully
- [ ] Backup files are created in correct location
- [ ] File permissions are correct (torrust user ownership)

### ✅ Backup Content

- [ ] Backup files contain MySQL dump headers
- [ ] All 4 Torrust Tracker tables present
- [ ] Database DROP/CREATE statements included
- [ ] Compression working (files have .gz extension)
- [ ] Reasonable file sizes (~1KB compressed, ~4KB uncompressed)

### ✅ Automation

- [ ] Cron job installed correctly
- [ ] Scheduled execution produces new backup files
- [ ] Logs show successful execution
- [ ] Retention cleanup working (when applicable)

### ✅ Error Handling

- [ ] Script fails gracefully when MySQL is down
- [ ] Environment validation catches missing variables
- [ ] Cleanup removes partial backups on failure

## Troubleshooting

### Common Issues

#### Backup Script Not Found

**Symptom**: `bash: share/bin/mysql-backup.sh: No such file or directory`

**Solution**: The script wasn't included in the git archive deployment. Copy it manually:

```bash
scp application/share/bin/mysql-backup.sh \
    torrust@$VM_IP:/home/torrust/github/torrust/torrust-tracker-demo/application/share/bin/
```

#### Permission Denied

**Symptom**: Script execution fails with permission errors

**Solution**: Ensure script is executable:

```bash
ssh torrust@$VM_IP \
    'chmod +x /home/torrust/github/torrust/torrust-tracker-demo/application/share/bin/mysql-backup.sh'
```

#### MySQL Container Not Running

**Symptom**: `ERROR: MySQL container is not running`

**Solution**: Check Docker Compose services:

```bash
ssh torrust@$VM_IP \
    'cd /home/torrust/github/torrust/torrust-tracker-demo/application && docker compose ps'
```

#### Environment Variables Missing

**Symptom**: `ERROR: MYSQL_ROOT_PASSWORD not set in environment`

**Solution**: Verify environment file exists and contains required variables:

```bash
ssh torrust@$VM_IP 'cat /var/lib/torrust/compose/.env | grep MYSQL'
```

#### Cron Job Not Running

**Symptom**: No automated backup files created

**Solution**: Check cron service and logs:

```bash
ssh torrust@$VM_IP 'sudo systemctl status cron'
ssh torrust@$VM_IP 'sudo grep CRON /var/log/syslog | tail -10'
```

## Cleanup

After testing, clean up the test environment:

```bash
# Destroy the VM
make infra-destroy

# Reset local configuration if needed
git checkout infrastructure/config/environments/local.env
git checkout infrastructure/config/environments/local.defaults
```

## Production Notes

- In production, backups run daily at 3:00 AM
- Retention period is configurable via `BACKUP_RETENTION_DAYS`
- Backups are compressed to save disk space
- All operations are logged to `/var/log/mysql-backup.log`
- The script requires the torrust user to be in the docker group (configured automatically
  via cloud-init)

## Next Steps

After validating backup automation:

1. Commit backup automation implementation
2. Update production deployment documentation
3. Configure monitoring for backup failures
4. Test backup restoration procedures
5. Implement SSL automation (next phase of Issue #21)

This testing guide ensures the MySQL backup automation is working correctly before
deploying to production environments.
