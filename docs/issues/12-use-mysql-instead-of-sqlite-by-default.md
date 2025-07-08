# Phase 1: MySQL Migration Implementation Plan

## 🎯 Overview

This document outlines the detailed implementation plan for migrating from SQLite to MySQL
as the default database for the Torrust Tracker Demo deployment.

**Parent Issue**: Phase 1: Database Migration to MySQL  
**Migration Plan Reference**: [docs/plans/hetzner-migration-plan.md](../plans/hetzner-migration-plan.md)

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

3. **Local Functionality Testing**:

   ```bash
   # Test tracker announce functionality locally
   curl -v "http://localhost:7070/announce?info_hash=1234567890123456789012345678901234567890&peer_id=1234567890123456789&port=6881&uploaded=0&downloaded=0&left=1000&event=started"

   # Connect to MySQL and verify data
   docker compose exec mysql mysql -u torrust -p torrust_tracker
   # Check if tables were created automatically by tracker
   ```

4. **Local Data Persistence Testing**:

   ```bash
   # Make announce request, restart services, verify data persists
   docker compose restart tracker
   docker compose restart mysql

   # Verify data is still there
   docker compose exec mysql mysql -u torrust -p torrust_tracker -e "SHOW TABLES;"
   ```

### Phase 2: VM Integration Testing

**Prerequisites**:

```bash
# Ensure local testing environment is ready
make test-prereq
```

**VM Testing Steps**:

1. **Clean Deployment Test**:

   ```bash
   make destroy  # Clean any existing VMs
   make apply    # Deploy with new MySQL configuration
   ```

2. **Service Health Check**:

   ```bash
   make ssh
   cd /home/torrust/github/torrust/torrust-tracker-demo
   docker compose ps  # Verify all services are running
   docker compose logs mysql  # Check MySQL startup logs
   docker compose logs tracker  # Check tracker connection logs
   ```

3. **Database Connectivity Test**:

   ```bash
   # Connect to MySQL and verify database exists
   docker compose exec mysql mysql -u torrust -p torrust_tracker
   # Should connect successfully and show database with tracker tables
   ```

4. **Functional Testing**:

   ```bash
   # Test tracker announce functionality
   curl -v "http://localhost:7070/announce?info_hash=1234567890123456789012345678901234567890&peer_id=1234567890123456789&port=6881&uploaded=0&downloaded=0&left=1000&event=started"
   ```

5. **Data Persistence Test**:

   ```bash
   # Make announce request, restart services, verify data persists
   docker compose restart tracker
   # Check if torrent data is still in MySQL
   ```

### Validation Checklist

- [ ] **MySQL Service**:

  - [ ] MySQL container starts successfully
  - [ ] Database `torrust_tracker` is created
  - [ ] User `torrust` can connect with provided credentials
  - [ ] Character set is `utf8mb4` with `utf8mb4_unicode_ci` collation

- [ ] **Tracker Service**:

  - [ ] Tracker connects to MySQL without errors
  - [ ] Tracker logs show successful database connection
  - [ ] Database tables are created automatically by tracker
  - [ ] No SQLite-related errors in logs

- [ ] **Functional Testing**:

  - [ ] Announce requests work correctly
  - [ ] Data is written to MySQL tables (automatically created)
  - [ ] Scrape requests return correct data
  - [ ] Download counters increment properly

- [ ] **Integration Testing**:

  - [ ] Grafana can access tracker metrics
  - [ ] Prometheus monitoring continues to work
  - [ ] Nginx proxy serves tracker API correctly

- [ ] **Persistence Testing**:

  - [ ] Data survives tracker service restart
  - [ ] Data survives MySQL service restart
  - [ ] Data survives complete stack restart
  - [ ] Database schema is maintained across restarts

## 🔄 Implementation Order

### Phase A: Service Configuration (No Breaking Changes)

1. Add MySQL service to `compose.yaml`
2. Create MySQL initialization directory and README
3. Update environment variables in `.env.production`
4. Test MySQL service starts independently (local Docker Compose)

### Phase B: Tracker Integration (Local Testing)

