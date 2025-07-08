# Torrust Tracker Demo Migration Plan - Digital Ocean to Hetzner

## Overview

This plan outlines the migration of the Torrust Tracker demo from Digital Ocean to Hetzner
infrastructure. The migration prioritizes **ease of updates** over performance by maintaining
Docker-based deployments, and follows a **complete local development and testing** approach
before deploying to production.

## Key Decisions

- **Docker-first approach**: Continue using Docker for the tracker to simplify updates
  (just pull new images)
- **Complete local testing**: Finish all development and testing locally before creating
  any Hetzner VMs
- **MySQL by default**: Replace SQLite with MySQL for better production characteristics
- **12-Factor App compliance**: Refactor the entire repository to follow modern deployment
  practices

## Migration Phases

### Phase 1: Database Migration to MySQL

**Objective**: Replace SQLite with MySQL as the default database

#### Tasks

- [x] Add MySQL service to `docker-compose.yaml`
- [x] Update tracker configuration (`tracker.toml`) to use MySQL connection
- [x] Create MySQL initialization scripts/schema
- [x] Update environment variable templates (`.env.production`)
- [x] Update documentation for MySQL setup

#### Validation

- [x] Deploy locally using `make apply`
- [x] Verify MySQL service starts successfully
- [x] Make test announce request
- [x] Confirm download counter increases in MySQL `torrents` table
- [x] Test tracker restart with persistent MySQL data

**Deliverable**: Working local deployment with MySQL backend

---

### Phase 2: 12-Factor App Refactoring

