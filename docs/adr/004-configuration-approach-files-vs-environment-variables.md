# ADR-004: Configuration Approach - Files vs Environment Variables

## Status

Accepted

## Context

As part of the 12-Factor App refactoring (Phase 1), we need to decide how to handle
application configuration for the Torrust Tracker Demo. There are two primary approaches:

1. **File-based configuration**: Store configuration in template-generated files
   (e.g., `tracker.toml`)
2. **Environment variable configuration**: Use environment variables for all
   configuration values

Both approaches have trade-offs in terms of maintainability, deployment complexity,
and operational flexibility.

## Decision

We will use a **hybrid approach** that prioritizes file-based configuration with
selective use of environment variables:

### File-based Configuration (Primary)

- Application behavior settings
- Port configurations
- Policy settings (timeouts, intervals, etc.)
- Feature flags (listed, private, stats enabled)
- Non-sensitive defaults

### Environment Variables (Secondary - Secrets & Environment-Specific Only)

- Database credentials and connection strings
- API tokens and authentication secrets
- SSL certificates and keys
- External IP addresses
- Domain names
- Infrastructure-specific settings

## Rationale

### Why File-based Configuration is Better for This Project

#### 1. Project Scope and Purpose

This repository is designed as an **automated installer/deployment tool** rather
than a cloud-native, horizontally scalable application. The primary goal is to:

- Deploy a single Torrust Tracker instance
- Provide infrastructure automation
- Enable easy manual maintenance post-deployment

#### 2. Operational Advantages

- **Easier maintenance**: Administrators can modify `tracker.toml` and restart the
  service without recreating containers
- **Direct access**: System administrators can edit configuration files directly
  on the server
- **Faster iteration**: Configuration changes don't require container recreation,
  only service restart
- **Simpler troubleshooting**: All non-secret configuration is visible in
  human-readable files

#### 3. Deployment Simplicity

- **Fewer environment variables**: Reduces complexity in Docker Compose and
  deployment scripts
- **Cleaner compose.yaml**: Environment sections remain minimal and focused on secrets
- **Reduced coupling**: Application configuration is decoupled from container
  orchestration

#### 4. Administrative Experience

- **Familiar patterns**: System administrators expect to find configuration in files
  like `/etc/torrust/tracker/tracker.toml`
- **Documentation alignment**: Configuration files can be documented and versioned
  alongside code
- **Backup friendly**: Configuration files are easier to backup and restore as part
  of standard system administration

### When Environment Variables Are Appropriate

#### 1. Secrets Management

```bash
# Database credentials
MYSQL_ROOT_PASSWORD=secret_password
MYSQL_PASSWORD=user_password

# API authentication
TRACKER_ADMIN_TOKEN=admin_token_123

# Grafana admin credentials
GF_SECURITY_ADMIN_PASSWORD=secure_password
```

#### 2. Environment-Specific Values

```bash
# Network configuration that varies by deployment
EXTERNAL_IP=192.168.1.100
DOMAIN_NAME=tracker.example.com

# Infrastructure differences
ON_REVERSE_PROXY=true
LOG_LEVEL=info
```

#### 3. Container Runtime Configuration

```bash
# Docker-specific settings
USER_ID=1000
MYSQL_DATABASE=torrust_tracker
```

## Implementation Examples

### **File-based Configuration** (`tracker.toml`)

```toml
[metadata]
app = "torrust-tracker"
purpose = "configuration"
schema_version = "2.0.0"

[logging]
threshold = "debug"  # Environment-specific value

[core]
inactive_peer_cleanup_interval = 600
listed = false
private = false
tracker_usage_statistics = true

[core.announce_policy]
interval = 120
interval_min = 120

[core.database]
driver = "mysql"
# URL set via environment variable at runtime
url = ""

[core.net]
external_ip = "0.0.0.0"
on_reverse_proxy = false  # Environment-specific value

[core.tracker_policy]
max_peer_timeout = 900
persistent_torrent_completed_stat = false
remove_peerless_torrents = true

# Admin token set via environment variable at runtime
[http_api.access_tokens]
# admin = ""

[[udp_trackers]]
bind_address = "0.0.0.0:6868"

[[udp_trackers]]
bind_address = "0.0.0.0:6969"

[[http_trackers]]
bind_address = "0.0.0.0:7070"
```

