# Phase 1: MySQL Migration Implementation Plan

## 🎯 Overview

This document outlines the detailed implementation plan for migrating from SQLite to MySQL
as the default database for the Torrust Tracker Demo deployment.

**Parent Issue**: Phase 1: Database Migration to MySQL  
**Migration Plan Reference**:
[docs/plans/hetzner-migration-plan.md](../plans/hetzner-migration-plan.md)  
**Database Choice Decision**:
[ADR-003: Use MySQL Over MariaDB](../adr/003-use-mysql-over-mariadb.md)

## 📋 Implementation Steps

### Step 1: MySQL Service Configuration

**File**: `application/compose.yaml`

**Changes Required**:

- Add MySQL service definition to Docker Compose
- Configure MySQL environment variables
- Set up proper networking and volumes
- Add dependency relationships

**Implementation Details**:

```yaml
mysql:
  image: mysql:8.0
  container_name: mysql
  restart: unless-stopped
  environment:
    - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
    - MYSQL_DATABASE=${MYSQL_DATABASE}
    - MYSQL_USER=${MYSQL_USER}
    - MYSQL_PASSWORD=${MYSQL_PASSWORD}
  networks:
    - backend_network
  ports:
    - "3306:3306" # Only for debugging, remove in production
  volumes:
    - mysql_data:/var/lib/mysql
    - ./storage/mysql/init:/docker-entrypoint-initdb.d:ro
  command: --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
  logging:
    options:
      max-size: "10m"
      max-file: "10"
```

**Dependencies**:

- Update tracker service to depend on MySQL
- Ensure mysql_data volume is properly utilized

### Step 2: Environment Variables Configuration

**File**: `application/.env.production`

**Changes Required**:

- Add MySQL connection parameters
- Add tracker configuration overrides for MySQL
- Maintain backward compatibility documentation

**Implementation Details**:

```bash
# Database Configuration
MYSQL_ROOT_PASSWORD=secure_root_password_change_me
MYSQL_DATABASE=torrust_tracker
MYSQL_USER=torrust
MYSQL_PASSWORD=secure_password_change_me

# Tracker Database Configuration
TORRUST_TRACKER_CONFIG_OVERRIDE_CORE__DATABASE__DRIVER=mysql
TORRUST_TRACKER_CONFIG_OVERRIDE_CORE__DATABASE__PATH=mysql://torrust:${MYSQL_PASSWORD}@mysql:3306/torrust_tracker
```

### Step 3: Tracker Configuration Updates

**File**: `application/storage/tracker/etc/tracker.toml`

**Changes Required**:

- Update database section to use MySQL by default
- Remove SQLite-specific configurations
- Use MySQL connection string format

**Implementation Details**:

```toml
[core.database]
driver = "mysql"
path = "mysql://torrust:password_will_be_overridden_by_env@mysql:3306/torrust_tracker"
```

**Note**: Environment variables will override these default values in production.

### Step 4: MySQL Initialization Directory

**Directory**: `application/storage/mysql/init/`

**Files to Create**:

1. `README.md` - Documentation for initialization directory

**Implementation Details**:

`README.md`:

```markdown
# MySQL Initialization Directory

This directory is available for MySQL initialization scripts if needed in the future.

## Notes

- Scripts in this directory would be executed automatically by MySQL container on first startup
- The database and user are created automatically via environment variables
- **Torrust Tracker handles its own database migrations automatically**
- Database tables are created and updated by the tracker on startup
- No manual schema setup is required
```

**Important Note**: The Torrust Tracker automatically handles database migrations and table
creation. The database schema is managed by the tracker itself through its built-in
migration system in the database drivers.

### Step 5: Docker Compose Service Dependencies

**File**: `application/compose.yaml`

**Changes Required**:

- Add MySQL to tracker service dependencies
- Ensure proper startup order

**Implementation Details**:

```yaml
tracker:
  # ...existing configuration...
  depends_on:
    - mysql
  environment:
    # ...existing environment variables...
    - TORRUST_TRACKER_CONFIG_OVERRIDE_CORE__DATABASE__DRIVER=${TORRUST_TRACKER_CONFIG_OVERRIDE_CORE__DATABASE__DRIVER:-mysql}
    - TORRUST_TRACKER_CONFIG_OVERRIDE_CORE__DATABASE__PATH=${TORRUST_TRACKER_CONFIG_OVERRIDE_CORE__DATABASE__PATH:-mysql://torrust:password@mysql:3306/torrust_tracker}
```

### Step 6: Documentation Updates

**Files to Update**:

1. `application/README.md`
2. `application/docs/production-setup.md`
3. `application/docs/deployment.md` (if exists)