1. Update tracker configuration in `tracker.toml`
2. Add tracker environment variable overrides
3. Update service dependencies
4. **Test complete stack deployment locally with Docker Compose**
5. Verify database tables are created automatically by tracker
6. Validate announce/scrape functionality locally

### Phase C: VM Integration Testing

1. Deploy to VM using `make apply`
2. Run comprehensive testing on VM environment
3. Validate against all acceptance criteria
4. Document any differences between local and VM environments

### Phase D: Documentation and Finalization

1. Update documentation files
2. Document local vs VM testing procedures
3. Create troubleshooting guide
4. Document any migration notes

## 📁 File Change Summary

```text
application/
├── compose.yaml                     # Add MySQL service, update tracker deps
├── .env.production                  # Add MySQL environment variables
├── storage/
│   ├── tracker/
│   │   └── etc/
│   │       └── tracker.toml        # Update database configuration
│   └── mysql/                      # New directory
│       └── init/                   # New directory
│           └── README.md           # New file (documentation only)
├── README.md                       # Update database requirements
└── docs/
    ├── production-setup.md         # Add MySQL setup instructions
    └── deployment.md               # Update deployment procedures
```

**Note**: No SQL migration scripts needed - Torrust Tracker handles database migrations automatically.

## 🔍 Pre-Implementation Research

### Torrust Tracker MySQL Requirements

**Research Completed**:

- ✅ Torrust Tracker MySQL driver support confirmed
- ✅ MySQL connection string format: `mysql://user:password@host:port/database`
- ✅ Configuration uses single `path` parameter, not individual connection fields
- ✅ Database migrations are handled automatically by tracker

**Key Findings**:

1. **Automatic Migrations**: Torrust Tracker handles database migrations automatically
   through built-in migration system in database drivers
2. **Connection Format**: Uses MySQL connection string in `path` field
3. **Table Creation**: Tables are created automatically on tracker startup
4. **No Manual Setup**: No manual schema setup or migration scripts required

### Environment Variable Validation

**Research Tasks**:

- [ ] Verify exact environment variable names used by Torrust Tracker
- [ ] Test environment variable override behavior with connection string format
- [ ] Confirm configuration precedence (file vs environment)

## 🚨 Risk Assessment

### High Risk Items

- **Database connection failures**: Ensure proper networking between services
- **Character set issues**: UTF-8 handling for torrent names and peer data
- **Environment variable conflicts**: Ensure no conflicting configurations

### Medium Risk Items

- **Performance differences**: MySQL vs SQLite performance characteristics
- **Volume permissions**: Ensure MySQL data directory has correct permissions
- **Service startup timing**: MySQL must be ready before tracker starts

### Low Risk Items

- **Documentation gaps**: Missing or unclear setup instructions
- **Development environment differences**: Local vs production environment parity

## 🎯 Success Criteria

### Must Have

- [ ] MySQL service starts and is accessible
- [ ] Tracker connects to MySQL successfully
- [ ] Basic announce/scrape functionality works
- [ ] Data persists across service restarts
- [ ] All existing functionality continues to work

### Should Have

- [ ] Performance is equivalent to SQLite
- [ ] Comprehensive documentation is updated
- [ ] Migration path from SQLite is documented
- [ ] Local testing environment works reliably

### Nice to Have

- [ ] Database monitoring via Grafana
- [ ] Automated database backup considerations
- [ ] Performance optimization notes

## 📚 References

- [Torrust Tracker Documentation](https://docs.rs/torrust-tracker/)
- [Torrust Tracker MySQL Configuration Example](https://github.com/torrust/torrust-tracker/blob/develop/share/default/config/tracker.container.mysql.toml)
- [Torrust Tracker MySQL Driver Source](https://github.com/torrust/torrust-tracker/blob/develop/packages/tracker-core/src/databases/driver/mysql.rs)
- [MySQL 8.0 Documentation](https://dev.mysql.com/doc/refman/8.0/en/)
- [Docker Compose Networking](https://docs.docker.com/compose/networking/)
- [Migration Plan](../plans/hetzner-migration-plan.md)