### **Environment Variables** (`.env`)

```bash
# Secrets only
MYSQL_ROOT_PASSWORD=secret_root_password
MYSQL_PASSWORD=secret_user_password
TRACKER_ADMIN_TOKEN=admin_secret_token

# Docker runtime
USER_ID=1000
MYSQL_DATABASE=torrust_tracker
MYSQL_USER=torrust

# Grafana admin
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=admin_password
```

## Benefits

### **For System Administrators**

- Configuration changes are made in familiar file locations
- No need to understand Docker environment variable injection
- Standard Unix administration patterns apply
- Easy to backup and restore configurations

### **For Developers**

- Cleaner separation of concerns
- Fewer template variables to manage
- Simpler Docker Compose files
- Easier testing and validation

### **For Operations**

- Faster configuration updates (restart vs recreate)
- Better debugging capabilities
- Standard logging and monitoring patterns
- Familiar deployment patterns

## Trade-offs

### **What We Give Up**

- **Cloud-native patterns**: Less suitable for Kubernetes or other orchestrators
- **Dynamic reconfiguration**: Cannot change configuration without file access
- **Secret injection**: Some secrets still appear in config files (but only connection
  strings, not raw credentials)

### **What We Gain**

- **Operational simplicity**: Standard system administration patterns
- **Deployment reliability**: Fewer moving parts in the deployment process
- **Administrative control**: Direct access to configuration without container knowledge
- **Performance**: No environment variable processing overhead

## Exceptions

### **Prometheus Configuration**

Prometheus does not support runtime environment variable substitution in its configuration
files. Therefore, API tokens for scraping Torrust Tracker metrics must be embedded in
the `prometheus.yml` file during template generation:

```yaml
scrape_configs:
  - job_name: "torrust-tracker-stats"
    static_configs:
      - targets: ["tracker:1212"]
    metrics_path: "/api/v1/stats"
    params:
      token: ["admin_token_123"] # Token embedded at generation time
      format: ["prometheus"]
```

This is an acceptable exception because:

- Prometheus config files are not typically edited by administrators
- The token is only for internal monitoring within the Docker network
- The configuration is regenerated when environment changes

## Consequences

### **Configuration Management Process**

1. **Environment-specific values**: Set in `infrastructure/config/environments/{environment}.env`
2. **Template processing**: Generate config files using `configure-env.sh`
3. **Validation**: Validate generated configurations using `validate-config.sh`
4. **Deployment**: Deploy with file-based configurations

### **Maintenance Workflow**

1. **For secrets**: Update `.env` file and restart containers
2. **For behavior**: Edit `tracker.toml` and restart tracker service
3. **For infrastructure**: Update templates and regenerate configurations

### **Future Considerations**

- If the project evolves toward cloud-native deployment, this decision can be revisited
- Environment variable overrides can be added later without breaking existing deployments
- The hybrid approach provides flexibility for future architectural changes

## Alternatives Considered

### **Full Environment Variable Approach**

- **Pros**: Cloud-native, 12-factor compliant, dynamic configuration
- **Cons**: Complex Docker Compose, harder maintenance, container recreation required

### **Full File-based Approach**

- **Pros**: Maximum simplicity, traditional Unix patterns
- **Cons**: Secrets in files, harder automation, less secure

### **External Configuration Service**

- **Pros**: Centralized management, audit trails, dynamic updates
- **Cons**: Additional infrastructure, complexity overkill for single-instance deployment

## Related Decisions

- [ADR-002: Docker for All Services](002-docker-for-all-services.md) - Establishes container-based deployment
- [ADR-003: Use MySQL Over MariaDB](003-use-mysql-over-mariadb.md) - Database choice
  affects connection configuration

## References

- [The Twelve-Factor App](https://12factor.net/config)
- [Torrust Tracker Configuration Documentation](https://docs.rs/torrust-tracker)
- [Docker Compose Environment Variables](https://docs.docker.com/compose/environment-variables/)