**Changes Required**:

- Update database requirements section
- Add MySQL setup instructions
- Document environment variables
- Add migration notes for existing SQLite users

## 🧪 Testing Strategy

### Phase 1: Local Docker Compose Testing

**Recommendation**: Test the MySQL integration locally with Docker Compose first, before
deploying to VMs. This saves time during development and avoids creating/destroying VMs
while iterating on the configuration.

**Prerequisites**:

```bash
# Ensure you're in the application directory
cd application/
```

**Local Testing Steps**:

1. **Local Service Testing**:

   ```bash
   # Stop any existing services
   docker compose down

   # Start only MySQL to test it independently
   docker compose up mysql -d

   # Verify MySQL is running
   docker compose ps
   docker compose logs mysql
   ```

2. **Full Stack Local Testing**:

   ```bash
   # Start all services with the new MySQL configuration
   docker compose up -d

   # Check all services are running
   docker compose ps

   # Check MySQL startup logs
   docker compose logs mysql

   # Check tracker connection logs
   docker compose logs tracker
   ```

   **Expected Output**:

   ```bash
   # Verify tracker is running and connected to MySQL
   docker compose logs tracker | grep "Successfully connected to database"
   ```

3. **Local Data Persistence Testing**:

   - **Status**: ✅ **Completed**
   - **Verification**: Data persists in MySQL after service restarts.

   ```bash
   # Restart services
   docker compose restart

   # Verify tables still exist in MySQL
   docker compose exec mysql mysql -u torrust -p<YOUR_PASSWORD> torrust_tracker -e "SHOW TABLES;"
   ```

4. **VM Integration Testing**:

   - **Status**: ✅ **Completed** (2025-07-08)
   - **Description**: Deploy the complete stack on a local VM to test the full
     infrastructure integration.
   - **Solution**: MySQL 8.0 x86-64-v2 CPU requirement resolved by configuring VM with
     `host-model` CPU mode to enable modern instruction sets.

   ```bash
   # From the repository root
   make apply  # Deploy VM
   make ssh    # Connect to VM
   # Run smoke tests from the smoke testing guide
   ```

   **Results**:

   - ✅ All Docker containers running successfully
   - ✅ MySQL container: `Up 48 minutes (healthy)` - no more restart loops
   - ✅ Tracker container: `Up 48 minutes (healthy)` - connected to MySQL
   - ✅ All services responding to health checks

   **Technical Solution**:

   - **Issue**: MySQL 8.0 Docker image requires x86-64-v2 CPU instruction set
   - **Fix**: Updated `infrastructure/terraform/main.tf` to use `host-model` CPU mode
   - **Result**: VM CPU now supports x86-64-v2 instructions required by MySQL 8.0

### Phase 2: Documentation and Cleanup

**Status**: ✅ **Completed** (2025-07-08)

**Description**: Update all relevant documentation to reflect the MySQL migration and
remove any outdated SQLite references.

**Files Updated**:

- ✅ `application/README.md` - Added database configuration section explaining MySQL as default
- ✅ `application/docs/production-setup.md` - Already documented MySQL properly
- ✅ `application/.env.production` - Added header comments about MySQL configuration
- ✅ `docs/guides/smoke-testing-guide.md` - No database-specific changes needed (external testing)
- ✅ `.github/copilot-instructions.md` - Already updated with smoke testing guide references

**Results**:

- All documentation now reflects MySQL as the default database
- Added clear explanations about database configuration and requirements
- Maintained references to SQLite as a development/testing option
- Updated environment file with clear MySQL configuration comments
- Legacy SQLite configuration files preserved for reference and rollback scenarios

## ✅ Completion Checklist

- [x] MySQL service added to `compose.yaml`
- [x] Environment variables configured in `.env.production`
- [x] Tracker `tracker.toml` defaults to MySQL
- [x] MySQL initialization directory documented
- [x] Docker Compose service dependencies updated
- [x] Local functionality testing passed
- [x] Local data persistence testing passed
- [x] VM integration testing passed
- [x] All documentation updated
- [x] Old SQLite configurations documented as legacy
- [ ] Final PR reviewed and approved

## Rollback Plan

If critical issues arise, the following steps can be taken to revert to SQLite:

1. **Revert `compose.yaml`**: Remove the MySQL service and dependencies.
2. **Revert `.env.production`**: Restore SQLite environment variables.
3. **Revert `tracker.toml`**: Set the database driver back to `sqlite3`.
4. **Restart Services**: Run `docker compose up -d --force-recreate`.

This ensures a quick rollback path if the MySQL integration causes unforeseen problems.
