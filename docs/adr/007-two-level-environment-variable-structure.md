# ADR-007: Two-Level Environment Variable Structure

## Status

Accepted

## Context

As part of implementing twelve-factor app methodology, we need a clear approach for
managing environment variables throughout the deployment process. The system has
evolved to use a two-level environment variable structure that serves different
purposes and security requirements.

Currently, the project uses environment variables at two distinct levels:

1. **Main Environment Variables**: Used for the entire deployment process
2. **Docker Compose Environment Variables**: Used only for running containers

This separation has emerged organically but lacks clear documentation, leading to
potential confusion about where variables should be defined and how they flow
through the system.

## Decision

We will formalize and document a **two-level environment variable structure**
with clear separation of concerns:

### Level 1: Main Environment Variables

**Purpose**: Complete deployment configuration  
**Location**: `infrastructure/config/environments/`  
**Examples**: `local.env`, `production.env`  
**Scope**: All deployment processes

**Contents**:

- Infrastructure configuration (VM specs, network settings)
- SSL certificate configuration (domains, Let's Encrypt email)
- Database credentials and connection parameters
- Application API tokens and secrets
- Backup and monitoring configuration
- Build and deployment automation settings

**Usage**:

- Sourced by deployment scripts (`provision-infrastructure.sh`, `deploy-app.sh`)
- Used for template rendering (cloud-init, configuration files)
- Contains variables for infrastructure operations (SSL generation, backups)
- Includes variables that containers never need to see

### Level 2: Docker Compose Environment Variables

**Purpose**: Container runtime configuration  
**Template**: `infrastructure/config/templates/docker-compose.env.tpl`  
**Generated File**: `.env` (in application directory)  
**Scope**: Docker Compose and running containers only

**Contents** (filtered subset from Level 1):

- Database connection strings for application containers
- Application API tokens needed by running services
- Docker runtime configuration (USER_ID)
- Service-specific configuration (Grafana admin credentials)
- Container environment overrides

**Filtering Criteria**:

- **Include**: Variables directly used by containerized applications
- **Exclude**: Infrastructure-only variables (SSL domains, backup settings)
- **Exclude**: Build-time variables not needed at runtime
- **Security**: Minimize attack surface by only exposing necessary variables

## Template Transformation Process

```text
Level 1: Main Environment Variables
├── infrastructure/config/environments/local.env.tpl
├── infrastructure/config/environments/production.env.tpl
└── (user creates) local.env or production.env
                    │
                    ▼ (template processing)
Level 2: Docker Environment Variables
├── infrastructure/config/templates/docker-compose.env.tpl
└── (generated) application/.env
```

**Processing Flow**:

1. User creates environment file from template (e.g., `local.env`)
2. Deployment script sources the main environment file
3. Template processor generates `docker-compose.env` from template
4. Docker Compose uses the generated `.env` file for container variables

## Rationale

### Security Benefits

- **Principle of Least Privilege**: Containers only receive variables they need
- **Reduced Attack Surface**: Infrastructure secrets not exposed to application containers
- **Separation of Concerns**: Infrastructure and application secrets handled differently

### Operational Benefits

- **Clear Responsibility**: Infrastructure variables vs. application variables
- **Easier Debugging**: Know where to look for specific types of configuration
- **Template Flexibility**: Can generate different container environments from same base config
- **Deployment Isolation**: Infrastructure operations don't leak sensitive data to containers

### Examples

**Level 1 Only (Infrastructure Variables)**:

```bash
# SSL configuration (not needed in containers)
SSL_DOMAIN="tracker.example.com"
SSL_EMAIL="admin@example.com"
ENABLE_SSL_AUTOMATION="true"

# Backup configuration (not needed in containers)
ENABLE_DB_BACKUPS="true"
BACKUP_RETENTION_DAYS="30"

# Infrastructure specifications (not needed in containers)
VM_MEMORY="4096"
VM_VCPUS="4"
```

**Level 2 (Container Variables - Filtered from Level 1)**:

```bash
# Database connection (needed by tracker container)
MYSQL_ROOT_PASSWORD="secure_root_password"
MYSQL_PASSWORD="secure_user_password"
TORRUST_TRACKER_CONFIG_OVERRIDE_CORE__DATABASE__PATH="mysql://torrust:${MYSQL_PASSWORD}@mysql:3306/torrust_tracker"

# API tokens (needed by application)
TRACKER_ADMIN_TOKEN="secure_api_token"

# Runtime configuration (needed by containers)
USER_ID="1000"
```

## Implementation Guidelines

### For Infrastructure Scripts

```bash
# Source the main environment file
source "infrastructure/config/environments/${ENVIRONMENT}.env"

# Use all variables for infrastructure operations
generate_ssl_certificates "$SSL_DOMAIN" "$SSL_EMAIL"
configure_backups "$ENABLE_DB_BACKUPS" "$BACKUP_RETENTION_DAYS"
```

### For Template Processing

```bash
# Generate Docker environment file from template
envsubst < "infrastructure/config/templates/docker-compose.env.tpl" > "application/.env"
```

### For Container Configuration

```bash
# Docker Compose command (in deploy-app.sh)
docker compose --env-file /var/lib/torrust/compose/.env up -d

# The .env file contains only container-relevant variables
# and is passed to Docker Compose via the --env-file flag
```

## Benefits

1. **Security**: Reduced container attack surface
2. **Clarity**: Clear separation between infrastructure and application concerns
3. **Maintainability**: Easier to understand what variables are used where
4. **Flexibility**: Can generate different container environments from same base
5. **Compliance**: Aligns with twelve-factor configuration principles
6. **Debugging**: Easier to troubleshoot configuration issues

## Trade-offs

### Accepted Complexity

- **Two Files to Maintain**: Requires keeping template and source in sync
- **Template Processing**: Additional step in deployment process
- **Learning Curve**: Contributors must understand the two-level structure

### Mitigated Risks

- **Template Drift**: Validation scripts check template consistency
- **Missing Variables**: Docker Compose will fail fast if required variables are missing
- **Documentation**: This ADR and inline comments clarify the structure

## Consequences

### For Contributors

- Must understand which level to modify for different types of changes
- Infrastructure changes: Edit main environment templates
- Container configuration: Edit Docker environment template
- New variables: Consider which level(s) need the variable

### For Deployment

- All deployment scripts use Level 1 (main environment)
- Docker Compose only sees Level 2 (filtered environment)
- Template processing is automatic during deployment
- No manual synchronization required

### For Security

- Infrastructure secrets isolated from application containers
- Container compromise doesn't expose infrastructure configuration
- Easier security auditing of container-exposed variables

## Alternative Considered

**Single-Level Environment Variables**: Using one environment file for everything.

**Rejected because**:

- Security: All variables exposed to containers
- Complexity: Difficult to determine which variables containers actually need
- Maintenance: Changes to infrastructure configuration could affect containers unnecessarily

## References

- [Twelve-Factor App: Config](https://12factor.net/config)
- [ADR-004: Configuration Approach](./004-configuration-approach-files-vs-environment-variables.md)
- [Docker Compose Environment Variables](https://docs.docker.com/compose/environment-variables/)
