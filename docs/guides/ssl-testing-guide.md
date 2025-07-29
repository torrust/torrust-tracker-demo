# SSL/HTTPS Testing Guide

This guide documents the manual testing procedures for the two-phase SSL/HTTPS enablement
workflow in the Torrust Tracker Demo. It covers both local testing with Pebble ACME server
and validation of the production-ready SSL scripts.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Phase 1: HTTP-Only Deployment Testing](#phase-1-http-only-deployment-testing)
- [Phase 2: SSL/HTTPS Enablement Testing](#phase-2-sslhttps-enablement-testing)
- [Local Testing with Pebble](#local-testing-with-pebble)
- [Production SSL Testing](#production-ssl-testing)
- [Troubleshooting](#troubleshooting)
- [Validation Checklist](#validation-checklist)
- [Test Results and Updates](#test-results-and-updates)

## Overview

The SSL/HTTPS enablement follows a two-phase approach:

1. **Phase 1**: Fully automated HTTP-only deployment
2. **Phase 2**: Manual SSL/HTTPS enablement using standalone scripts

### Architecture Components

- **HTTP Template**: `infrastructure/config/templates/nginx-http.conf.tpl`
- **HTTPS Extension**: `infrastructure/config/templates/nginx-https-extension.conf.tpl`
- **SSL Scripts**: Located in `application/share/bin/ssl-*.sh`
- **Pebble Test Environment**: `application/compose.test.yaml`

### Working Tree Deployment for Testing

**Important**: For local testing, the deployment script automatically uses `rsync --filter=':- .gitignore'`
to copy the working tree, including uncommitted and untracked files (while respecting `.gitignore`).
This means all new SSL scripts, nginx templates, and Pebble configuration files are automatically
copied to the VM during `make app-deploy ENVIRONMENT=local`, even if they are not yet committed to git.

This makes the testing workflow seamless - you can create new SSL scripts, test them locally,
and deploy them immediately without needing to commit first.

## Prerequisites

### System Requirements

- Local testing infrastructure set up (see [Quick Start Guide](../infrastructure/quick-start.md))
- Docker and Docker Compose installed
- OpenTofu/Terraform configured
- SSH access to test VMs

### Required Tools

```bash
# Verify required tools are installed
make install-deps
make infra-config-local

# Test infrastructure prerequisites
make infra-test-prereq
```

### Environment Setup

```bash
# Ensure you have the correct environment configured
cd /path/to/torrust-tracker-demo

# Check current environment configuration
ls -la infrastructure/config/environments/
cat infrastructure/config/environments/local.env
```

## Phase 1: HTTP-Only Deployment Testing

### Test 1: Template Processing

**Purpose**: Verify that the nginx HTTP template processes correctly with environment variables.

```bash
# Load environment variables
source infrastructure/config/environments/local.env

# Export DOLLAR variable for nginx variables
export DOLLAR='$'

# Test template processing
envsubst < infrastructure/config/templates/nginx-http.conf.tpl > /tmp/test-nginx-http.conf

# Verify output
cat /tmp/test-nginx-http.conf
```

**Expected Results**:

- Domain names should be substituted: `tracker.test.local`, `grafana.test.local`
- Nginx variables should be preserved: `$proxy_add_x_forwarded_for`, `$host`, etc.
- Configuration should be valid nginx syntax

**Validation Commands**:

```bash
# Check domain substitution
grep -E "(tracker|grafana)\.test\.local" /tmp/test-nginx-http.conf

# Check nginx variable preservation
grep -E "\\\$proxy_add_x_forwarded_for|\\\$host|\\\$scheme" /tmp/test-nginx-http.conf

# Basic nginx syntax check (if nginx is installed locally)
nginx -t -c /tmp/test-nginx-http.conf 2>/dev/null && \
  echo "Syntax OK" || echo "Syntax check skipped (nginx not available)"
```

### Test 2: Infrastructure Deployment

**Purpose**: Test the complete infrastructure deployment with HTTP-only configuration.

```bash
# Deploy infrastructure
make infra-apply

# Deploy application (includes nginx HTTP config generation)
make app-deploy

# Check deployment status
make infra-status
```

**Expected Results**:

- VM should be provisioned successfully
- Application should deploy without errors
- HTTP services should be accessible

**Validation Commands**:

```bash
# Get VM IP
VM_IP=$(cd infrastructure/terraform && tofu output -raw vm_ip)
echo "VM IP: $VM_IP"

# Test HTTP endpoints
curl -s "http://$VM_IP/api/health_check" | jq
curl -s "http://$VM_IP/" | head -5

# Check nginx configuration on VM
ssh torrust@$VM_IP "cat /var/lib/torrust/proxy/etc/nginx-conf/nginx.conf" | head -20
```

### Test 3: Service Health Validation

**Purpose**: Verify all services are running and responding correctly.

```bash
# Run health check
make app-health-check

# Manual service checks
ssh torrust@$VM_IP \
  "docker compose -f /home/torrust/github/torrust/torrust-tracker-demo/application/compose.yaml ps"
```

**Expected Results**:

- All Docker services should be running
- Health check endpoints should return success
- Tracker and Grafana should be accessible via HTTP

## Phase 2: SSL/HTTPS Enablement Testing

### Test 4: SSL Script Validation

**Purpose**: Verify SSL scripts are executable and properly configured.

```bash
# Check SSL scripts exist and are executable
ls -la application/share/bin/ssl-*.sh

# Test script help/usage
application/share/bin/ssl-setup.sh --help
application/share/bin/ssl-validate-dns.sh --help
application/share/bin/ssl-generate.sh --help
application/share/bin/ssl-configure-nginx.sh --help
application/share/bin/ssl-activate-renewal.sh --help
```

**Expected Results**:

- All SSL scripts should be present and executable
- Help/usage information should be displayed correctly

### Test 5: DNS Validation Script

**Purpose**: Test the DNS validation functionality.

```bash
# Test DNS validation for local domains
ssh torrust@$VM_IP \
  "cd /home/torrust/github/torrust/torrust-tracker-demo && \
   ./application/share/bin/ssl-validate-dns.sh test.local"
```

**Expected Results**:

- For local testing, DNS validation may fail (expected)
- Script should provide clear feedback about DNS status
- No critical errors should occur

### Test 6: HTTPS Template Processing

**Purpose**: Verify the HTTPS extension template processes correctly.

```bash
# Test HTTPS template processing
source infrastructure/config/environments/local.env
export DOLLAR='$'

envsubst < infrastructure/config/templates/nginx-https-extension.conf.tpl > /tmp/test-nginx-https.conf

# Verify output
cat /tmp/test-nginx-https.conf
```

**Expected Results**:

- Domain names should be substituted in SSL certificate paths
- Nginx variables should be preserved
- SSL configuration should be complete and valid

## Local Testing with Pebble

### Test 7: Pebble ACME Server Setup

**Purpose**: Set up local ACME server for SSL certificate testing.

```bash
# Start Pebble test environment
cd application
docker compose -f compose.test.yaml up -d

# Check Pebble is running
docker compose -f compose.test.yaml ps
docker compose -f compose.test.yaml logs pebble
```

**Expected Results**:

- Pebble container should start successfully
- ACME server should be accessible on localhost:14000
- No critical errors in logs

### Test 8: Certificate Generation with Pebble

**Purpose**: Test SSL certificate generation using the local ACME server.

```bash
# SSH to VM and test certificate generation
ssh torrust@$VM_IP

# Navigate to application directory
cd /home/torrust/github/torrust/torrust-tracker-demo

# Test SSL generation with Pebble
./application/share/bin/ssl-generate.sh test.local admin@test.local pebble
```

**Expected Results**:

- Certificate generation should complete successfully
- Certificates should be created in expected locations
- No critical errors should occur

**Validation Commands** (on VM):

```bash
# Check certificate files
sudo ls -la /etc/letsencrypt/live/tracker.test.local/
sudo ls -la /etc/letsencrypt/live/grafana.test.local/

# Verify certificate details
sudo openssl x509 -in /etc/letsencrypt/live/tracker.test.local/fullchain.pem -text -noout | head -20
```

### Test 9: Nginx HTTPS Configuration

**Purpose**: Test adding HTTPS configuration to existing nginx setup.

```bash
# On VM, test nginx HTTPS configuration
ssh torrust@$VM_IP

cd /home/torrust/github/torrust/torrust-tracker-demo

# Configure nginx with HTTPS
./application/share/bin/ssl-configure-nginx.sh test.local
```

**Expected Results**:

- HTTPS configuration should be appended to nginx.conf
- Nginx should reload successfully
- No syntax errors should occur

**Validation Commands** (on VM):

```bash
# Check updated nginx configuration
sudo cat /var/lib/torrust/proxy/etc/nginx-conf/nginx.conf | tail -50

# Test nginx configuration
sudo nginx -t -c /var/lib/torrust/proxy/etc/nginx-conf/nginx.conf

# Check nginx is running
docker compose ps nginx
```

### Test 10: SSL Renewal Setup

**Purpose**: Test SSL certificate renewal automation setup.

```bash
# On VM, test renewal activation
ssh torrust@$VM_IP

cd /home/torrust/github/torrust/torrust-tracker-demo

# Show current renewal status
./application/share/bin/ssl-activate-renewal.sh test.local admin@test.local show

# Install renewal cron job
./application/share/bin/ssl-activate-renewal.sh test.local admin@test.local install

# Verify cron job
crontab -l | grep certbot
```

**Expected Results**:

- Renewal cron job should be installed successfully
- Cron job should be visible in crontab
- No duplicate entries should be created

## Production SSL Testing

### Test 11: Production SSL Scripts (Dry Run)

**Purpose**: Test production SSL scripts without actually generating certificates.

```bash
# On VM, test production SSL in dry-run mode
ssh torrust@$VM_IP

cd /home/torrust/github/torrust/torrust-tracker-demo

# Test staging certificate generation (safe for testing)
./application/share/bin/ssl-generate.sh your-domain.com admin@your-domain.com staging
```

**Expected Results**:

- Staging certificate generation should work
- Let's Encrypt staging server should respond
- Rate limits should not be triggered

**Note**: Only perform this test if you have a real domain configured and DNS properly set up.

### Test 12: Complete SSL Workflow

**Purpose**: Test the complete SSL enablement workflow orchestration.

```bash
# On VM, test complete SSL setup
ssh torrust@$VM_IP

cd /home/torrust/github/torrust/torrust-tracker-demo

# Run complete SSL setup (using staging for safety)
./application/share/bin/ssl-setup.sh your-domain.com admin@your-domain.com staging
```

**Expected Results**:

- All SSL setup steps should complete successfully
- Services should restart without issues
- HTTPS endpoints should become available

## Troubleshooting

### Common Issues and Solutions

#### Template Processing Errors

**Issue**: Environment variables not substituted correctly

**Diagnosis**:

```bash
# Check environment file exists and is readable
ls -la infrastructure/config/environments/local.env
cat infrastructure/config/environments/local.env | grep DOMAIN_NAME

# Verify variables are exported
echo "DOMAIN_NAME: ${DOMAIN_NAME:-not_set}"
echo "DOLLAR: ${DOLLAR:-not_set}"
```

**Solution**:

```bash
# Reload environment
source infrastructure/config/environments/local.env
export DOLLAR='$'
```

#### Nginx Variable Corruption

**Issue**: Nginx variables like `$host` become empty in processed templates

**Diagnosis**:

```bash
# Check for missing DOLLAR variable
grep -E "proxy_set_header.*[^$]host" /tmp/test-nginx-http.conf
```

**Solution**:

```bash
# Ensure DOLLAR is exported before envsubst
export DOLLAR='$'
envsubst < template.conf.tpl > output.conf
```

#### SSL Certificate Generation Failures

**Issue**: Certificate generation fails with ACME server

**Diagnosis**:

```bash
# Check certbot logs
sudo tail -f /var/log/letsencrypt/letsencrypt.log

# Test ACME server connectivity
curl -k https://localhost:14000/dir  # For Pebble
curl https://acme-staging-v02.api.letsencrypt.org/directory  # For staging
```

**Solution**:

```bash
# For Pebble: Check if test environment is running
docker compose -f compose.test.yaml ps

# For Let's Encrypt: Check DNS and firewall
dig tracker.your-domain.com
sudo ufw status
```

#### Nginx Configuration Errors

**Issue**: Nginx fails to start after HTTPS configuration

**Diagnosis**:

```bash
# Test nginx configuration
sudo nginx -t -c /var/lib/torrust/proxy/etc/nginx-conf/nginx.conf

# Check nginx logs
docker compose logs nginx
```

**Solution**:

```bash
# Verify certificate files exist
sudo ls -la /etc/letsencrypt/live/tracker.your-domain.com/

# Check file permissions
sudo ls -la /etc/letsencrypt/live/tracker.your-domain.com/fullchain.pem
```

### Cleanup Procedures

#### Reset to HTTP-Only

```bash
# Remove HTTPS configuration and certificates
ssh torrust@$VM_IP

# Stop services
cd /home/torrust/github/torrust/torrust-tracker-demo/application
docker compose down

# Remove HTTPS configuration
sudo sed -i '/# HTTPS server for tracker subdomain/,$d' /var/lib/torrust/proxy/etc/nginx-conf/nginx.conf

# Remove certificates
sudo rm -rf /etc/letsencrypt/live/*
sudo rm -rf /etc/letsencrypt/archive/*
sudo rm -rf /etc/letsencrypt/renewal/*

# Restart services
docker compose up -d
```

#### Clean Pebble Environment

```bash
# Stop and remove Pebble containers
cd application
docker compose -f compose.test.yaml down -v

# Clean up certificate data
docker compose -f compose.test.yaml rm -f
```

## Validation Checklist

### Phase 1: HTTP-Only Deployment

- [ ] Nginx HTTP template processes correctly with environment variables
- [ ] Domain names are properly substituted (tracker.test.local, grafana.test.local)
- [ ] Nginx variables are preserved ($proxy_add_x_forwarded_for, $host, etc.)
- [ ] Infrastructure deploys successfully
- [ ] Application deploys without errors
- [ ] HTTP services are accessible
- [ ] Health checks pass
- [ ] All Docker services are running

### Phase 2: SSL/HTTPS Enablement

- [ ] SSL scripts are executable and show help/usage
- [ ] DNS validation script runs without critical errors
- [ ] HTTPS template processes correctly
- [ ] Pebble ACME server starts successfully
- [ ] Certificate generation works with Pebble
- [ ] Certificates are created in expected locations
- [ ] Nginx HTTPS configuration is appended correctly
- [ ] Nginx reloads successfully after HTTPS configuration
- [ ] SSL renewal cron job is installed correctly
- [ ] Complete SSL workflow executes successfully

### Production Readiness

- [ ] Staging SSL certificates can be generated
- [ ] Production SSL scripts work in dry-run mode
- [ ] DNS validation works for real domains
- [ ] Certificate renewal automation is functional
- [ ] HTTPS endpoints are accessible
- [ ] Security headers are properly configured
- [ ] WebSocket connections work for Grafana Live

### Documentation and Maintenance

- [ ] All test procedures are documented
- [ ] Troubleshooting steps are validated
- [ ] Cleanup procedures work correctly
- [ ] Common issues have solutions
- [ ] Testing guide is complete and usable by other developers

## Future Enhancements

### Automated Testing

Consider implementing automated tests for:

- Template processing validation
- SSL certificate generation simulation
- Nginx configuration syntax checking
- End-to-end HTTPS workflow testing

### Integration with CI/CD

Future improvements could include:

- Automated SSL testing in GitHub Actions
- Integration testing with real ACME servers
- Performance testing of HTTPS configurations
- Security scanning of SSL configurations

### Monitoring and Alerting

Additional validation could include:

- Certificate expiration monitoring
- SSL configuration security scanning
- Performance impact measurement
- Automated health checks for HTTPS endpoints

## Test Results and Updates

This section documents the actual test results and any updates made during testing.

### Working Tree Deployment Validation

**Test Date**: July 29, 2025  
**Tester**: System validation  
**Status**: ✅ PASS

**Test Description**: Verified that the deployment script properly copies untracked SSL files to the VM for local testing.

**Key Findings**:

- ✅ The `deploy-app.sh` script automatically uses `rsync --filter=':- .gitignore'` for local testing
- ✅ All untracked SSL scripts (`ssl-*.sh`) are copied to the VM successfully
- ✅ All nginx templates (`nginx-*.conf.tpl`) are copied to the VM
- ✅ Pebble test environment files (`compose.test.yaml`, `pebble-config/`) are copied
- ✅ File permissions are preserved (SSL scripts remain executable: `-rwxrwxr-x`)
- ✅ Working tree deployment includes both uncommitted and untracked files while respecting `.gitignore`

**Validation Commands Used**:

```bash
# Check git status of untracked files
git status --porcelain

# Deploy application with working tree
make app-deploy ENVIRONMENT=local VM_IP=192.168.122.92

# Verify SSL scripts on VM
ssh torrust@192.168.122.92 "ls -la /home/torrust/github/torrust/torrust-tracker-demo/application/share/bin/ssl-*.sh"

# Test SSL script functionality
ssh torrust@192.168.122.92 "cd /home/torrust/github/torrust/torrust-tracker-demo && ./application/share/bin/ssl-setup.sh --help"
```

**Resolution Notes**: Fixed path calculation in SSL scripts. The scripts were initially calculating `PROJECT_ROOT` incorrectly, causing `shell-utils.sh` to not be found. Updated to use the correct relative paths.

### Template Processing Validation

**Test Date**: July 29, 2025  
**Status**: ✅ PASS

**Test Description**: Verified that nginx HTTP and HTTPS templates process correctly with environment variables.

**Key Findings**:

- ✅ HTTP template processes correctly with `DOMAIN_NAME=test.local`
- ✅ Nginx variables are properly preserved with `DOLLAR='$'` export
- ✅ Domain substitution works for `tracker.test.local` and `grafana.test.local`
- ✅ Template processing is automated in `deploy-app.sh`

### Future Test Areas

**Pending Tests** (to be performed in subsequent sessions):

1. **Pebble ACME Server Testing**

   - Start Pebble test environment
   - Generate certificates using local ACME server
   - Validate certificate creation and nginx configuration

2. **Let's Encrypt Staging Testing**

   - Test DNS validation for real domains
   - Generate staging certificates
   - Validate staging workflow

3. **End-to-End HTTPS Workflow**

   - Complete SSL setup using `ssl-setup.sh`
   - Validate HTTPS endpoints accessibility
   - Test certificate renewal automation

4. **Production Readiness Validation**
   - Test production certificate workflow (dry-run)
   - Validate security headers and configurations
   - Performance impact assessment

### Development Notes

**For Contributors**:

- The deployment script now seamlessly handles untracked files for local testing
- No need to commit SSL scripts before testing - they're automatically copied
- Path calculations in SSL scripts have been standardized and tested
- All SSL scripts now properly source `shell-utils.sh` from the correct location

**Testing Workflow Recommendations**:

1. Create/modify SSL scripts locally
2. Make them executable: `chmod +x application/share/bin/ssl-*.sh`
3. Deploy with: `make app-deploy ENVIRONMENT=local`
4. Test on VM: `ssh torrust@VM_IP "cd torrust-tracker-demo && ./application/share/bin/ssl-setup.sh --help"`

This approach enables rapid iteration during SSL feature development without requiring git commits for every change.
