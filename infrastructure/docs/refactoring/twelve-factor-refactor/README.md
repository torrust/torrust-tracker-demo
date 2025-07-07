# Twelve-Factor App Refactoring Plan for Torrust Tracker Demo

## Executive Summary

This document outlines a comprehensive plan to refactor the Torrust Tracker
Demo repository to follow
[The Twelve-Factor App](https://12factor.net/) methodology while maintaining
the current local testing environment and preparing for multi-cloud production
deployments (starting with Hetzner).

## Current State Analysis

### Current Architecture

- **VM Provisioning**: Cloud-init + OpenTofu/Terraform (local KVM/libvirt)
- **Application Deployment**: Manual post-provisioning via `test-integration.sh`
- **Configuration**: Mixed approach with Docker containers and environment
  variables
- **Services**: Tracker, Prometheus, Grafana via Docker Compose
- **Environment Management**: Basic `.env.production` file

### Torrust Tracker Specific Considerations

From the official Torrust Tracker documentation, we need to account for:

#### Configuration Requirements

- **Multiple Database Drivers**: SQLite (development) and MySQL (production)
- **Service Components**: HTTP tracker, UDP tracker, and REST API
- **Port Configuration**: UDP (6868, 6969), HTTP (7070), API (1212)
- **Authentication**: Time-bound keys and access tokens
- **Performance Optimization**: Network tuning for BitTorrent traffic

#### Deployment Modes

- **Private Mode**: Requires authentication keys for tracker access
- **Public Mode**: Open tracker without authentication
- **Whitelisted Mode**: Only specific torrents allowed

#### Docker vs Source Compilation

- **Current**: Using Docker images (torrust/tracker:develop)
- **Future Plans**: Considering source compilation for production performance optimization
- **Dependencies**: pkg-config, libssl-dev, make, build-essential, libsqlite3-dev
- **Demo Repository Decision**: Uses Docker for all services to prioritize simplicity,
  consistency, and frequent updates over peak performance
  (see [ADR-002](../../../docs/adr/002-docker-for-all-services.md))

### Twelve-Factor Violations Identified

<!-- markdownlint-disable MD013 -->

| Factor                   | Current Issue                                                   | Impact |
| ------------------------ | --------------------------------------------------------------- | ------ |
| **I. Codebase**          | ✅ Good - Single repo with multiple environments                | None   |
| **II. Dependencies**     | ⚠️ Partial - Dependencies in cloud-init, not isolated           | Medium |
| **III. Config**          | ❌ Config mixed in files and env vars, not environment-specific | High   |
| **IV. Backing Services** | ✅ Good - Services are attachable resources                     | None   |
| **V. Build/Release/Run** | ❌ No clear separation, deployment mixed with infrastructure    | High   |
| **VI. Processes**        | ✅ Good - Stateless application processes                       | None   |
| **VII. Port Binding**    | ✅ Good - Services export via port binding                      | None   |
| **VIII. Concurrency**    | ✅ Good - Can scale via process model                           | None   |
| **IX. Disposability**    | ⚠️ Partial - VMs not quickly disposable due to app coupling     | Medium |
| **X. Dev/Prod Parity**   | ❌ Local and production have different deployment paths         | High   |
| **XI. Logs**             | ✅ Good - Docker logging configured                             | None   |
| **XII. Admin Processes** | ⚠️ Partial - No clear admin process separation                  | Low    |

<!-- markdownlint-enable MD013 -->

## Target Architecture

### Core Principles

1. **Infrastructure ≠ Application**: Clean separation of concerns
2. **Environment Parity**: Same deployment process for local/staging/production
3. **Configuration as Environment**: All config via environment variables
4. **Immutable Infrastructure**: VMs are cattle, not pets
5. **Deployment Pipeline**: Clear build → release → run stages

### High-Level Architecture

The refactored architecture will separate infrastructure provisioning from
application deployment, ensuring twelve-factor compliance while maintaining
the flexibility to deploy to multiple cloud providers.

## Refactoring Plan

### Phase 1: Foundation & Configuration (Weeks 1-2)

**Objective**: Establish twelve-factor configuration and deployment foundation

#### 1.1 Configuration Management Refactor

- Create environment-specific configuration structure
- Implement strict environment variable configuration
- Remove hardcoded configuration from cloud-init

#### 1.2 Deployment Separation

- Extract application deployment from infrastructure provisioning
- Create dedicated deployment scripts
- Implement configuration injection mechanism

#### 1.3 Environment Standardization

- Standardize local, staging, and production environments
- Create environment-specific variable files
- Implement configuration validation

### Phase 2: Build/Release/Run Separation (Weeks 3-4)

**Objective**: Implement clear separation of build, release, and run stages

#### 2.1 Build Stage

- Infrastructure provisioning only
- Base system preparation
- Dependency installation

#### 2.2 Release Stage

- Application deployment
- Configuration injection
- Service orchestration

#### 2.3 Run Stage

- Service startup
- Health checking
- Monitoring setup

### Phase 3: Multi-Cloud Preparation (Weeks 5-6)

**Objective**: Prepare for Hetzner and future cloud provider support

#### 3.1 Cloud Abstraction

- Provider-agnostic configuration
- Modular infrastructure components
- Environment-specific provider configs

#### 3.2 Deployment Orchestration

- Unified deployment interface
- Provider-specific implementations
- Configuration templating

### Phase 4: Operational Excellence (Weeks 7-8)

**Objective**: Implement production-ready operational practices

#### 4.1 Monitoring & Observability

- Health check standardization
- Logging standardization
- Metrics collection

#### 4.2 Maintenance & Updates

- Rolling deployment capability
- Backup procedures
- Disaster recovery

## Implementation Details

### Directory Structure Changes

```text
torrust-tracker-demo/
├── infrastructure/
│   ├── cloud-init/
│   │   ├── base-system.yaml.tpl           # Base system only
│   │   └── providers/                     # Provider-specific templates
│   │       ├── local/
│   │       ├── hetzner/
│   │       └── aws/                       # Future
│   ├── terraform/
│   │   ├── modules/                       # Reusable modules
│   │   │   ├── base-vm/
│   │   │   ├── networking/
│   │   │   └── security/
│   │   └── providers/                     # Provider configurations
│   │       ├── local/
│   │       ├── hetzner/
│   │       └── aws/                       # Future
│   ├── scripts/
│   │   ├── deploy-app.sh                  # Application deployment
│   │   ├── configure-env.sh               # Environment configuration
│   │   ├── validate-deployment.sh         # Deployment validation
│   │   └── health-check.sh               # Health checking
│   └── config/                           # Configuration templates
│       ├── environments/
│       │   ├── local.env
│       │   ├── staging.env
│       │   └── production.env
│       └── templates/
│           ├── tracker.toml.tpl
│           └── prometheus.yml.tpl
├── application/
│   ├── compose/                          # Environment-specific compose files
│   │   ├── base.yaml                     # Base services
│   │   ├── local.yaml                    # Local overrides
│   │   ├── staging.yaml                  # Staging overrides
│   │   └── production.yaml               # Production overrides
│   ├── config/                           # Application configurations
│   │   └── templates/                    # Configuration templates
│   └── scripts/                          # Application-specific scripts
└── docs/
    └── deployment/                       # Deployment documentation
        ├── local.md
        ├── staging.md
        └── production.md
```

### Configuration Strategy

#### Environment Variables Hierarchy

```text
1. System Environment Variables (highest priority)
2. .env.{environment} files
3. Default values in configuration templates
```

#### Configuration Categories

```yaml
# Infrastructure Configuration
INFRASTRUCTURE_PROVIDER: "hetzner|local|aws"
INFRASTRUCTURE_REGION: "fsn1"
INFRASTRUCTURE_INSTANCE_TYPE: "cx11"

# Application Configuration
TORRUST_TRACKER_MODE: "private|public|whitelisted"
TORRUST_TRACKER_DATABASE_URL: "sqlite:///var/lib/torrust/tracker.db"
TORRUST_TRACKER_LOG_LEVEL: "info|debug|trace"
TORRUST_TRACKER_API_TOKEN: "${TORRUST_API_TOKEN}"

# Service Configuration
PROMETHEUS_RETENTION_TIME: "15d"
GRAFANA_ADMIN_PASSWORD: "${GRAFANA_PASSWORD}"

# Security Configuration
SSH_PUBLIC_KEY: "${SSH_PUBLIC_KEY}"
SSL_EMAIL: "${SSL_EMAIL}"
DOMAIN_NAME: "${DOMAIN_NAME}"
```

### Deployment Workflow

#### Current Workflow (Manual)

```bash
1. make apply                    # Infrastructure + app deployment
2. SSH and manual configuration
3. Manual service startup
```

#### Target Workflow (Twelve-Factor)

```bash
# Infrastructure
1. make infra-apply ENVIRONMENT=local
2. make app-deploy ENVIRONMENT=local
3. make health-check ENVIRONMENT=local

# Application Updates (without infrastructure changes)
1. make app-deploy ENVIRONMENT=local
2. make health-check ENVIRONMENT=local
```

## Testing Strategy

### Test Categories

#### 1. Infrastructure Tests

```bash
# Syntax validation
make test-syntax                 # YAML, HCL, shell syntax

# Infrastructure deployment
make test-infrastructure         # VM provisioning only

# Environment validation
make test-environment           # Configuration validation
```

#### 2. Application Tests

```bash
# Application deployment
make test-app-deployment        # Application deployment only

# End-to-end testing
make test-e2e                   # Full deployment pipeline

# Service validation
make test-services              # Health checks, endpoints
```

#### 3. Integration Tests

```bash
# Multi-environment testing
make test-local                 # Local environment
make test-staging               # Staging environment
make test-production            # Production environment (dry-run)
```

## Migration Strategy

### Phase 1: Backward Compatibility (Weeks 1-2)

#### Maintain Current Functionality

- Current `make apply` still works
- Existing test scripts remain functional
- No breaking changes to user workflow

#### Introduce New Structure

- Add new configuration structure alongside existing
- Implement new deployment scripts
- Create environment-specific configurations

#### Validation

- All existing tests pass
- New structure tests pass
- Documentation updated

### Phase 2: Gradual Migration (Weeks 3-4)

#### Deprecate Old Patterns

- Mark old configuration patterns as deprecated
- Provide migration warnings and guidance
- Implement migration helpers

#### Promote New Patterns

- Make new deployment method the default
- Update documentation to favor new approach
- Provide clear migration examples

#### Parallel Support

- Both old and new methods work
- Clear migration path documented
- User choice for migration timing

### Phase 3: New Default (Weeks 5-6)

#### Switch Defaults

- New twelve-factor approach becomes default
- Old approach requires explicit flags
- Comprehensive migration documentation

#### Remove Deprecated Code

- Clean up old configuration patterns
- Simplify codebase
- Update all documentation

#### Production Readiness

- Full Hetzner support implemented
- Multi-cloud foundation ready
- Operational procedures documented

## Success Metrics

### Configuration Compliance

- ✅ 100% configuration via environment variables
- ✅ No hardcoded configuration in deployment files
- ✅ Environment-specific configuration isolation

### Deployment Reliability

- ✅ < 5 minute VM provisioning time
- ✅ < 2 minute application deployment time
- ✅ 100% deployment success rate in testing

### Environment Parity

- ✅ Identical deployment process across environments
- ✅ Configuration-only differences between environments
- ✅ Zero manual configuration steps

### Operational Excellence

- ✅ Automated health checking
- ✅ Comprehensive logging and monitoring
- ✅ Clear rollback procedures

## Risk Assessment & Mitigation

### Technical Risks

#### Risk: Configuration Complexity

- **Impact**: High - Could make deployment more complex
- **Probability**: Medium
- **Mitigation**:
  - Provide clear examples and documentation
  - Implement configuration validation
  - Create migration helpers

#### Risk: Environment Inconsistencies

- **Impact**: High - Could cause production issues
- **Probability**: Low
- **Mitigation**:
  - Strict environment variable validation
  - Automated testing across environments
  - Configuration templates with validation

#### Risk: Deployment Failures

- **Impact**: Medium - Could disrupt testing workflow
- **Probability**: Low
- **Mitigation**:
  - Comprehensive testing strategy
  - Rollback procedures
  - Gradual migration approach

### Operational Risks

#### Risk: User Adoption

- **Impact**: Medium - Users might resist change
- **Probability**: Medium
- **Mitigation**:
  - Maintain backward compatibility during transition
  - Clear migration documentation
  - Demonstrable benefits

#### Risk: Documentation Lag

- **Impact**: Medium - Could cause confusion
- **Probability**: Medium
- **Mitigation**:
  - Documentation-first approach
  - Automated documentation testing
  - Community feedback integration

## Dependencies & Prerequisites

### Technical Dependencies

- OpenTofu/Terraform ≥ 1.0
- Docker ≥ 20.0
- Docker Compose ≥ 2.0
- KVM/libvirt (local testing)
- Cloud provider SDKs (production)

### Knowledge Prerequisites

- Understanding of twelve-factor methodology
- Experience with infrastructure as code
- Familiarity with environment variable configuration
- Knowledge of container orchestration

### Resource Requirements

- Development time: 8 weeks (1 person)
- Testing infrastructure: Local KVM environment
- Documentation effort: 20% of development time
- Community coordination: 10% of development time

## Deliverables

### Week 1-2: Foundation

- [ ] Environment-specific configuration structure
- [ ] Configuration validation scripts
- [ ] Deployment separation implementation
- [ ] Updated documentation

### Week 3-4: Build/Release/Run

- [ ] Infrastructure provisioning scripts
- [ ] Application deployment scripts
- [ ] Health checking implementation
- [ ] Integration testing framework

### Week 5-6: Multi-Cloud Preparation

- [ ] Provider abstraction layer
- [ ] Hetzner cloud integration
- [ ] Configuration templating system
- [ ] Multi-environment testing

### Week 7-8: Operational Excellence

- [ ] Monitoring standardization
- [ ] Backup procedures
- [ ] Disaster recovery documentation
- [ ] Production deployment guides

## Related Documents

- [Twelve-Factor App Methodology](https://12factor.net/)
- [Torrust Tracker Documentation](https://docs.rs/torrust-tracker/latest/torrust_tracker/)
- [Production Deployment Guide](https://torrust.com/blog/deploying-torrust-to-production)
- [Current Local Testing Setup](../local-testing-setup.md)
- [Infrastructure Overview](../infrastructure-overview.md)

## Support & Communication

### Implementation Team

- **Lead**: Project maintainer
- **Review**: Core team members
- **Testing**: Community contributors

### Communication Channels

- **GitHub Issues**: Technical discussions and questions
- **Pull Requests**: Code review and implementation
- **Documentation**: Continuous updates and improvements

### Feedback Collection

- **Weekly Progress Reports**: Implementation status
- **Community Feedback**: User experience and suggestions
- **Technical Reviews**: Architecture and implementation validation

---

**Next Steps**:

1. Review and approve this plan
2. Create detailed implementation tickets
3. Begin Phase 1 implementation
4. Establish regular progress reviews

**Estimated Completion**: 8 weeks from start date  
**Risk Level**: Medium (well-defined scope, clear requirements)  
**Impact**: High (enables production deployment and multi-cloud support)