**Objective**: Refactor repository to follow [12-Factor App methodology](https://12factor.net/)

**Reference**: See detailed plan in `infrastructure/docs/refactoring/twelve-factor-refactor/`

#### Key Changes

- [ ] **Configuration via environment**: Move all config to environment variables
- [ ] **Dependency isolation**: Explicit dependency declaration in Docker
- [ ] **Stateless processes**: Ensure tracker processes are stateless
- [ ] **Port binding**: Clean service port configuration
- [ ] **Logs as streams**: Structured logging to stdout/stderr
- [ ] **Environment parity**: Dev/staging/prod environment consistency

#### Tasks

- [ ] Implement configuration refactoring (see phase-1-implementation.md)
- [ ] Update Docker configurations
- [ ] Refactor environment variable management
- [ ] Update deployment scripts
- [ ] Update documentation

**Deliverable**: 12-Factor compliant repository structure

---

### Phase 3: Complete Application Installation Automation

**Objective**: Fully automate tracker deployment including SSL certificates

#### Current State

- ✅ VM provisioning via cloud-init
- ✅ Basic app setup (copy files, `.env` config, `docker compose up`)
- ❌ SSL certificate generation
- ❌ Crontab setup for renewals
- ❌ Production hardening steps

#### Tasks

- [ ] Automate SSL certificate generation with Certbot
- [ ] Set up automatic certificate renewal crontabs
- [ ] Implement production hardening automation
- [ ] Create comprehensive deployment validation script
- [ ] Handle edge cases and error recovery

#### Implementation Notes

- Integrate with existing cloud-init setup
- If Certbot automation requires manual interaction, document as the only manual step
- Follow production setup guide: https://torrust.com/blog/deploying-torrust-to-production

**Deliverable**: One-command deployment to production-ready state

---

### Phase 4: Hetzner Infrastructure Implementation

**Objective**: Add Hetzner Cloud provider support and validate complete deployment

#### Tasks

- [ ] Research and add Hetzner Cloud OpenTofu provider
- [ ] Create Hetzner-specific Terraform configurations
- [ ] Implement Hetzner cloud-init adaptations
- [ ] Test complete deployment pipeline on Hetzner
- [ ] Configure provider-level firewall (optional, complementing VM firewall)
- [ ] Validate tracker accessibility via IP (HTTP)

#### Provider Firewall Consideration

- VM firewall via cloud-init: ✅ Required
- Provider firewall: 🤔 Optional additional security layer

#### Validation

- [ ] Deploy test VM on Hetzner
- [ ] Verify all services start correctly
- [ ] Test tracker functionality (announce, scrape)
- [ ] Confirm firewall rules work correctly
- [ ] Performance and connectivity testing

**Deliverable**: Working Hetzner deployment with IP access

---

### Phase 5: Database Migration (Optional)

**Objective**: Migrate existing tracker data from Digital Ocean SQLite to Hetzner MySQL

#### Tasks

- [ ] Export existing SQLite data from Digital Ocean instance
- [ ] Create data transformation scripts (SQLite → MySQL)
- [ ] Import data to new MySQL instance
- [ ] Validate data integrity and completeness
- [ ] Test tracker with migrated data

**Note**: This step is optional and can be skipped for a fresh start

---

### Phase 6: Grafana Configuration

**Objective**: Manually configure Grafana for monitoring the tracker.

#### Tasks

- [ ] Log in to Grafana at `http://localhost:3100/` with default credentials (admin/admin).
- [ ] Change the default admin password.
- [ ] Configure the Prometheus data source to poll the tracker's API metrics endpoint.
- [ ] Optional: Import pre-built dashboards from the repository to visualize tracker metrics.

**Note**: An issue will be opened with more details when work on this phase begins.

**Deliverable**: A configured Grafana instance with a Prometheus data source and dashboards.

---

### Phase 7: Testing and Validation

**Objective**: Comprehensive testing of the new Hetzner deployment

#### Testing Areas

- [ ] **Functional Testing**: All tracker endpoints work correctly
- [ ] **Performance Testing**: Announce/scrape response times
- [ ] **Integration Testing**: Index ↔ Tracker communication
- [ ] **Monitoring**: Grafana dashboards show correct metrics
- [ ] **SSL Testing**: HTTPS certificate generation and renewal
- [ ] **Backup Testing**: Database backup and restore procedures

#### Test Scenarios

- [ ] Fresh torrent announce and scrape
- [ ] High-load announce testing
- [ ] Tracker restart with data persistence
- [ ] Certificate renewal simulation
- [ ] Firewall rule validation

**Deliverable**: Fully validated production deployment

---

### Phase 8: Go Live

**Objective**: Switch production traffic to Hetzner infrastructure

#### Pre-Go-Live

- [ ] Consider static IP allocation on Hetzner
- [ ] Prepare DNS change procedures
- [ ] Document rollback plan

#### Go-Live Steps

- [ ] Update DNS records to point to new Hetzner IP
- [ ] Update Digital Ocean index configuration:
  - Change tracker resolution from Docker service name to public domain
  - Index will access tracker via public API instead of internal Docker network
- [ ] Monitor traffic and error rates
- [ ] Validate end-to-end functionality

#### Post-Go-Live

- [ ] Monitor system stability for 24-48 hours
- [ ] Verify certificate auto-renewal works
- [ ] Confirm backup procedures
- [ ] Update documentation with new procedures

**Deliverable**: Production traffic on Hetzner infrastructure

---

## Future Considerations

### Dynamic Configuration (Future Work)

Currently hardcoded in cloud-init:

- Number of tracker instances (e.g., 2 UDP trackers on ports 6868, 6969)
- Firewall port configurations
- Service scaling parameters

**Future Enhancement**: Inject dynamic configuration via template variables

### Repository Template Usage

This repository serves as a template for users deploying their own trackers. Current
hardcoded configurations can be manually adapted, but future work could make this more
dynamic.

## Risk Mitigation

### Rollback Plan

- Keep Digital Ocean instance running until Hetzner deployment is fully validated
- Maintain DNS rollback capability
- Document emergency procedures

### Testing Strategy

- All changes tested locally before Hetzner deployment
- Staged rollout with validation at each phase
- Comprehensive testing before DNS switch

## Success Criteria

- [ ] Tracker accessible via HTTPS on Hetzner
- [ ] MySQL database working with persistent data
- [ ] Grafana monitoring functional
- [ ] SSL certificates auto-renewing
- [ ] Index successfully communicating with tracker
- [ ] Performance equivalent to or better than Digital Ocean
- [ ] 12-Factor App compliance achieved
- [ ] One-command deployment working
